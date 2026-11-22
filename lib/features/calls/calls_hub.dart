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

  /// Calls tab shown (server switch on for this member).
  final ValueNotifier<bool> tabVisible = ValueNotifier<bool>(false);

  /// Unseen missed calls (the tab badge).
  final ValueNotifier<int> unseenMissed = ValueNotifier<int>(0);

  CallOverview? overview;

  /// False when notifications or the incoming-call channel are off here.
  bool phoneCanRing = true;

  bool _active = false;
  bool _refreshing = false;
  bool _refreshAgain = false;

  /// A member's session began (never for Guardian-only accounts).
  Future<void> start() async {
    if (_active) return;
    _active = true;
    WidgetsBinding.instance.addObserver(this);
    CallController.historyVersion.addListener(_onHistoryChanged);
    try {
      final prefs = await SharedPreferences.getInstance();
      tabVisible.value = prefs.getBool(_tabKey) ?? false;
    } catch (_) {}
    await Future.wait([refresh(), reportRingCapability()]);
  }

  /// Sign-out: nothing of the departing member stays.
  Future<void> stop() async {
    if (!_active) return;
    _active = false;
    WidgetsBinding.instance.removeObserver(this);
    CallController.historyVersion.removeListener(_onHistoryChanged);
    overview = null;
    unseenMissed.value = 0;
    tabVisible.value = false;
    notifyListeners();
  }

  void _onHistoryChanged() => unawaited(refresh());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _active) {
      unawaited(refresh());
      unawaited(reportRingCapability());
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
        final next = await _api.overview();
        if (!_active) return;
        if (next != null) {
          overview = next;
          unseenMissed.value = next.unseenMissed;
          if (tabVisible.value != next.callsEnabled) {
            tabVisible.value = next.callsEnabled;
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(_tabKey, next.callsEnabled);
            } catch (_) {}
          }
          notifyListeners();
        }
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
