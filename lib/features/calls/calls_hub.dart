// App-wide calling state for the signed-in member (docs/voice_calling_spec.md
// 12.2 and 12.5): whether the Calls tab is shown (server switch), its
// missed-call badge, the overview above the history, and whether this
// phone can ring (reported to the server, which rings only phones that can).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/fcm_service.dart';

import 'call_api.dart';
import 'call_controller.dart';
import 'call_log.dart';
import 'call_notifications.dart';
import 'call_platform.dart';
import 'calling_rules.dart';

class CallsHub extends ChangeNotifier with WidgetsBindingObserver {
  CallsHub({CallApi? api, CallPlatform? platform})
      : _api = api ?? CallApi.instance,
        _platform = platform ?? CallPlatform.instance;

  static final CallsHub instance = CallsHub();

  // The last known switch state, so the tab bar does not change shape on
  // every launch while the overview loads.
  static const _tabKey = 'silarah_calls_tab_visible_v1';

  final CallApi _api;
  final CallPlatform _platform;

  /// The server's calling rules (switch and every number members are told).
  /// Null until loaded or when signed out.
  final ValueNotifier<CallingRules?> rules = ValueNotifier<CallingRules?>(null);

  /// The one gate for every calling surface (spec 12.6): the Calls tab, call
  /// settings, the missed-call toggle, the guide and Help article, call
  /// buttons, minutes and packs, the Premium benefit and the Guardian call
  /// log. Off (or unknown) means the app looks as it does without calling.
  bool get callingOn => rules.value?.callsEnabled ?? false;

  /// Calls tab shown (server switch on for this member).
  final ValueNotifier<bool> tabVisible = ValueNotifier<bool>(false);

  /// Unseen missed calls (the tab badge).
  final ValueNotifier<int> unseenMissed = ValueNotifier<int>(0);

  CallOverview? overview;

  /// False when notifications or the incoming-call channel are off here.
  bool phoneCanRing = true;

  bool _active = false;
  bool _member = false;
  bool _refreshing = false;
  bool _refreshAgain = false;

  // A call is settled a few seconds after it ends: check again until the
  // minutes and talk time are final, then tell every view.
  static const settleCheckEvery = Duration(seconds: 3);
  static const settleChecks = 20;
  Timer? _settleTimer;
  int _settleChecksLeft = 0;
  bool _wasSettling = false;

  /// A session began. [member]: a member account (Calls tab, minutes, ring
  /// capability); false for Guardian-only accounts, which only need the
  /// switch (their call log follows it).
  Future<void> start({bool member = true}) async {
    if (_active) return;
    _active = true;
    _member = member;
    WidgetsBinding.instance.addObserver(this);
    CallController.historyVersion.addListener(_onHistoryChanged);
    if (member) {
      try {
        final prefs = await SharedPreferences.getInstance();
        tabVisible.value = prefs.getBool(_tabKey) ?? false;
      } catch (_) {}
    }
    await Future.wait([refresh(), if (member) reportRingCapability()]);
  }

  /// Sign-out: nothing of the departing member stays.
  Future<void> stop() async {
    if (!_active) return;
    _active = false;
    WidgetsBinding.instance.removeObserver(this);
    CallController.historyVersion.removeListener(_onHistoryChanged);
    overview = null;
    rules.value = null;
    unseenMissed.value = 0;
    tabVisible.value = false;
    _settleTimer?.cancel();
    _settleTimer = null;
    _wasSettling = false;
    notifyListeners();
  }

  void _followSettlement(bool settling) {
    _settleTimer?.cancel();
    _settleTimer = null;
    if (settling) {
      if (!_wasSettling) _settleChecksLeft = settleChecks;
      _wasSettling = true;
      if (_settleChecksLeft-- > 0) {
        _settleTimer = Timer(settleCheckEvery, () => unawaited(refresh()));
      }
    } else if (_wasSettling) {
      // Settled: the call log, the chat and this overview reload once.
      _wasSettling = false;
      CallController.historyChanged();
    }
  }

  void _onHistoryChanged() => unawaited(refresh());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _active) {
      unawaited(refresh());
      if (_member) unawaited(reportRingCapability());
    }
  }

  /// Reloads the overview; concurrent calls fold into one more run.
  Future<void> refresh() async {
    if (!_active) return;
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        final nextRules = await _api.rules();
        if (!_active) return;
        if (nextRules != null) rules.value = nextRules;
        // Calling off: nothing else to load, and nothing is shown.
        final on = callingOn;
        final next = _member && on ? await _api.overview() : null;
        if (!_active) return;
        if (next != null) {
          overview = next;
          unseenMissed.value = next.unseenMissed;
          _followSettlement(next.settling);
        } else if (nextRules != null && !on) {
          overview = null;
          unseenMissed.value = 0;
        }
        if (nextRules != null) {
          final visible = _member && on;
          if (tabVisible.value != visible) {
            tabVisible.value = visible;
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(_tabKey, visible);
            } catch (_) {}
          }
        }
        notifyListeners();
      } while (_refreshAgain && _active);
    } finally {
      _refreshing = false;
    }
  }

  /// Opening the Calls tab: the badge clears here and on other phones.
  Future<void> markSeen() async {
    unawaited(CallNotifications.clearMissed());
    if (unseenMissed.value == 0) return;
    unseenMissed.value = 0;
    await _api.markSeen();
  }

  /// Tells the server whether this phone can ring (spec 12.2.4).
  Future<void> reportRingCapability() async {
    final canRing = await _platform.canRing();
    if (canRing != phoneCanRing) {
      phoneCanRing = canRing;
      notifyListeners();
    }
    try {
      final deviceId = await FcmService.instance.deviceId();
      await _api.reportRingCapability(deviceId: deviceId, canRing: canRing);
    } catch (_) {}
  }
}
