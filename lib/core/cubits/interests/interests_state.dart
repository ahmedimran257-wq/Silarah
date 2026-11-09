// SILARAH — Interests State (Items 17 + 18)
//
//   PENDING → ACCEPTED → MATCH_CREATED (chat unlocked)
//   PENDING → DECLINED
//   PENDING → EXPIRED (server expires_at; currently 14 days)
//   PENDING → WITHDRAWN (sender, silent)
//
import 'package:equatable/equatable.dart';
import '../../models/discovery_profile.dart';

enum InterestStatus {
  pending,
  accepted,
  declined,
  withdrawn,
  expired, // Auto-set after 14 days
}

/// Explains why an otherwise healthy discovery feed may be empty.
///
/// Describes the strongest active relationship currently shown on a discovery
/// card. Profiles remain browsable; the action changes to the appropriate
/// Interests or Chat destination instead of offering a duplicate request.
enum DiscoveryInteractionHandoff {
  none,
  receivedInterest,
  sentInterest,
  matched,
}

/// Authoritative relationship state for one profile. The app never offers a
/// second active interest for the same pair; it hands the member to the stage
/// that already owns that relationship instead.
enum ProfileInteractionState {
  none,
  pendingSent,
  pendingReceived,
  matched,
}

/// Why an interest was not sent, in the words shown to the member. The daily
/// limit is absent because it opens its own sheet.
enum InterestSendFailure {
  generic(
      'Your interest could not be sent. Check your connection and try again.'),
  rematchCooldown('You can reconnect after the 7-day cooling-off period.'),
  noteTooLong('Your note is too long. Please keep it to 150 characters.'),
  alreadyConnected('You already have an interest or match with this member.'),
  profileUnavailable('This profile is unavailable right now.'),
  accountRestricted(
      'Interests are unavailable for this account. Open Help & Support if you believe this is a mistake.');

  const InterestSendFailure(this.message);

  final String message;
}

class InterestEntry extends Equatable {
  const InterestEntry({
    required this.id,
    required this.profile,
    required this.timeAgo,
    required this.sentAt,
    required this.createdAt,
    this.serverExpiresAt,
    this.status = InterestStatus.pending,
    this.note, // D1: optional interest note
  });

  final String id;
  final DiscoveryProfile profile;
  final String timeAgo;
  final DateTime sentAt;
  final DateTime createdAt;
  final DateTime? serverExpiresAt;
  final InterestStatus status;
  final String? note; // D1: personal interest note

  DateTime get expiresAt =>
      serverExpiresAt ?? createdAt.add(const Duration(days: 14));

  bool get isExpired =>
      status == InterestStatus.expired ||
      (status == InterestStatus.pending && !expiresAt.isAfter(DateTime.now()));

  /// Effective status (accounts for computed expiry)
  InterestStatus get effectiveStatus =>
      isExpired ? InterestStatus.expired : status;

  int? get daysRemaining {
    if (effectiveStatus != InterestStatus.pending) return null;
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 0;
    return (remaining.inSeconds / Duration.secondsPerDay).ceil().clamp(0, 14);
  }

  int? get hoursRemaining {
    if (effectiveStatus != InterestStatus.pending) return null;
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 0;
    return (remaining.inSeconds / Duration.secondsPerHour).ceil().clamp(0, 336);
  }

