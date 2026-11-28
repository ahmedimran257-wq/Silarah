// Plain data for voice calling. No Flutter or Supabase imports so the rules
// can be unit-tested.

/// What the server answered to "call this person" (edge function `calls`).
enum CallStartOutcome {
  ringing,
  glare,
  unavailable,
  premiumRequired,
  noMinutes,
  balanceNegative,
  limitReached,
  callsDisabled,
  capacity,
  busySelf,
  notAllowed,
  rateLimited,
  consentRequired,
  failed;

  static CallStartOutcome parse(String? value) => switch (value) {
        'ringing' => ringing,
        'glare' => glare,
        'unavailable' => unavailable,
        'premium_required' => premiumRequired,
        'no_minutes' => noMinutes,
        'balance_negative' => balanceNegative,
        'limit_reached' => limitReached,
        'calls_disabled' => callsDisabled,
        'capacity' => capacity,
        'busy_self' => busySelf,
        'not_allowed' || 'account_restricted' => notAllowed,
        'rate_limited' => rateLimited,
        'consent_required' => consentRequired,
        _ => failed,
      };
}

class CallStartResult {
  const CallStartResult(this.outcome, {this.requestId, this.ringSeconds, this.retryAfter, this.quietUntil});
  final CallStartOutcome outcome;
  final String? requestId;

  /// How long the server lets it ring, counted on this phone from now
  /// (never compared with the server's clock).
  final int? ringSeconds;
  final DateTime? retryAfter;

  /// The call did not ring because it is the other member's quiet hours:
  /// when calls ring again (333). The only refusal a caller is told about.
  final DateTime? quietUntil;
}

/// Join details for a live call. The Stream token never leaves memory.
class CallJoinInfo {
  const CallJoinInfo({
    required this.requestId,
    required this.role,
    required this.otherName,
    required this.matchId,
    required this.holdMinutes,
    required this.maxDurationSeconds,
    required this.apiKey,
    required this.token,
    required this.callType,
    required this.callId,
    required this.userId,
    required this.myName,
    required this.otherUserId,
  });

  final String requestId;
  final String role; // caller | callee
  final String otherName;
  final String? matchId;
  final int holdMinutes;
  final int maxDurationSeconds;
  final String apiKey;
  final String token;
  final String callType;
  final String callId;
  final String userId;
  final String myName;

  /// The other member, for Report on the call screen.
  final String? otherUserId;

  bool get isCaller => role == 'caller';

  static CallJoinInfo? fromJson(String requestId, Map<String, dynamic> json) {
    final stream = json['stream'];
    if (json['outcome'] != 'active' || stream is! Map) return null;
    return CallJoinInfo(
      requestId: requestId,
      role: json['role']?.toString() ?? 'callee',
      otherName: json['other_name']?.toString() ?? '',
      myName: json['my_name']?.toString() ?? '',
      matchId: json['match_id']?.toString(),
      holdMinutes: (json['hold_minutes'] as num?)?.toInt() ?? 0,
      maxDurationSeconds: (json['max_duration_seconds'] as num?)?.toInt() ?? 0,
      apiKey: stream['api_key']?.toString() ?? '',
      token: stream['token']?.toString() ?? '',
      callType: stream['call_type']?.toString() ?? 'silarah_voice',
      callId: stream['call_id']?.toString() ?? '',
      userId: stream['user_id']?.toString() ?? '',
      otherUserId: json['other_user_id']?.toString(),
    );
  }
}

/// Minutes and packs (RPC get_my_call_wallet).
class CallWallet {
  const CallWallet({
    required this.callsEnabled,
    required this.premium,
    required this.includedMinutes,
    required this.includedGranted,
    required this.includedPeriodEnd,
    required this.packMinutes,
    required this.heldMinutes,
    required this.availableMinutes,
    required this.canBuyPacks,
    required this.packs,
    this.premiumUntil,
    this.willRenew = false,
    this.consentRequired = false,
  });

  final bool callsEnabled;
  final bool premium;
  final int includedMinutes;
  final int includedGranted;
  final DateTime? includedPeriodEnd;
  final int packMinutes;
  final int heldMinutes;
  final int availableMinutes;
  final bool canBuyPacks;
  final List<CallPack> packs;
  final DateTime? premiumUntil;
  final bool willRenew;
  final bool consentRequired;

