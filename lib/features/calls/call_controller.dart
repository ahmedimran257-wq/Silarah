// The one call on this phone (outgoing, incoming or connected).
//
// The server decides everything that costs money or touches safety; this
// controller only follows it: ring, poll, join Stream with the 1-hour token
// the server returns after Answer, show the minute meter, hang up.
//
// Every call attempt gets its own number ([_attempt]). Each await is
// followed by a check that the attempt is still current, so a step that
// finishes late (a join after the member hung up, an answer for a call that
// was cancelled meanwhile) stops itself instead of acting on a newer call.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_video/stream_video.dart' as sv;

import '../../l10n/calling_ui_copy.dart';
import 'call_api.dart';
import 'call_models.dart';
import 'call_notifications.dart';
import 'call_platform.dart';

enum CallPhase { idle, outgoing, incoming, connecting, active, ended }

enum CallAudioRoute { earpiece, speaker, bluetooth, wired }

/// Why the call screen shows "ended", as copy keys (see calling_ui_copy).
abstract final class CallEndCopy {
  static const ended = 'Call ended';
  static const notAnswered = 'Not answered';
  static const failed = 'Call failed. Please try again.';
  static const answeredElsewhere = 'Answered on another device';
  static const declined = 'Call declined';
  static const missed = 'Missed call';
  static const timeUp = 'Your call minutes ran out.';
}

/// Where the call's audio goes after the devices changed (spec 12.9), the
/// way a phone call does it: a headset that just connected takes the call;
/// the route in use stays while it is there; when it goes, the next best.
CallAudioRoute nextAudioRoute({
  required CallAudioRoute current,
  required Set<CallAudioRoute> before,
  required Set<CallAudioRoute> now,
}) {
  if (now.contains(CallAudioRoute.bluetooth) && !before.contains(CallAudioRoute.bluetooth)) {
    return CallAudioRoute.bluetooth;
  }
  if (now.contains(CallAudioRoute.wired) && !before.contains(CallAudioRoute.wired)) {
    return CallAudioRoute.wired;
  }
  if (now.contains(current)) return current;
  for (final next in const [
    CallAudioRoute.bluetooth,
    CallAudioRoute.wired,
    CallAudioRoute.earpiece,
    CallAudioRoute.speaker,
  ]) {
    if (now.contains(next)) return next;
  }
  return CallAudioRoute.earpiece;
}

/// The tone as a call ends (spec 12.9), or none. The caller hears one
/// neutral tone for every call that did not connect: never why (12.4).
String? callEndTone({
  required String copy,
  required bool connected,
  required bool ringingOut,
  bool endedByMember = false,
}) {
  if (copy == CallEndCopy.failed) return 'failed';
  if (connected) return 'ended';
  // The caller hung up while it rang: their own ending, not "not reached".
  if (ringingOut && endedByMember) return 'ended';
  if (ringingOut) return 'not_reached';
  return null;
}

class CallController extends ChangeNotifier with WidgetsBindingObserver {
  CallController({CallApi? api, CallPlatform? platform})
      : _api = api ?? CallApi.instance,
        _platform = platform ?? CallPlatform.instance {
    _platformEvents = _platform.events.listen(_onPlatformEvent);
  }

  static final CallController instance = CallController();

  /// Chats refresh their call history when this changes (a call ended, or a
  /// missed-call note arrived while Silarah is open).
  static final ValueNotifier<int> historyVersion = ValueNotifier<int>(0);
  static void historyChanged() => historyVersion.value++;

  /// How long the other member may be missing before the app hangs up on
  /// its own. Normally the server ends the call first (Stream says the
  /// member left), and a dropped phone rejoins within seconds.
  static const otherMemberGrace = Duration(seconds: 15);

  /// A connection lost for longer than this ends the call; the server stops
  /// billing when Stream ends it.
  static const reconnectLimit = Duration(seconds: 30);

  final CallApi _api;
  final CallPlatform _platform;

  CallPhase phase = CallPhase.idle;
  String? requestId;
  String? matchId;
  String? otherUserId;
  String otherName = '';
  bool isCaller = false;
  String endedCopy = CallEndCopy.ended;
  bool muted = false;
  bool onHold = false;
  bool reconnecting = false;
  CallAudioRoute route = CallAudioRoute.earpiece;
  Set<CallAudioRoute> availableRoutes = const {CallAudioRoute.earpiece, CallAudioRoute.speaker};