  InterestEntry copyWith({
    String? id,
    InterestStatus? status,
    String? timeAgo,
    String? note,
  }) {
    return InterestEntry(
      id: id ?? this.id,
      profile: profile,
      timeAgo: timeAgo ?? this.timeAgo,
      sentAt: sentAt,
      createdAt: createdAt,
      serverExpiresAt: serverExpiresAt,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props =>
      [id, profile, timeAgo, sentAt, createdAt, serverExpiresAt, status, note];
}

class InterestsState extends Equatable {
  const InterestsState({
    this.received = const [],
    this.sent = const [],
    this.matches = const [],
    this.interestsSentToday = 0,
    this.dailyLimit = 0,
    this.lastResetDate,
    this.quotaResetsAt,
    this.isPremium = false,
    this.limitError = false,
    this.quotaUnavailable = false,
    this.quotaCheckFailed = false,
  });

  final List<InterestEntry> received;
  final List<InterestEntry> sent;
  final List<InterestEntry> matches;

  final int interestsSentToday;
  final int dailyLimit;
  final DateTime? lastResetDate;
  final DateTime? quotaResetsAt;
  final bool isPremium;
  final bool limitError; // true only after hitting the daily cap
  final bool quotaUnavailable;

  /// The member tried to start an interest and the allowance could not be
  /// checked. Only this is surfaced; background refreshes fail silently.
  final bool quotaCheckFailed;

  // Computed getters
  /// Pending received interests (shown with action buttons)
  List<InterestEntry> get pendingReceived => received
      .where((e) => e.effectiveStatus == InterestStatus.pending)
      .toList();

  /// Responded-to received interests (accepted or declined)
  List<InterestEntry> get respondedReceived => received
      .where((e) =>
          e.effectiveStatus == InterestStatus.accepted ||
          e.effectiveStatus == InterestStatus.declined ||
          e.effectiveStatus == InterestStatus.expired)
      .toList();

  /// Combined received for display: pending first, then responded
  List<InterestEntry> get displayReceived =>
      [...pendingReceived, ...respondedReceived];

  /// Unread pending received count (for nav badge)
  int get unreadCount => pendingReceived.length;

  bool get isDailyLimitReached =>
      dailyLimit > 0 && interestsSentToday >= dailyLimit;

  int get remainingToday =>
      (dailyLimit - interestsSentToday).clamp(0, dailyLimit);

  DiscoveryInteractionHandoff get discoveryHandoff {
    if (matches.isNotEmpty) return DiscoveryInteractionHandoff.matched;
    if (pendingReceived.isNotEmpty) {
      return DiscoveryInteractionHandoff.receivedInterest;
    }
    if (sent.any(
      (entry) => entry.effectiveStatus == InterestStatus.pending,
    )) {
      return DiscoveryInteractionHandoff.sentInterest;
    }
    return DiscoveryInteractionHandoff.none;
  }

  ProfileInteractionState interactionWith(String userId) {
    if (matches.any((entry) => entry.profile.id == userId)) {
      return ProfileInteractionState.matched;
    }
    if (pendingReceived.any((entry) => entry.profile.id == userId)) {
      return ProfileInteractionState.pendingReceived;
    }
    if (sent.any(
      (entry) =>
          entry.profile.id == userId &&
          entry.effectiveStatus == InterestStatus.pending,
    )) {
      return ProfileInteractionState.pendingSent;
    }
    return ProfileInteractionState.none;
  }

  InterestsState copyWith({
    List<InterestEntry>? received,
    List<InterestEntry>? sent,
    List<InterestEntry>? matches,
    int? interestsSentToday,
    int? dailyLimit,
    DateTime? lastResetDate,
    DateTime? quotaResetsAt,
    bool? isPremium,
    bool? limitError,
    bool? quotaUnavailable,
    bool? quotaCheckFailed,
    bool clearLimitError = false,
    bool clearQuotaUnavailable = false,
  }) {
    return InterestsState(
      received: received ?? this.received,
      sent: sent ?? this.sent,
      matches: matches ?? this.matches,
      interestsSentToday: interestsSentToday ?? this.interestsSentToday,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      lastResetDate: lastResetDate ?? this.lastResetDate,
      quotaResetsAt: quotaResetsAt ?? this.quotaResetsAt,
      isPremium: isPremium ?? this.isPremium,
      limitError: clearLimitError ? false : (limitError ?? this.limitError),
      quotaUnavailable: clearQuotaUnavailable
          ? false
          : (quotaUnavailable ?? this.quotaUnavailable),
      quotaCheckFailed: clearQuotaUnavailable
          ? false
          : (quotaCheckFailed ?? this.quotaCheckFailed),
    );
  }

  @override
  List<Object?> get props => [
        received,
        sent,
        matches,
        interestsSentToday,
        dailyLimit,
        lastResetDate,
        quotaResetsAt,
        isPremium,
        limitError,
        quotaUnavailable,
        quotaCheckFailed,
      ];
}
