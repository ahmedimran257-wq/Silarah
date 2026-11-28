// SILARAH — Notification Preferences State
//
//   new_interest, interest_accepted, new_message,
//   profile_live, interest_expiring, inactive_nudge,
//   boost_available, festival_greetings + quiet_start / quiet_end (23:00–08:00)
//
// Step 12: replace toggles with Supabase UPSERT on change.
import 'package:equatable/equatable.dart';

enum DiscoveryDigestFrequency {
  off('off'),
  daily('daily'),
  weekly('weekly');

  const DiscoveryDigestFrequency(this.dbValue);
  final String dbValue;

  static DiscoveryDigestFrequency fromDb(Object? value) {
    final token = value?.toString().toLowerCase();
    return values.firstWhere(
      (frequency) => frequency.dbValue == token,
      orElse: () => DiscoveryDigestFrequency.off,
    );
  }
}

class NotificationPrefsState extends Equatable {
  static const _unchanged = Object();

  final bool newInterest;
  final bool interestAccepted;
  final bool newMessage;
  final bool profileView;
  final bool profileLive;
  final bool newCompatibleProfiles;
  final DiscoveryDigestFrequency discoveryDigestFrequency;
  final bool interestExpiring;
  final bool inactiveNudge;
  final bool boostAvailable;
  final bool festivalGreetings;

  /// Missed-call notifications (docs/voice_calling_spec.md 12.3). Ringing
  /// itself is controlled by Ring / Silent / Calls off.
  final bool missedCall;

  /// Quiet hours — 23:00 to 08:00 (database defaults)
  final int quietStartHour; // 23
  final int quietEndHour; // 8
  final bool isLoaded;
  final bool isSaving;
  final String? syncError;
  final int syncEvent;

  const NotificationPrefsState({
    this.newInterest = true,
    this.interestAccepted = true,
    this.newMessage = true,
    this.profileView = true,
    this.profileLive = true,
    this.newCompatibleProfiles = true,
    this.discoveryDigestFrequency = DiscoveryDigestFrequency.off,
    this.interestExpiring = true,
    this.inactiveNudge = true,
    this.boostAvailable = true,
    this.festivalGreetings = true,
    this.missedCall = true,
    this.quietStartHour = 23,
    this.quietEndHour = 8,
    this.isLoaded = false,
    this.isSaving = false,
    this.syncError,
    this.syncEvent = 0,
  });

  NotificationPrefsState copyWith({
    bool? newInterest,
    bool? interestAccepted,
    bool? newMessage,
    bool? profileView,
    bool? profileLive,
    bool? newCompatibleProfiles,
    DiscoveryDigestFrequency? discoveryDigestFrequency,
    bool? interestExpiring,
    bool? inactiveNudge,
    bool? boostAvailable,
    bool? festivalGreetings,
    bool? missedCall,
    int? quietStartHour,
    int? quietEndHour,
    bool? isLoaded,
    bool? isSaving,
    Object? syncError = _unchanged,
    int? syncEvent,
  }) {
    return NotificationPrefsState(
      newInterest: newInterest ?? this.newInterest,
      interestAccepted: interestAccepted ?? this.interestAccepted,
      newMessage: newMessage ?? this.newMessage,
      profileView: profileView ?? this.profileView,
      profileLive: profileLive ?? this.profileLive,
      newCompatibleProfiles:
          newCompatibleProfiles ?? this.newCompatibleProfiles,
      discoveryDigestFrequency:
          discoveryDigestFrequency ?? this.discoveryDigestFrequency,
      interestExpiring: interestExpiring ?? this.interestExpiring,
      inactiveNudge: inactiveNudge ?? this.inactiveNudge,
      boostAvailable: boostAvailable ?? this.boostAvailable,
      festivalGreetings: festivalGreetings ?? this.festivalGreetings,
      missedCall: missedCall ?? this.missedCall,
      quietStartHour: quietStartHour ?? this.quietStartHour,
      quietEndHour: quietEndHour ?? this.quietEndHour,
      isLoaded: isLoaded ?? this.isLoaded,
      isSaving: isSaving ?? this.isSaving,
      syncError: identical(syncError, _unchanged)
          ? this.syncError
          : syncError as String?,
      syncEvent: syncEvent ?? this.syncEvent,
    );
  }

  @override
  List<Object?> get props => [
        newInterest,
        interestAccepted,
        newMessage,
        profileView,
        profileLive,
        newCompatibleProfiles,
        discoveryDigestFrequency,
        interestExpiring,
        inactiveNudge,
        boostAvailable,
        festivalGreetings,
        missedCall,
        quietStartHour,
        quietEndHour,
        isLoaded,
        isSaving,
        syncError,
        syncEvent,
      ];
}
