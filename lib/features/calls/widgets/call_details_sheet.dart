// Call details for one member (docs/voice_calling_spec.md 12.5.6): every
// call with them, totals, Call back / Message / View profile / Plan a call,
// and the per-chat safety controls (mute calls, block calls, report).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:silarah/l10n/ui_copy.dart';

import '../../../core/cubits/chat/chat_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import '../../home/screens/paywall_gate_screen.dart';
import '../../home/widgets/report_bottom_sheet.dart';
import '../call_api.dart';
import '../call_log.dart';
import '../call_models.dart';
import '../calling_rules.dart';
import '../calls_hub.dart';
import 'calls_tab_widgets.dart';
import 'chat_call_widgets.dart';

/// What the details sheet asked the Calls tab to do afterwards.
enum CallDetailsResult { removed, changed }

Future<CallDetailsResult?> showCallDetailsSheet(
  BuildContext context, {
  required CallLogRow row,
  required String? photoUrl,
  CallApi? api,
}) =>
    showSilarahBottomSheet<CallDetailsResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CallDetailsSheet(row: row, photoUrl: photoUrl, api: api ?? CallApi.instance),
    );

class _CallDetailsSheet extends StatefulWidget {
  const _CallDetailsSheet({required this.row, required this.photoUrl, required this.api});

  final CallLogRow row;
  final String? photoUrl;
  final CallApi api;

  @override
  State<_CallDetailsSheet> createState() => _CallDetailsSheetState();
}

class _CallDetailsSheetState extends State<_CallDetailsSheet> {
  late List<CallLogEntry> _attempts = widget.row.entries;
  ChatCallState? _prefs;
  bool _loading = true;
  bool _saving = false;

