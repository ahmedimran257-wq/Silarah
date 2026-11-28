// SILARAH — Notification Preferences Cubit (Supabase production flow)
//
// Each toggle maps directly to a column in the notification_prefs
// DB table. In real mode: upserts to Supabase on every toggle.
//
// Firebase Cloud Messaging (FCM) integration notes:
//   - On app start: FCM token obtained via FirebaseMessaging.instance.getToken()
//   - On login:    FCM token saved to user_fcm_tokens table in Supabase
//   - On delete:   FCM token row deleted from user_fcm_tokens (ghost push prevention)
//   - On refresh:  FirebaseMessaging.instance.onTokenRefresh saves new token to DB
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/supabase_service.dart';
import 'notification_prefs_state.dart';

class NotificationPrefsCubit extends Cubit<NotificationPrefsState> {
  NotificationPrefsCubit() : super(const NotificationPrefsState());

  bool get _isRealMode => SupabaseService.isInitialized;
  Timer? _persistDebounce;
  int _persistVersion = 0;
  NotificationPrefsState _lastPersisted = const NotificationPrefsState();

  // Load prefs from DB on login
  /// Load notification preferences from Supabase for the current user.
  Future<void> loadPrefs() async {
    if (!_isRealMode) return;

    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      final row = await SupabaseService.client
          .from('notification_prefs')
          .select(
            'new_interest, interest_accepted, new_message, profile_view, profile_live, '
            'new_compatible_profiles, discovery_digest_frequency, '
            'interest_expiring, inactive_nudge, boost_available, '
            'festival_greetings, missed_call, quiet_start, quiet_end',
          )
          .eq('user_id', userId)
          .maybeSingle();

      if (!isClosed) {
        final data = row ?? const <String, dynamic>{};
        final loaded = NotificationPrefsState(
          newInterest: (data['new_interest'] as bool?) ?? true,
          interestAccepted: (data['interest_accepted'] as bool?) ?? true,
          newMessage: (data['new_message'] as bool?) ?? true,
          profileView: (data['profile_view'] as bool?) ?? true,
          profileLive: (data['profile_live'] as bool?) ?? true,
          newCompatibleProfiles:
              (data['new_compatible_profiles'] as bool?) ?? true,
          discoveryDigestFrequency: DiscoveryDigestFrequency.fromDb(
            data['discovery_digest_frequency'],
          ),
          interestExpiring: (data['interest_expiring'] as bool?) ?? true,
          inactiveNudge: (data['inactive_nudge'] as bool?) ?? true,
          boostAvailable: (data['boost_available'] as bool?) ?? true,
          festivalGreetings: (data['festival_greetings'] as bool?) ?? true,
          missedCall: (data['missed_call'] as bool?) ?? true,
          quietStartHour: _timeToHour(data['quiet_start'] as String?, 23),
          quietEndHour: _timeToHour(data['quiet_end'] as String?, 8),
          isLoaded: true,
        );
        _lastPersisted = loaded;
        emit(loaded);
      }
    } catch (e) {
      debugPrint('[NotificationPrefsCubit] Error loading prefs: $e');
      if (!isClosed) {
        emit(state.copyWith(
          isLoaded: true,
          isSaving: false,
          syncError: 'Notification settings could not be loaded. Try again.',
          syncEvent: state.syncEvent + 1,
        ));
      }
    }
  }

  // Toggle methods — one per DB column
  void toggleNewInterest(bool value) {
    _emitChange(state.copyWith(newInterest: value));
  }

  void toggleInterestAccepted(bool value) {
    _emitChange(state.copyWith(interestAccepted: value));
  }

  void toggleNewMessage(bool value) {
    _emitChange(state.copyWith(newMessage: value));
  }

  void toggleProfileView(bool value) {
    _emitChange(state.copyWith(profileView: value));
  }

  void toggleProfileLive(bool value) {
    _emitChange(state.copyWith(profileLive: value));
  }

  void toggleNewCompatibleProfiles(bool value) {
    _emitChange(state.copyWith(
      newCompatibleProfiles: value,
      discoveryDigestFrequency:
          value ? state.discoveryDigestFrequency : DiscoveryDigestFrequency.off,
    ));
  }

  void setDiscoveryDigestFrequency(DiscoveryDigestFrequency value) {
    _emitChange(state.copyWith(
      discoveryDigestFrequency: value,
      newCompatibleProfiles: value == DiscoveryDigestFrequency.off
          ? state.newCompatibleProfiles
          : true,
    ));
  }

  void toggleInterestExpiring(bool value) {
    _emitChange(state.copyWith(interestExpiring: value));
  }

  void toggleInactiveNudge(bool value) {
    _emitChange(state.copyWith(inactiveNudge: value));
  }

  void toggleBoostAvailable(bool value) {
    _emitChange(state.copyWith(boostAvailable: value));
  }

  void toggleFestivalGreetings(bool value) {
    _emitChange(state.copyWith(festivalGreetings: value));
  }

  void toggleMissedCall(bool value) {
    _emitChange(state.copyWith(missedCall: value));
  }

  // Quiet hours
  void setQuietHours({required int startHour, required int endHour}) {
    _emitChange(state.copyWith(
      quietStartHour: startHour,
      quietEndHour: endHour,
    ));
  }

  // Reset all to defaults
  void resetToDefaults() {
    _emitChange(const NotificationPrefsState(isLoaded: true));
  }

  void clear() {
    _persistDebounce?.cancel();
    _persistVersion++;
    _lastPersisted = const NotificationPrefsState();
    if (!isClosed) emit(const NotificationPrefsState());
  }

  void _emitChange(NotificationPrefsState next) {
    emit(next.copyWith(
      isLoaded: true,
      isSaving: true,
      syncError: null,
    ));
    _schedulePersist();
  }

  // Persistence helper
  void _schedulePersist() {
    final version = ++_persistVersion;
    _persistDebounce?.cancel();
    // Race fix: rapid toggles are debounced and versioned so an older async
    // upsert cannot overwrite the latest in-memory preference state.
    _persistDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_persist(version, state));
    });
  }

  Future<void> _persist(
    int version,
    NotificationPrefsState snapshot,
  ) async {
    if (!_isRealMode) return;
    if (version != _persistVersion) return;

    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    if (version != _persistVersion) return;

    try {
      await SupabaseService.client.from('notification_prefs').upsert({
        'user_id': userId,
        'new_interest': snapshot.newInterest,
        'interest_accepted': snapshot.interestAccepted,
        'new_message': snapshot.newMessage,
        'profile_view': snapshot.profileView,
        'profile_live': snapshot.profileLive,
        'new_compatible_profiles': snapshot.newCompatibleProfiles,
        'discovery_digest_frequency': snapshot.discoveryDigestFrequency.dbValue,
        'interest_expiring': snapshot.interestExpiring,
        'inactive_nudge': snapshot.inactiveNudge,
        'boost_available': snapshot.boostAvailable,
        'festival_greetings': snapshot.festivalGreetings,
        'missed_call': snapshot.missedCall,
        'quiet_start':
            '${snapshot.quietStartHour.toString().padLeft(2, '0')}:00',
        'quiet_end': '${snapshot.quietEndHour.toString().padLeft(2, '0')}:00',
      }, onConflict: 'user_id');
      if (version != _persistVersion || isClosed) return;
      final saved = snapshot.copyWith(
        isLoaded: true,
        isSaving: false,
        syncError: null,
      );
      _lastPersisted = saved;
      emit(saved);
    } catch (e) {
      debugPrint('[NotificationPrefsCubit] Error persisting prefs: $e');
      if (version == _persistVersion && !isClosed) {
        emit(_lastPersisted.copyWith(
          isLoaded: true,
          isSaving: false,
          syncError: 'Notification settings were not saved. Try again.',
          syncEvent: state.syncEvent + 1,
        ));
      }
    }
  }

  // Helpers
  /// Parse a time string like "23:00:00" → 23
  int _timeToHour(String? timeStr, int fallback) {
    if (timeStr == null || timeStr.isEmpty) return fallback;
    final parts = timeStr.split(':');
    return int.tryParse(parts[0]) ?? fallback;
  }

  @override
  Future<void> close() {
    clear();
    return super.close();
  }
}
