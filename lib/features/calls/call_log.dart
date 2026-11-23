// Calls tab data (docs/voice_calling_spec.md 12.5, 13): the member's call
// log, the overview above it and planned calls. Everything here is what the
// server decided the member may see; the app only arranges it.
import 'package:flutter/foundation.dart';

import 'call_models.dart';

/// What the member sees for one call (server: private.call_outcome_for).
enum CallLogOutcome {
  answered,
  /// The caller's view of any call that did not connect: never why.
  noAnswer,
  missed,
  declined,
  /// Answered, but the two never connected.
  notConnected,
  ringing,
  live;

  static CallLogOutcome parse(String? value) => switch (value) {
        'answered' => answered,
        'no_answer' => noAnswer,
        'declined' => declined,
        'not_connected' => notConnected,
        'ringing' => ringing,
        'live' => live,
        _ => missed,
      };
}

enum CallLogFilter {
  all,
  missed,
  incoming,
  outgoing,
  planned;

  /// The server's filter name; planned calls come from the overview.
  String get serverName => name;
}

@immutable
class CallLogEntry {
  const CallLogEntry({
    required this.requestId,
    required this.createdAt,
    required this.outgoing,
    required this.outcome,
    required this.talkSeconds,
    required this.minutesUsed,
    required this.matchId,
    required this.otherUserId,
    required this.firstName,
    required this.lastName,
    required this.memberUnavailable,
    required this.unseen,
  });

  final String requestId;
  final DateTime createdAt;
  final bool outgoing;
  final CallLogOutcome outcome;
  final int? talkSeconds;
  final int? minutesUsed;
  final String? matchId;

  /// Null when the member is unavailable (blocked, deleted, banned, off).
  final String? otherUserId;
  final String firstName;

  /// Full surname while matched, the initial otherwise, empty when unavailable.
  final String lastName;
  final bool memberUnavailable;
  final bool unseen;

  bool get missedByMe => !outgoing && outcome == CallLogOutcome.missed;

  /// "Abdul A." / "Abdul Ahmed": the same rule as the chat list.
  String get displayName {
    if (memberUnavailable) return firstName;
    final last = lastName.trim();
    if (last.isEmpty) return firstName;
    return last.length == 1 ? '$firstName $last.' : '$firstName $last';
  }

  /// Rows that collapse together: same person, same chat.
  String get peerKey => memberUnavailable ? 'unavailable:$requestId' : '${otherUserId ?? ''}|${matchId ?? ''}';

  static CallLogEntry? fromJson(Map<String, dynamic> json) {
    final id = json['request_id']?.toString() ?? '';
    final created = DateTime.tryParse(json['created_at']?.toString() ?? '');
    if (id.isEmpty || created == null) return null;
    return CallLogEntry(
      requestId: id,
      createdAt: created.toLocal(),
      outgoing: json['direction'] == 'outgoing',
      outcome: CallLogOutcome.parse(json['outcome']?.toString()),
      talkSeconds: (json['talk_seconds'] as num?)?.toInt(),
      minutesUsed: (json['minutes_used'] as num?)?.toInt(),
      matchId: json['match_id']?.toString(),
      otherUserId: json['other_user_id']?.toString(),
      firstName: (json['other_first_name']?.toString() ?? '').trim(),
      lastName: (json['other_last_name']?.toString() ?? '').trim(),
      memberUnavailable: json['member_unavailable'] == true,
      unseen: json['unseen'] == true,
    );
  }
}

/// What the member can do with a planned call now (server decides).
enum CallPlanAction {
  respond,
  waitForTime,
  call,
  paywall,
  waitForCall,
  none;

  static CallPlanAction parse(String? value) => switch (value) {
        'respond' => respond,
        'wait_for_time' => waitForTime,
        'call' => call,
        'paywall' => paywall,
        'wait_for_call' => waitForCall,
        _ => none,
      };
}

@immutable
class CallPlan {
  const CallPlan({
    required this.id,
    required this.matchId,
    required this.plannedFor,
    required this.status,
    required this.open,
    required this.iProposed,
    required this.otherUserId,
    required this.firstName,
    required this.lastName,
    required this.memberUnavailable,
    required this.action,
  });

  final String id;
  final String matchId;
  final DateTime plannedFor;
  final String status;
  final bool open;
  final bool iProposed;
  final String? otherUserId;
  final String firstName;
  final String lastName;
  final bool memberUnavailable;
  final CallPlanAction action;

  bool get accepted => status == 'accepted';

  String get displayName {
    if (memberUnavailable) return firstName;
    final last = lastName.trim();
    if (last.isEmpty) return firstName;
    return last.length == 1 ? '$firstName $last.' : '$firstName $last';
  }

  static CallPlan? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final at = DateTime.tryParse(json['planned_for']?.toString() ?? '');
    if (id.isEmpty || at == null) return null;
    return CallPlan(
      id: id,
      matchId: json['match_id']?.toString() ?? '',
      plannedFor: at.toLocal(),
      status: json['status']?.toString() ?? 'proposed',
      open: json['open'] == true,
      iProposed: json['i_proposed'] == true,
      otherUserId: json['other_user_id']?.toString(),
      firstName: (json['other_first_name']?.toString() ?? '').trim(),
      lastName: (json['other_last_name']?.toString() ?? '').trim(),
      memberUnavailable: json['member_unavailable'] == true,
      action: CallPlanAction.parse(json['action']?.toString()),
    );
  }

  /// What this member can do right now. The server answered when the page
  /// loaded; once the time comes ([callWindowOpens]) an accepted plan turns
  /// into Call now for a Premium member, the paywall for a free man, and
  /// "they will call you" for a free woman (spec 13.3). The server checks
  /// every call again.
  CallPlanAction actionNow({required bool premium, required bool female, required DateTime now}) {
    if (action != CallPlanAction.waitForTime) return action;
    if (!accepted || !open || now.isBefore(callWindowOpens)) return action;
    if (premium) return CallPlanAction.call;
    return female ? CallPlanAction.waitForCall : CallPlanAction.paywall;
  }

  DateTime get callWindowOpens => plannedFor.subtract(const Duration(minutes: 5));

  static List<CallPlan> listFrom(Object? value) => (value as List? ?? const [])
      .whereType<Map>()
      .map((row) => CallPlan.fromJson(Map<String, dynamic>.from(row)))
      .whereType<CallPlan>()
      .toList(growable: false);
}