  bool get negative => packMinutes < 0;

  CallMinutesTerms get terms => CallMinutesTerms(
        premium: premium,
        periodEnd: includedPeriodEnd,
        premiumUntil: premiumUntil,
        willRenew: willRenew,
        packMinutes: packMinutes,
      );

  factory CallWallet.fromJson(Map<String, dynamic> json) => CallWallet(
        callsEnabled: json['calls_enabled'] == true,
        premium: json['premium'] == true,
        includedMinutes: (json['included_minutes'] as num?)?.toInt() ?? 0,
        includedGranted: (json['included_granted'] as num?)?.toInt() ?? 0,
        includedPeriodEnd:
            DateTime.tryParse(json['included_period_end']?.toString() ?? ''),
        packMinutes: (json['pack_minutes'] as num?)?.toInt() ?? 0,
        heldMinutes: (json['held_minutes'] as num?)?.toInt() ?? 0,
        availableMinutes: (json['available_minutes'] as num?)?.toInt() ?? 0,
        canBuyPacks: json['can_buy_packs'] == true,
        premiumUntil: DateTime.tryParse(json['premium_until']?.toString() ?? ''),
        willRenew: json['will_renew'] == true,
        consentRequired: json['consent_required'] == true,
        packs: [
          for (final pack in (json['packs'] as List? ?? const []))
            if (pack is Map)
              CallPack(
                productId: pack['product_id']?.toString() ?? '',
                minutes: (pack['minutes'] as num?)?.toInt() ?? 0,
              ),
        ],
      );
}

/// What the minutes card and sheet say about when included minutes reset
/// and when Premium ends (docs/voice_calling_spec.md 6.4). It never
/// promises a renewal the server has not confirmed.
class CallMinutesTerms {
  const CallMinutesTerms({
    required this.premium,
    required this.periodEnd,
    required this.premiumUntil,
    required this.willRenew,
    required this.packMinutes,
  });

  final bool premium;
  final DateTime? periodEnd;

  /// End of Premium; null when it has no end date.
  final DateTime? premiumUntil;
  final bool willRenew;
  final int packMinutes;

  /// "Available until {date}": only when Premium will not renew. A renewing
  /// subscription's paid period often ends before the 30-day minutes period
  /// (short months); that is not the end of Premium.
  DateTime? get availableUntil {
    final until = premiumUntil;
    if (!premium || until == null || willRenew) return null;
    return until;
  }

  /// "They reset on {date}": while Premium lasts past the period end (it
  /// renews, has no end date, or ends later).
  DateTime? get resetsOn {
    final end = periodEnd;
    if (!premium || end == null) return null;
    final until = premiumUntil;
    if (willRenew || until == null || until.isAfter(end)) return end;
    return null;
  }

  /// Premium ended with pack minutes left: they are kept.
  bool get packsSavedWhileLapsed => !premium && packMinutes > 0;
}

/// Minutes a call has used so far, the way settlement charges them: every
/// started minute, never more than the hold (docs/voice_calling_spec.md 4).
int chargedMinutesSoFar(int connectedSeconds, int holdMinutes) {
  if (connectedSeconds <= 0 || holdMinutes <= 0) return 0;
  final started = (connectedSeconds + 59) ~/ 60;
  return started > holdMinutes ? holdMinutes : started;
}

class CallPack {
  const CallPack({required this.productId, required this.minutes});
  final String productId;
  final int minutes;
}

/// One call shown in a chat (RPC get_chat_call_state.events).
enum CallEventOutcome { answered, notAnswered, missed, declined, ringing, connectingOrFailed }

class ChatCallEvent {
  const ChatCallEvent({
    required this.id,
    required this.createdAt,
    required this.outgoing,
    required this.outcome,
    required this.durationSeconds,
    required this.live,
  });

  final String id;
  final DateTime createdAt;
  final bool outgoing;
  final CallEventOutcome outcome;
  final int? durationSeconds;
  final bool live;