  /// Device names (a Bluetooth headset's own name) for the route picker.
  Map<CallAudioRoute, String> routeNames = const {};
  DateTime? connectedAt;
  int maxDurationSeconds = 0;
  int holdMinutes = 0;
  bool extending = false;
  IncomingCallPush? incoming;

  /// End of the ring on this phone's own clock.
  DateTime? ringEndsAt;

  int _attempt = 0;
  sv.StreamVideo? _client;
  sv.Call? _call;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Timer? _pollTimer;
  Timer? _tick;
  Timer? _resetTimer;
  Timer? _otherGoneTimer;
  Timer? _reconnectTimer;
  CallTimeWarning _lastWarning = CallTimeWarning.none;
  bool _serviceWanted = false;
  bool _serviceRunning = false;
  bool _observing = false;
  // Telecom holds the call (Android 8+): routes and hold go through it.
  bool _telecom = false;
  int _shownMinutesLeft = -1;
  StreamSubscription<CallEvent>? _platformEvents;

  bool get busy => phase != CallPhase.idle && phase != CallPhase.ended;
  bool get holdWasFull => holdMinutes >= 60;

  int get secondsLeftNow => connectedAt == null
      ? holdMinutes * 60
      : secondsLeft(
          holdMinutes: holdMinutes,
          connectedAt: connectedAt!,
          now: DateTime.now(),
        );

  int get elapsedSeconds =>
      connectedAt == null ? 0 : DateTime.now().difference(connectedAt!).inSeconds;

  /// The caller's held minutes not yet used, counted the way settlement
  /// charges: every started minute (docs/voice_calling_spec.md 4).
  int get minutesLeftOfHold => holdMinutes - chargedMinutesSoFar(elapsedSeconds, holdMinutes);

  CallTimeWarning get warning => phase == CallPhase.active
      ? warningFor(secondsLeftNow, holdWasFull: holdWasFull)
      : CallTimeWarning.none;

  /// Starts a new attempt; earlier attempts stop at their next check.
  int _begin() {
    _attempt++;
    _clearTimers();
    return _attempt;
  }

  bool _current(int attempt) => attempt == _attempt;

  // ---------------------------------------------------------------------------
  // Outgoing
  // ---------------------------------------------------------------------------