  CallLogEntry get _entry => widget.row.latest;
  bool get _available => !_entry.memberUnavailable && _entry.otherUserId != null;
  String get _name => _entry.memberUnavailable ? context.uiCopy('Member unavailable') : _entry.displayName;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!_available) {
      setState(() => _loading = false);
      return;
    }
    final matchId = _entry.matchId;
    final results = await Future.wait<Object?>([
      widget.api
          .log(otherUserId: _entry.otherUserId, limit: 100)
          .then<Object?>((value) => value, onError: (_) => null),
      if (matchId != null) widget.api.chatState(matchId),
    ]);
    if (!mounted) return;
    setState(() {
      final attempts = results.first;
      if (attempts is List<CallLogEntry> && attempts.isNotEmpty) _attempts = attempts;
      if (results.length > 1 && results[1] is ChatCallState) _prefs = results[1] as ChatCallState;
      _loading = false;
    });
  }

  Future<void> _setPrefs({bool? muted, bool? blocked}) async {
    final matchId = _entry.matchId;
    final prefs = _prefs;
    if (matchId == null || prefs == null || _saving) return;
    setState(() => _saving = true);
    final ok = await widget.api.setChatPrefs(
      matchId,
      muted: muted ?? prefs.muted,
      callsBlocked: blocked ?? prefs.callsBlocked,
    );
    final fresh = ok ? await widget.api.chatState(matchId) : prefs;
    if (!mounted) return;
    setState(() {
      _prefs = fresh;
      _saving = false;
    });
    if (!ok) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: UiText(context.uiCopy('Could not save. Please try again.')),
      ));
    }
  }

  Future<void> _callBack() async {
    final matchId = _entry.matchId;
    if (matchId == null) return;
    final navigator = Navigator.of(context);
    navigator.pop(CallDetailsResult.changed);
    await placeCall(
      navigator.context,
      matchId: matchId,
      name: _entry.displayName,
      photoUrl: widget.photoUrl,
      otherUserId: _entry.otherUserId,
    );
  }

  Future<void> _message() async {
    final matchId = _entry.matchId;
    if (matchId == null) return;
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final access = await context.read<ChatCubit>().checkChatAccess(matchId);
    if (!mounted) return;
    if (access.requiresSubscription) {
      await PaywallGateSheet.show(context);
      return;
    }
    if (!access.allowed) {
      messenger?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: UiText(context.uiCopy('We could not open this conversation. Please try again.')),
      ));
      return;
    }
    navigator.pop();
    unawaited(router.push('/chat/$matchId'));
  }

  void _profile() {
    final userId = _entry.otherUserId;
    if (userId == null) return;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    unawaited(router.push('/profile/$userId'));
  }

  Future<void> _plan() async {
    final matchId = _entry.matchId;
    if (matchId == null) return;
    final planned = await showPlanCallSheet(context, matchId: matchId, name: _entry.firstName);
    if (planned && mounted) Navigator.of(context).pop(CallDetailsResult.changed);
  }

  Future<void> _report() async {
    final userId = _entry.otherUserId;
    if (userId == null) return;
    await ReportBottomSheet.show(context, reportedUserId: userId, reportedName: _entry.firstName, fromCall: true);
  }

  Future<void> _remove() async {
    final ok = await widget.api.hide([for (final a in _attempts) a.requestId]);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(CallDetailsResult.removed);
    } else {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: UiText(context.uiCopy('Could not save. Please try again.')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final talk = _attempts.fold<int>(0, (sum, a) => sum + (a.talkSeconds ?? 0));
    final used = _attempts.fold<int>(0, (sum, a) => sum + (a.minutesUsed ?? 0));
    final summary = [
      context.uiCopyWith(_attempts.length == 1 ? '{count} call' : '{count} calls', {'count': _attempts.length}),
      if (talk > 0) context.uiCopyWith('{time} talked', {'time': formatCallDuration(talk)}),
      if (used > 0) context.uiCopyWith('{minutes} min used', {'minutes': used}),
    ].join(' · ');
    final prefs = _prefs;
    final height = MediaQuery.sizeOf(context).height;

    return Container(
      constraints: BoxConstraints(maxHeight: height * .9),
      decoration: BoxDecoration(
        color: AppColors.surfaceMid,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.goldBorder)),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.space24,
            AppDimensions.space12,
            AppDimensions.space24,
            AppDimensions.space24,
          ),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: AppDimensions.space20),
            Center(
              child: CallAvatar(
                name: _entry.firstName,
                photoUrl: widget.photoUrl,
                unavailable: _entry.memberUnavailable,
                size: 76,
              ),
            ),
            const SizedBox(height: AppDimensions.space12),
            Semantics(
              header: true,
              child: UiText.verbatim(
                _name,
                textAlign: TextAlign.center,
                style: AppTypography.screenTitle.copyWith(fontSize: 22),
              ),
            ),
            const SizedBox(height: AppDimensions.space4),
            UiText.verbatim(summary, textAlign: TextAlign.center, style: AppTypography.caption),
            if (_available) ...[
              const SizedBox(height: AppDimensions.space20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RoundAction(icon: Icons.call_rounded, label: 'Call back', primary: true, onTap: _callBack),
                  _RoundAction(icon: Icons.chat_bubble_outline_rounded, label: 'Message', onTap: _message),
                  _RoundAction(icon: Icons.event_available_outlined, label: 'Plan a call', onTap: _plan),
                  _RoundAction(icon: Icons.person_outline_rounded, label: 'View profile', onTap: _profile),
                ],
              ),
            ],
            const SizedBox(height: AppDimensions.space24),
            UiText('Calls', style: AppTypography.sectionLabel.copyWith(color: AppColors.slateMist)),
            const SizedBox(height: AppDimensions.space8),
            if (_loading)
              const SilarahShimmer(child: ShimmerBox(width: double.infinity, height: 120, radius: 16))
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _attempts.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: AppColors.divider),
                      _AttemptRow(entry: _attempts[i], locale: locale),
                    ],
                  ],
                ),
              ),
            if (_available && prefs != null) ...[
              const SizedBox(height: AppDimensions.space24),
              UiText('Safety', style: AppTypography.sectionLabel.copyWith(color: AppColors.slateMist)),
              const SizedBox(height: AppDimensions.space8),
              _ToggleRow(
                icon: Icons.notifications_off_outlined,
                label: context.uiCopyWith('Mute calls from {name}', {'name': _entry.firstName}),
                detail: context.uiCopy('Calls do not ring; they show as missed.'),
                value: prefs.muted,
                enabled: !_saving,
                onChanged: (v) => _setPrefs(muted: v),
              ),
              _ToggleRow(
                icon: Icons.phone_disabled_outlined,
                label: context.uiCopyWith('Block calls from {name}', {'name': _entry.firstName}),
                detail: context.uiCopy('They are not told. Messages are not affected.'),
                value: prefs.callsBlocked,
                enabled: !_saving,
                onChanged: (v) => _setPrefs(blocked: v),
              ),
              const SizedBox(height: AppDimensions.space8),
              CallOutlineButton(label: 'Report', icon: Icons.flag_outlined, danger: true, onTap: _report),
            ],
            const SizedBox(height: AppDimensions.space16),
            CallOutlineButton(
              label: 'Remove from history',
              icon: Icons.delete_sweep_outlined,
              onTap: _remove,
            ),
            const SizedBox(height: AppDimensions.space8),
            UiText(
              'Removing only hides these calls for you. Safety records are kept.',
              style: AppTypography.caption.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.label, required this.onTap, this.primary = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SilarahPressable(
        semanticLabel: context.uiCopy(label),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary ? AppColors.champagneGold : AppColors.surfaceGlass,
                border: Border.all(color: primary ? AppColors.champagneGold : AppColors.cardBorder),
              ),
              child: Icon(
                icon,
                size: 22,
                color: primary ? AppColors.readableOn(AppColors.champagneGold) : AppColors.pearlWhite,
              ),
            ),
            const SizedBox(height: AppDimensions.space6),
            ExcludeSemantics(
              child: UiText(label, textAlign: TextAlign.center, style: AppTypography.caption, maxLines: 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({required this.entry, required this.locale});

  final CallLogEntry entry;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final missed = entry.missedByMe;
    final when = DateFormat.yMMMd(locale).add_jm().format(entry.createdAt);
    final detail = callRowDetail(context, entry);
    return Semantics(
      label: '$detail, $when',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space14, vertical: AppDimensions.space12),
          child: Row(
            children: [
              Icon(
                missed
                    ? Icons.call_missed_rounded
                    : entry.outgoing
                        ? Icons.call_made_rounded
                        : Icons.call_received_rounded,
                size: 18,
                color: missed ? AppColors.softCoral : AppColors.champagneGold,
              ),
              const SizedBox(width: AppDimensions.space12),
              Expanded(
                child: UiText.verbatim(
                  detail,
                  style: AppTypography.body.copyWith(color: missed ? AppColors.softCoral : AppColors.pearlWhite),
                ),
              ),
              const SizedBox(width: AppDimensions.space8),
              Flexible(
                child: UiText.verbatim(
                  when,
                  textAlign: TextAlign.end,
                  style: AppTypography.caption.copyWith(color: AppColors.slateMist),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.space6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.slateMist),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText.verbatim(label, style: AppTypography.body),
                  UiText.verbatim(detail, style: AppTypography.caption),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeTrackColor: AppColors.champagneGold,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan a call time (spec 13)
// ---------------------------------------------------------------------------

/// Times a member can pick: every 30 minutes within the server's planning
/// window (the server checks the same window).
List<DateTime> planSlotsFor(DateTime day, DateTime now, {required int leadMinutes, required int daysAhead}) {
  final earliest = now.add(Duration(minutes: leadMinutes));
  final latest = now.add(Duration(days: daysAhead));
  final slots = <DateTime>[];
  for (var minutes = 0; minutes < 24 * 60; minutes += 30) {
    final slot = DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
    if (!slot.isBefore(earliest) && !slot.isAfter(latest)) slots.add(slot);
  }
  return slots;
}

/// True when the plan was sent.
Future<bool> showPlanCallSheet(
  BuildContext context, {
  required String matchId,
  required String name,
  CallApi? api,
}) async {
  if (CallsHub.instance.rules.value?.callsEnabled != true) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: UiText(context.uiCopy('Calling is paused right now. Please try again later.')),
    ));
    return false;
  }
  final sent = await showSilarahBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PlanCallSheet(matchId: matchId, name: name, api: api ?? CallApi.instance),
  );
  return sent ?? false;
}

class _PlanCallSheet extends StatefulWidget {
  const _PlanCallSheet({required this.matchId, required this.name, required this.api});

  final String matchId;
  final String name;
  final CallApi api;

  @override
  State<_PlanCallSheet> createState() => _PlanCallSheetState();
}

class _PlanCallSheetState extends State<_PlanCallSheet> {
  late final DateTime _now = DateTime.now();
  // Opened only while the rules are loaded (showPlanCallSheet).
  late final CallingRules _rules = CallsHub.instance.rules.value!;
  late final int _lead = _rules.planMinLeadMinutes;
  late final int _daysAhead = _rules.planMaxDaysAhead;
  late final List<DateTime> _days = [
    for (var i = 0; i <= _daysAhead; i++) DateTime(_now.year, _now.month, _now.day + i),
  ].where((d) => _slots(d).isNotEmpty).toList(growable: false);

  List<DateTime> _slots(DateTime day) =>
      planSlotsFor(day, _now, leadMinutes: _lead, daysAhead: _daysAhead);
  late DateTime _day = _days.first;
  DateTime? _slot;
  bool _sending = false;

  Future<void> _send() async {
    final slot = _slot;
    if (slot == null || _sending) return;
    setState(() => _sending = true);
    final outcome = await widget.api.proposePlan(widget.matchId, slot);
    if (!mounted) return;
    setState(() => _sending = false);
    if (outcome == 'proposed') {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: UiText(context.uiCopyWith('{name} will be asked to accept this time.', {'name': widget.name})),
      ));
      return;
    }
    if (outcome == 'premium_required') {
      Navigator.of(context).pop(false);
      await PaywallGateSheet.show(context, gate: PremiumGate.calls);
      return;
    }
    final message = switch (outcome) {
      'already_planned' => 'You already have a call time with them. Cancel it to choose another.',
      'invalid_time' => 'Choose a time at least {lead} minutes from now.',
      'calls_off_self' => 'Turn calls on in Settings to plan a call.',
      'limit_reached' => 'You have planned enough calls for now. Try again later.',
      'unavailable' => neutralUnavailableCopy,
      _ => 'Could not save. Please try again.',
    };
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: UiText(context.uiCopyWith(message, {'name': widget.name, 'lead': _lead})),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final slots = _slots(_day);
    return SilarahBottomSheet(
      title: context.uiCopyWith('Plan a call with {name}', {'name': widget.name}),
      subtitle: context.uiCopyWith('They choose whether to accept. You both get a reminder {reminder} minutes before.',
          {'reminder': _rules.planReminderMinutes}),
      primaryAction: BottomSheetAction(
        label: context.uiCopy(_sending ? 'Sending…' : 'Suggest this time'),
        onTap: _slot == null || _sending ? () {} : _send,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _days.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppDimensions.space8),
              itemBuilder: (context, i) {
                final day = _days[i];
                final selected = day == _day;
                final label = i == 0
                    ? context.uiCopy('Today')
                    : i == 1
                        ? context.uiCopy('Tomorrow')
                        : DateFormat.E(locale).format(day);
                return Semantics(
                  selected: selected,
                  button: true,
                  child: SilarahPressable(
                    semanticLabel: '$label ${DateFormat.MMMd(locale).format(day)}',
                    onTap: () => setState(() {
                      _day = day;
                      _slot = null;
                    }),
                    child: AnimatedContainer(
                      duration: AppDimensions.durationTransition,
                      width: 72,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.goldGlow : AppColors.surfaceGlass,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? AppColors.goldBorder : AppColors.cardBorder),
                      ),
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              child: UiText.verbatim(
                                label,
                                style: AppTypography.caption.copyWith(
                                  color: selected ? AppColors.champagneGold : AppColors.slateMist,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            UiText.verbatim(
                              DateFormat.d(locale).format(day),
                              style: AppTypography.bodyMedium.copyWith(
                                color: selected ? AppColors.champagneGold : AppColors.pearlWhite,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppDimensions.space16),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .34),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: [
                  for (final slot in slots)
                    Semantics(
                      selected: slot == _slot,
                      button: true,
                      child: SilarahPressable(
                        semanticLabel: DateFormat.jm(locale).format(slot),
                        onTap: () => setState(() => _slot = slot),
                        child: AnimatedContainer(
                          duration: AppDimensions.durationTransition,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.space14,
                            vertical: AppDimensions.space10,
                          ),
                          decoration: BoxDecoration(
                            color: slot == _slot ? AppColors.champagneGold : AppColors.surfaceGlass,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                            border: Border.all(color: slot == _slot ? AppColors.champagneGold : AppColors.cardBorder),
                          ),
                          child: ExcludeSemantics(
                            child: UiText.verbatim(
                              DateFormat.jm(locale).format(slot),
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: slot == _slot
                                    ? AppColors.readableOn(AppColors.champagneGold)
                                    : AppColors.pearlWhite,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