  static ChatCallEvent? fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['created_at']?.toString() ?? '');
    final id = json['id']?.toString();
    if (created == null || id == null) return null;
    return ChatCallEvent(
      id: id,
      createdAt: created.toLocal(),
      outgoing: json['direction'] == 'outgoing',
      outcome: switch (json['outcome']) {
        'answered' => CallEventOutcome.answered,
        'not_answered' => CallEventOutcome.notAnswered,
        'declined' => CallEventOutcome.declined,
        'ringing' => CallEventOutcome.ringing,
        'connecting_or_failed' => CallEventOutcome.connectingOrFailed,
        _ => CallEventOutcome.missed,
      },
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      live: json['live'] == true,
    );
  }
}

/// Call controls for one chat (RPC get_chat_call_state).
class ChatCallState {
  const ChatCallState({
    required this.callsEnabled,
    required this.canCall,
    required this.reason,
    required this.retryAfter,
    required this.iAmPremium,
    required this.iAmFemale,
    required this.muted,
    required this.callsBlocked,
    required this.events,
  });

  final bool callsEnabled;
  final bool canCall;
  final String? reason;
  final DateTime? retryAfter;
  final bool iAmPremium;
  final bool iAmFemale;
  final bool muted;
  final bool callsBlocked;
  final List<ChatCallEvent> events;

  static const hidden = ChatCallState(
    callsEnabled: false,
    canCall: false,
    reason: 'calls_disabled',
    retryAfter: null,
    iAmPremium: false,
    iAmFemale: false,
    muted: false,
    callsBlocked: false,
    events: [],
  );

  factory ChatCallState.fromJson(Map<String, dynamic> json) => ChatCallState(
        callsEnabled: json['calls_enabled'] == true,
        canCall: json['can_call'] == true,
        reason: json['reason']?.toString(),
        retryAfter: DateTime.tryParse(json['retry_after']?.toString() ?? ''),
        iAmPremium: json['i_am_premium'] == true,
        iAmFemale: json['i_am_female'] == true,
        muted: json['muted'] == true,
        callsBlocked: json['calls_blocked'] == true,
        events: (json['events'] as List? ?? const [])
            .whereType<Map>()
            .map((event) => ChatCallEvent.fromJson(Map<String, dynamic>.from(event)))
            .whereType<ChatCallEvent>()
            .toList(growable: false),
      );

  /// The call button is shown whenever calling is switched on; tapping it
  /// leads a free member to the paywall rather than hiding the feature.
  bool get showCallButton => callsEnabled;
}

/// What the caller is told when the call did not ring (spec 4.1: always
/// the same neutral words, whatever the real reason).
const neutralUnavailableCopy = '{name} isn\'t taking calls right now.';

/// Paid seconds left: the hold itself, counted from when both were
/// connected. (Stream's own limit adds the connect time on top and is only
/// the backstop; it changes when both join, so it is not used here.)
int secondsLeft({
  required int holdMinutes,
  required DateTime connectedAt,
  required DateTime now,
}) {
  final paid = holdMinutes * 60;
  final elapsed = now.difference(connectedAt).inSeconds;
  final left = paid - elapsed;
  return left < 0 ? 0 : left;
}

/// Warnings on the in-call screen, each with a tone (spec 12.9): two
/// minutes left, then 30 seconds. At the 60-minute hold limit the question
/// is "still talking?" instead, two minutes before.
enum CallTimeWarning { none, twoMinutes, thirtySeconds, stillTalking }

CallTimeWarning warningFor(int secondsLeft, {required bool holdWasFull}) {
  if (secondsLeft <= 120 && holdWasFull) return CallTimeWarning.stillTalking;
  if (secondsLeft <= 30) return CallTimeWarning.thirtySeconds;
  if (secondsLeft <= 120) return CallTimeWarning.twoMinutes;
  return CallTimeWarning.none;
}

/// "4:05", "1:02:09".
String formatCallDuration(int totalSeconds) {
  final seconds = totalSeconds < 0 ? 0 : totalSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : '$m';
  return h > 0 ? '$h:$mm:${s.toString().padLeft(2, '0')}' : '$mm:${s.toString().padLeft(2, '0')}';
}