  /// Asks the server to ring [toMatchId]. Non-ringing outcomes are returned
  /// for the chat screen to explain; only `ringing` opens the call screen.
  Future<CallStartResult> startOutgoing({
    required String toMatchId,
    required String name,
    String? toUserId,
  }) async {
    if (busy) return const CallStartResult(CallStartOutcome.busySelf);
    final attempt = _begin();
    final result = await _api.start(toMatchId);
    if (!_current(attempt) || busy) {
      // Something else (an incoming call) took over while we asked.
      if (result.requestId != null && result.outcome == CallStartOutcome.ringing) {
        unawaited(_api.end(result.requestId!, reason: 'cancelled'));
      }
      return const CallStartResult(CallStartOutcome.busySelf);
    }
    if (result.outcome == CallStartOutcome.glare && result.requestId != null) {
      // They are calling us at the same moment: answer their call.
      _resetFields();
      requestId = result.requestId;
      matchId = toMatchId;
      otherUserId = toUserId;
      otherName = name;
      isCaller = false;
      phase = CallPhase.connecting;
      notifyListeners();
      unawaited(_answer(attempt, result.requestId!));
      return result;
    }
    if (result.outcome != CallStartOutcome.ringing || result.requestId == null) {
      return result;
    }
    _resetFields();
    requestId = result.requestId;
    matchId = toMatchId;
    otherUserId = toUserId;
    otherName = name;
    isCaller = true;
    ringEndsAt = DateTime.now().add(Duration(seconds: (result.ringSeconds ?? 30).clamp(5, 120)));
    phase = CallPhase.outgoing;
    notifyListeners();
    unawaited(_platform.setCallWindow(true));
    // A call from the first ring: Telecom routes the ringback to the
    // earpiece or headset, and the status bar shows the call.
    _wantService(true);
    unawaited(_platform.playTone('ringback'));
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _poll(attempt));
    return result;
  }

  /// A push said the other side answered: check now instead of waiting.
  void nudge(String forRequestId) {
    if (forRequestId == requestId && phase == CallPhase.outgoing) unawaited(_poll(_attempt));
  }

  bool _polling = false;
  Future<void> _poll(int attempt) async {
    final id = requestId;
    if (!_current(attempt) || id == null || phase != CallPhase.outgoing || _polling) return;
    _polling = true;
    try {
      final ends = ringEndsAt;
      if (ends != null && DateTime.now().isAfter(ends.add(const Duration(seconds: 3)))) {
        _pollTimer?.cancel();
        await _api.end(id, reason: 'timeout');
        if (_current(attempt)) await _finish(attempt, CallEndCopy.notAnswered);
        return;
      }
      final status = await _api.status(id);
      if (!_current(attempt) || phase != CallPhase.outgoing) return;
      switch (status) {
        case 'ringing':
        case 'connecting':
        case 'unknown':
          return;
        case 'active':
          _pollTimer?.cancel();
          await _platform.stopTone();
          if (!_current(attempt)) return;
          phase = CallPhase.connecting;
          notifyListeners();
          final joined = await _api.join(id);
          if (!_current(attempt)) return;
          final info = joined.info;
          if (info == null) {
            await _finish(attempt, CallEndCopy.failed);
            return;
          }
          await _connect(attempt, info);
        default:
          // declined, cancelled, missed, failed, unavailable, ended:
          // the caller is never told which.
          _pollTimer?.cancel();
          await _finish(attempt, CallEndCopy.notAnswered);
      }
    } finally {
      _polling = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Incoming
  // ---------------------------------------------------------------------------

  /// A ring arrived (push while open, or a tap on the notification).
  /// Ignored while this phone is busy with any call, including this one:
  /// a repeated push never resets an answer that is already under way.
  void presentIncoming(IncomingCallPush push) {
    if (busy) return;
    final attempt = _begin();
    _resetFields();
    incoming = push;
    requestId = push.requestId;
    matchId = push.matchId;
    otherName = push.callerName;
    otherUserId = push.callerId.isEmpty ? null : push.callerId;
    isCaller = false;
    ringEndsAt = push.expiresAt;
    phase = CallPhase.incoming;
    notifyListeners();
    unawaited(_platform.setCallWindow(true));
    // Close the incoming screen if the ring ends without an answer here.
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final id = requestId;
      if (!_current(attempt) || id == null || phase != CallPhase.incoming) return;
      if (DateTime.now().isAfter(push.expiresAt.add(const Duration(seconds: 2)))) {
        await _finish(attempt, CallEndCopy.missed);
        return;
      }
      final status = await _api.status(id);
      if (_current(attempt) && phase == CallPhase.incoming &&
          status != 'ringing' && status != 'unknown') {
        await _finish(attempt, status == 'connecting' || status == 'active'
            ? CallEndCopy.answeredElsewhere
            : CallEndCopy.missed);
      }
    });
  }

  /// Android lit the screen and showed Silarah over the lock screen as the
  /// ring opened it (MainActivity.wakeForIncomingRing). When that ring is not
  /// shown here (over, or for another account), give the lock screen back,
  /// unless a call is under way and still needs the window.
  void releaseRingWindow() {
    if (!busy) unawaited(_platform.setCallWindow(false));
  }

  /// The ring was cancelled (caller hung up, answered elsewhere, timeout).
  void onRingCancelled(String forRequestId) {
    if (forRequestId == requestId && phase == CallPhase.incoming) {
      unawaited(_finish(_attempt, CallEndCopy.missed));
    }
  }

  /// Answer (from the in-app screen or the notification). The screen has
  /// checked the microphone first.
  Future<void> answer({
    required String forRequestId,
    String? forMatchId,
    String? name,
  }) async {
    if (requestId != forRequestId) {
      if (busy) return;
      _begin();
      _resetFields();
      requestId = forRequestId;
      matchId = forMatchId;
      otherName = name ?? '';
      isCaller = false;
    } else if (phase != CallPhase.incoming) {
      return; // already answering or answered
    }
    _pollTimer?.cancel();
    phase = CallPhase.connecting;
    notifyListeners();
    await _answer(_attempt, forRequestId);
  }

  Future<void> _answer(int attempt, String id) async {
    await CallNotifications.cancel(id);
    unawaited(_platform.setCallWindow(true));
    // Lets the server stop the ring on this member's other phones. Optional:
    // answering never depends on it.
    String? deviceId;
    try {
      deviceId = (await SharedPreferences.getInstance()).getString('silarah_device_id');
    } catch (_) {}
    if (!_current(attempt)) return;
    final accepted = await _api.accept(id, deviceId: deviceId);
    if (!_current(attempt)) return;
    final info = accepted.info;
    if (info == null) {
      await _finish(attempt, switch (accepted.outcome) {
        'already_answered' => CallEndCopy.answeredElsewhere,
        'declined' => CallEndCopy.declined,
        'failed' => CallEndCopy.failed,
        _ => CallEndCopy.missed,
      });
      return;
    }
    await _connect(attempt, info);
  }

  Future<void> decline() async {
    final id = requestId;
    if (id == null || phase != CallPhase.incoming) return;
    final attempt = _attempt;
    _pollTimer?.cancel();
    await CallNotifications.cancel(id);
    await _api.end(id, reason: 'declined');
    if (_current(attempt)) await _finish(attempt, CallEndCopy.declined);
  }

  // ---------------------------------------------------------------------------
  // Live call
  // ---------------------------------------------------------------------------

  Future<void> _connect(int attempt, CallJoinInfo info) async {
    otherName = info.otherName.isEmpty ? otherName : info.otherName;
    otherUserId = info.otherUserId ?? otherUserId;
    matchId = info.matchId ?? matchId;
    isCaller = info.isCaller;
    maxDurationSeconds = info.maxDurationSeconds;
    holdMinutes = info.holdMinutes;
    phase = CallPhase.connecting;
    notifyListeners();

    await _platform.startPhoneCallWatch();
    _wantService(true);
    try {
      await sv.StreamVideo.reset(disconnect: true);
      if (!_current(attempt)) return;
      final callRequestId = info.requestId;
      final client = sv.StreamVideo(
        info.apiKey,
        user: sv.User.regular(userId: info.userId, name: info.myName),
        userToken: info.token,
        // Tokens last an hour (spec 4) and a topped-up call can run longer:
        // a reconnect then asks our server for a fresh one, which it gives
        // only while this call is live.
        tokenLoader: (_) async {
          final fresh = await _api.join(callRequestId);
          final token = fresh.info?.token;
          if (token == null || token.isEmpty) throw StateError('call_no_longer_live');
          return token;
        },
        options: sv.StreamVideoOptions(
          // The server sets names; the app never rewrites its Stream user.
          includeUserDetailsForAutoConnect: false,
          // Keep talking with the screen off or another app in front.
          keepConnectionsAliveWhenInBackground: true,
          muteAudioWhenInBackground: false,
          muteVideoWhenInBackground: true,
          // Stream's warnings and errors reach the device log (never its
          // verbose lines, which can contain request details).
          logPriority: sv.Priority.warning,
          logHandlerFunction: _streamLog,
        ),
        failIfSingletonExists: false,
      );
      _client = client;
      final call = client.makeCall(
        callType: sv.StreamCallType.custom(info.callType),
        id: info.callId,
      );
      _call = call;
      _subscriptions.add(call.state.listen((state) => _onCallState(attempt, state)));
      _subscriptions.add(
        sv.RtcMediaDeviceNotifier.instance.onDeviceChange.listen((_) => unawaited(_refreshRoutes())),
      );
      final joined = await call.join(
        connectOptions: sv.CallConnectOptions(
          camera: sv.TrackOption.disabled(),
          screenShare: sv.TrackOption.disabled(),
          microphone: sv.TrackOption.enabled(),
        ),
      );
      if (!_current(attempt)) {
        // The member hung up while we were joining: leave at once.
        unawaited(_leave(call, client));
        return;
      }
      if (joined is sv.Failure) {
        debugPrint('[CallController] join failed: ${joined.error.message}');
        await hangUp(copy: CallEndCopy.failed);
        return;
      }
      // Stream picked the route at join: a connected headset, else the
      // earpiece (silarah_voice has the speaker off). Follow it; forcing the
      // earpiece here once kept calls off Bluetooth headsets.
      final engineRoute = _routeOf(call.state.value.audioOutputDevice);
      if (_telecom) {
        // Telecom routed the ringing call already; decide once from both
        // (a headset wins) and apply it to Telecom and the engine.
        route = nextAudioRoute(current: engineRoute ?? route, before: const {}, now: availableRoutes);
        await setRoute(route, quiet: true);
      } else {
        route = engineRoute ?? route;
        await _refreshRoutes();
      }
    } catch (error) {
      debugPrint('[CallController] connect failed: $error');
      if (_current(attempt)) await hangUp(copy: CallEndCopy.failed);
    }
  }

  void _onCallState(int attempt, sv.CallState state) {
    if (!_current(attempt) || phase == CallPhase.ended) return;
    final status = state.status;
    if (status is sv.CallStatusDisconnected) {
      // Stream ended the call (the server or the time limit) or we left.
      unawaited(hangUp(copy: CallEndCopy.ended, alreadyLeft: true));
      return;
    }
    var changed = false;
    final nowReconnecting =
        status is sv.CallStatusReconnecting || status is sv.CallStatusMigrating;
    if (nowReconnecting != reconnecting) {
      reconnecting = nowReconnecting;
      changed = true;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      if (nowReconnecting) {
        unawaited(_platform.playTone('reconnecting'));
        _reconnectTimer = Timer(reconnectLimit, () {
          if (_current(attempt) && reconnecting) unawaited(hangUp(copy: CallEndCopy.failed));
        });
      }
    }
    // Held: an audio track the connection rebuilt meanwhile stays silent.
    final held = _call;
    if (onHold && held != null) _setOtherMemberAudio(held, heard: false);
    final otherHere = state.callParticipants.any((p) => !p.isLocal);
    if (otherHere) {
      _otherGoneTimer?.cancel();
      _otherGoneTimer = null;
      if (connectedAt == null) {
        connectedAt = DateTime.now();
        phase = CallPhase.active;
        _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick(attempt));
        unawaited(_refreshOngoing(connected: true));
        unawaited(_platform.callConnected());
        unawaited(_platform.playTone('connected'));
        unawaited(HapticFeedback.mediumImpact());
        changed = true;
      }
    } else if (connectedAt != null && _otherGoneTimer == null) {
      // The other member dropped out. The server ends the call when Stream
      // confirms they left; if that signal never reaches us, hang up after
      // the grace period instead of on a momentary blip.
      _otherGoneTimer = Timer(otherMemberGrace, () {
        if (_current(attempt) && phase == CallPhase.active) {
          unawaited(hangUp(copy: CallEndCopy.ended));
        }
      });
    }
    // Audio levels change many times a second; only real changes redraw.
    if (changed) notifyListeners();
  }

  void _onTick(int attempt) {
    if (!_current(attempt) || phase != CallPhase.active) return;
    // The paid time is over: the caller's phone ends the call now, with the
    // end tone and "Your call minutes ran out" (spec 12.9); the other phone
    // follows when the server ends it. Stream's limit (30 s later, the
    // connect allowance) stays as the backstop.
    if (isCaller && !extending && maxDurationSeconds > 0 && secondsLeftNow <= 0) {
      unawaited(hangUp(copy: CallEndCopy.timeUp));
      return;
    }
    // Stream's timer is the hard stop; leave just after it in case its
    // event is lost.
    if (DateTime.now().difference(connectedAt!).inSeconds > maxDurationSeconds + 5) {
      unawaited(hangUp(copy: CallEndCopy.timeUp));
      return;
    }
    unawaited(_refreshOngoing());
    final now = warning;
    if (now != _lastWarning) {
      _lastWarning = now;
      if (now != CallTimeWarning.none) {
        unawaited(_platform.playTone('warning'));
        unawaited(HapticFeedback.heavyImpact());
      }
    }
    notifyListeners();
  }

  /// Notification buttons, Telecom and the phone-call watcher
  /// (packages/silarah_calls). Only acts on the call that is on now.
  void _onPlatformEvent(CallEvent event) {
    switch (event.type) {
      case 'hangUp':
        if (busy) unawaited(hangUp());
      case 'toggleMute':
        if (phase == CallPhase.connecting || phase == CallPhase.active) unawaited(toggleMute());
      case 'declined':
        // Declined from the notification while the incoming screen is open.
        if (phase == CallPhase.incoming && event.requestId == requestId) {
          unawaited(_finish(_attempt, CallEndCopy.declined));
        }
      case 'phoneCall':
        _onInterrupted(event.active);
      case 'telecom':
        _telecom = event.available;
      case 'route':
        final next = _routeNamed(event.route);
        if (_telecom && next != null && next != route) {
          // Telecom moved the call (a headset button, the car, the system):
          // the audio engine follows, so both agree.
          unawaited(setRoute(next, telecomChose: true));
        }
      case 'routes':
        if (_telecom) {
          final routes = event.routes.map(_routeNamed).whereType<CallAudioRoute>().toSet();
          if (routes.isNotEmpty) {
            final before = availableRoutes;
            availableRoutes = routes;
            routeNames = {
              for (final entry in event.routeNames.entries)
                if (_routeNamed(entry.key) case final r?) r: entry.value,
            };
            final next = nextAudioRoute(current: route, before: before, now: routes);
            if (next != route) unawaited(setRoute(next));
            notifyListeners();
          }
        }
    }
  }

  static CallAudioRoute? _routeNamed(String? name) => switch (name) {
        'earpiece' => CallAudioRoute.earpiece,
        'speaker' => CallAudioRoute.speaker,
        'bluetooth' => CallAudioRoute.bluetooth,
        'wired' => CallAudioRoute.wired,
        _ => null,
      };

  void _onInterrupted(bool interrupted) {
    final call = _call;
    if (call == null || interrupted == onHold) return;
    onHold = interrupted;
    // A regular phone call took the audio: the call is held both ways, like
    // a held phone call. The other member does not hear it (microphone off)
    // and is not heard over it (their audio off); both come back when it
    // is over (the microphone only if the member had not muted it).
    unawaited(call.setMicrophoneEnabled(enabled: !interrupted && !muted));
    _setOtherMemberAudio(call, heard: !interrupted);
    // Telecom put the call on hold; it is ours again once the phone call ends.
    if (!interrupted && _telecom) unawaited(_platform.resumeAfterPhoneCall());
    notifyListeners();
  }

  /// Plays or silences the other member's audio on this phone.
  static void _setOtherMemberAudio(sv.Call call, {required bool heard}) {
    for (final participant in call.state.value.callParticipants) {
      if (participant.isLocal) continue;
      final track = call.getTrack(participant.trackIdPrefix, sv.SfuTrackType.audio);
      if (track == null) continue;
      if (heard) {
        track.enable();
      } else {
        track.disable();
      }
    }
  }

  Future<void> toggleMute() async {
    final call = _call;
    if (call == null) return;
    muted = !muted;
    notifyListeners();
    unawaited(_platform.updateCall(muted: muted));
    await call.setMicrophoneEnabled(enabled: !muted && !onHold);
  }

  // ---------------------------------------------------------------------------
  // Microphone foreground service: Android starts it only while Silarah is
  // in front, so it is started then, or as soon as the member comes back.
  // ---------------------------------------------------------------------------

  void _wantService(bool wanted) {
    _serviceWanted = wanted;
    if (wanted && !_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    unawaited(_syncService());
  }

  Future<void> _syncService() async {
    final id = requestId;
    if (_serviceWanted && !_serviceRunning && id != null) {
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
      final code = await CallNotifications.languageCode();
      _shownMinutesLeft = _minutesLeftForNotice();
      _serviceRunning = await _platform.startCall(
        requestId: id,
        name: otherName.isEmpty ? callingCopyFor(code, 'A Silarah member') : otherName,
        outgoing: isCaller,
        text: _ongoingText(code),
        muteLabel: callingCopyFor(code, 'Mute'),
        unmuteLabel: callingCopyFor(code, 'Unmute'),
        connectedAt: connectedAt,
        muted: muted,
      );
    } else if (!_serviceWanted) {
      _serviceRunning = false;
      _telecom = false;
      await _platform.stopCall();
    }
  }

  /// Minutes left as the ongoing notification shows them: the caller's only
  /// (the callee never pays), -1 when not shown.
  int _minutesLeftForNotice() =>
      isCaller && connectedAt != null ? minutesLeftOfHold.clamp(0, 999) : -1;

  String _ongoingText(String code) {
    if (connectedAt == null) {
      return callingCopyFor(code, phase == CallPhase.outgoing ? 'Ringing…' : 'Connecting…');
    }
    final minutes = _minutesLeftForNotice();
    if (minutes < 0) return callingCopyFor(code, 'Silarah voice call');
    return callingCopyFor(code, '{minutes} min left').replaceAll('{minutes}', '$minutes');
  }

  /// Timer start, mute and minutes left on the ongoing notification.
  Future<void> _refreshOngoing({bool connected = false}) async {
    if (!_serviceRunning) return;
    final minutes = _minutesLeftForNotice();
    if (!connected && minutes == _shownMinutesLeft) return;
    _shownMinutesLeft = minutes;
    final code = await CallNotifications.languageCode();
    await _platform.updateCall(
      text: _ongoingText(code),
      connectedAt: connected ? connectedAt : null,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_syncService());
  }

  // ---------------------------------------------------------------------------
  // Audio route
  // ---------------------------------------------------------------------------

  Future<void> _refreshRoutes() async {
    // With Telecom, its endpoint list is the truth ('routes' events).
    if (_telecom) return;
    final result = await sv.RtcMediaDeviceNotifier.instance.audioOutputs();
    final devices = result.getDataOrNull() ?? const <sv.RtcMediaDevice>[];
    final routes = <CallAudioRoute>{CallAudioRoute.speaker};
    final names = <CallAudioRoute, String>{};
    for (final device in devices) {
      final r = _routeOf(device);
      if (r != null) {
        routes.add(r);
        if (device.label.trim().isNotEmpty) names.putIfAbsent(r, () => device.label.trim());
      }
    }
    if (!routes.contains(CallAudioRoute.wired)) routes.add(CallAudioRoute.earpiece);
    final before = availableRoutes;
    availableRoutes = routes;
    routeNames = names;
    final next = nextAudioRoute(current: route, before: before, now: routes);
    if (next != route) await setRoute(next, quiet: true);
    notifyListeners();
  }

  static CallAudioRoute? _routeOf(sv.RtcMediaDevice? device) {
    if (device == null) return null;
    final key = '${device.id} ${device.label}'.toLowerCase();
    if (key.contains('bluetooth')) return CallAudioRoute.bluetooth;
    if (key.contains('speaker')) return CallAudioRoute.speaker;
    if (key.contains('wired') || key.contains('headset') || key.contains('headphone')) {
      return CallAudioRoute.wired;
    }
    if (key.contains('earpiece') || key.contains('receiver')) return CallAudioRoute.earpiece;
    return null;
  }

  /// Sends the call's audio to [next]. One decision, applied to every layer
  /// that routes audio: Telecom (while it holds the call) and the audio
  /// engine, so neither undoes the other later.
  Future<void> setRoute(CallAudioRoute next, {bool quiet = false, bool telecomChose = false}) async {
    final call = _call;
    if (call == null) {
      // Ringing: no audio engine yet. Remember Telecom's route for the join.
      if (telecomChose) route = next;
      return;
    }
    if (_telecom && !telecomChose) await _platform.setAudioRoute(next.name);
    final result = await sv.RtcMediaDeviceNotifier.instance.audioOutputs();
    final devices = result.getDataOrNull() ?? const <sv.RtcMediaDevice>[];
    final device = devices.where((d) => _routeOf(d) == next).firstOrNull;
    if (device != null) await call.setAudioOutputDevice(device);
    route = next;
    // Screen off at the ear only when the phone itself is the speaker.
    await _platform.setProximity(next == CallAudioRoute.earpiece);
    if (!quiet) notifyListeners();
  }

  /// "Still talking?" or after a top-up: hold more minutes (caller only).
  Future<String> extend() async {
    final id = requestId;
    if (id == null || !isCaller || extending || phase != CallPhase.active) return 'not_allowed';
    final attempt = _attempt;
    extending = true;
    notifyListeners();
    try {
      final result = await _api.extend(id);
      if (_current(attempt) && result.outcome == 'extended') {
        maxDurationSeconds = result.maxDurationSeconds ?? maxDurationSeconds;
        holdMinutes = result.holdMinutes ?? holdMinutes;
      }
      return result.outcome;
    } finally {
      extending = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Ending
  // ---------------------------------------------------------------------------

  /// Hang up, cancel an outgoing ring, or leave after the server ended it.
  Future<void> hangUp({String copy = CallEndCopy.ended, bool alreadyLeft = false}) async {
    if (phase == CallPhase.idle || phase == CallPhase.ended) return;
    final attempt = _attempt;
    final id = requestId;
    if (id != null) {
      // Tell the server first; it ends the call on Stream for both.
      unawaited(_api.end(id, reason: phase == CallPhase.outgoing ? 'cancelled' : 'hangup'));
    }
    await _finish(attempt, copy, leave: !alreadyLeft, endedByMember: !alreadyLeft && copy == CallEndCopy.ended);
  }

  Future<void> _leave(sv.Call? call, sv.StreamVideo? client) async {
    if (call != null) {
      try {
        await call.leave();
      } catch (_) {}
    }
    if (client != null) {
      try {
        await sv.StreamVideo.reset(disconnect: true);
      } catch (_) {}
    }
  }

  Future<void> _finish(int attempt, String copy, {bool leave = true, bool endedByMember = false}) async {
    if (!_current(attempt) || phase == CallPhase.ended) return;
    // Mark ended first so nothing re-enters while we tidy up.
    phase = CallPhase.ended;
    endedCopy = copy;
    onHold = false;
    reconnecting = false;
    _clearTimers();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    final call = _call;
    final client = _client;
    final tone = callEndTone(
      copy: copy,
      connected: connectedAt != null,
      ringingOut: isCaller && call == null,
      endedByMember: endedByMember,
    );
    _call = null;
    _client = null;
    notifyListeners();
    await _platform.stopTone();
    // While the call's audio is still up, so the tone takes the call's route.
    if (tone != null) await _platform.playTone(tone);
    if (leave) {
      await _leave(call, client);
    } else if (client != null) {
      await _leave(null, client);
    }
    final id = requestId;
    if (id != null) await CallNotifications.cancel(id);
    _wantService(false);
    _shownMinutesLeft = -1;
    await _platform.setProximity(false);
    await _platform.stopPhoneCallWatch();
    await _platform.setCallWindow(false);
    historyChanged();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (_current(attempt) && phase == CallPhase.ended) {
        _resetFields();
        notifyListeners();
      }
    });
  }

  void _clearTimers() {
    _pollTimer?.cancel();
    _tick?.cancel();
    _resetTimer?.cancel();
    _otherGoneTimer?.cancel();
    _otherGoneTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _resetFields() {
    phase = CallPhase.idle;
    requestId = null;
    matchId = null;
    otherUserId = null;
    otherName = '';
    isCaller = false;
    muted = false;
    onHold = false;
    reconnecting = false;
    route = CallAudioRoute.earpiece;
    routeNames = const {};
    availableRoutes = const {CallAudioRoute.earpiece, CallAudioRoute.speaker};
    _lastWarning = CallTimeWarning.none;
    connectedAt = null;
    maxDurationSeconds = 0;
    holdMinutes = 0;
    incoming = null;
    ringEndsAt = null;
    endedCopy = CallEndCopy.ended;
  }

  static void _streamLog(
    sv.Priority priority,
    String tag,
    sv.MessageBuilder message, [
    Object? error,
    StackTrace? stk,
  ]) {
    debugPrint('[Stream/$tag] ${message()}${error == null ? '' : ' :: $error'}');
  }

  @override
  void dispose() {
    unawaited(_platformEvents?.cancel());
    super.dispose();
  }

  /// Sign-out: end any call of the departing account at once.
  Future<void> onSignedOut() async {
    if (busy) await hangUp();
    _begin();
    _resetFields();
    notifyListeners();
  }
}