/// Everything above the history (RPC get_my_call_overview).
@immutable
class CallOverview {
  const CallOverview({
    required this.callsEnabled,
    required this.premium,
    required this.female,
    required this.callMode,
    required this.includedMinutes,
    required this.includedGranted,
    required this.includedPeriodEnd,
    required this.packMinutes,
    required this.availableMinutes,
    required this.canBuyPacks,
    required this.monthTalkSeconds,
    required this.unseenMissed,
    required this.plans,
    this.premiumUntil,
    this.willRenew = false,
    this.consentRequired = false,
  });

  final bool callsEnabled;
  final bool premium;
  final bool female;
  final String callMode;
  final int includedMinutes;
  final int includedGranted;
  final DateTime? includedPeriodEnd;
  final int packMinutes;
  final int availableMinutes;
  final bool canBuyPacks;
  final int monthTalkSeconds;
  final int unseenMissed;
  final List<CallPlan> plans;
  final DateTime? premiumUntil;
  final bool willRenew;
  final bool consentRequired;

  CallMinutesTerms get terms => CallMinutesTerms(
        premium: premium,
        periodEnd: includedPeriodEnd,
        premiumUntil: premiumUntil,
        willRenew: willRenew,
        packMinutes: packMinutes,
      );

  factory CallOverview.fromJson(Map<String, dynamic> json) => CallOverview(
        callsEnabled: json['calls_enabled'] == true,
        premium: json['premium'] == true,
        female: json['female'] == true,
        callMode: json['call_mode']?.toString() ?? 'ring',
        includedMinutes: (json['included_minutes'] as num?)?.toInt() ?? 0,
        includedGranted: (json['included_granted'] as num?)?.toInt() ?? 0,
        includedPeriodEnd: DateTime.tryParse(json['included_period_end']?.toString() ?? '')?.toLocal(),
        packMinutes: (json['pack_minutes'] as num?)?.toInt() ?? 0,
        availableMinutes: (json['available_minutes'] as num?)?.toInt() ?? 0,
        canBuyPacks: json['can_buy_packs'] == true,
        monthTalkSeconds: (json['month_talk_seconds'] as num?)?.toInt() ?? 0,
        unseenMissed: (json['unseen_missed'] as num?)?.toInt() ?? 0,
        plans: CallPlan.listFrom(json['plans']),
        premiumUntil: DateTime.tryParse(json['premium_until']?.toString() ?? '')?.toLocal(),
        willRenew: json['will_renew'] == true,
        consentRequired: json['consent_required'] == true,
      );
}

/// One visible row: consecutive calls with the same person on the same day.
@immutable
class CallLogRow {
  const CallLogRow(this.entries);

  /// Newest first.
  final List<CallLogEntry> entries;

  CallLogEntry get latest => entries.first;
  int get count => entries.length;
  bool get anyMissed => entries.any((e) => e.missedByMe);
  bool get anyUnseen => entries.any((e) => e.unseen);
  List<String> get requestIds => [for (final e in entries) e.requestId];
}

/// The day a group of rows belongs to.
enum CallDayKind { today, yesterday, thisWeek, earlier }

@immutable
class CallLogSection {
  const CallLogSection({required this.day, required this.kind, required this.rows});

  final DateTime day;
  final CallDayKind kind;
  final List<CallLogRow> rows;
}

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

CallDayKind callDayKind(DateTime day, DateTime now) {
  final today = _dayOf(now);
  final d = _dayOf(day);
  final diff = today.difference(d).inDays;
  if (diff <= 0) return CallDayKind.today;
  if (diff == 1) return CallDayKind.yesterday;
  if (diff < 7) return CallDayKind.thisWeek;
  return CallDayKind.earlier;
}

/// Groups newest-first entries by local day; consecutive calls with the same
/// person on the same day collapse into one row (spec 12.5.5).
List<CallLogSection> groupCallLog(List<CallLogEntry> entries, {required DateTime now}) {
  final sections = <CallLogSection>[];
  List<CallLogRow>? rows;
  DateTime? currentDay;
  List<CallLogEntry>? run;

  void closeRun() {
    if (run != null && run!.isNotEmpty) rows!.add(CallLogRow(List.unmodifiable(run!)));
    run = null;
  }

  for (final entry in entries) {
    final day = _dayOf(entry.createdAt);
    if (currentDay == null || day != currentDay) {
      closeRun();
      rows = <CallLogRow>[];
      currentDay = day;
      sections.add(CallLogSection(day: day, kind: callDayKind(day, now), rows: rows));
    }
    if (run != null && run!.first.peerKey == entry.peerKey) {
      run!.add(entry);
    } else {
      closeRun();
      run = [entry];
    }
  }
  closeRun();
  return sections;
}

/// "2 h 15 m" style talk time, in the member's language later.
({int hours, int minutes}) talkTimeParts(int seconds) {
  final minutes = (seconds / 60).round();
  return (hours: minutes ~/ 60, minutes: minutes % 60);
}
