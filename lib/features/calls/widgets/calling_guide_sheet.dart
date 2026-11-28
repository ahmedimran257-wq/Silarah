// "How calling works" (docs/voice_calling_spec.md 12.6): shown once before a
// member's first call, and any time from the Calls tab, the minutes sheet,
// call settings and Help. Every number comes from the server's rules.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/l10n/ui_copy.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import '../calling_rules.dart';
import '../calls_hub.dart';

const _guideSeenKey = 'silarah_calling_guide_seen_v1';

/// One section of the guide: a heading and its lines, with {placeholders}
/// filled from the server's rules.
typedef CallingGuideSection = ({IconData icon, String title, List<String> lines});

const List<CallingGuideSection> callingGuideSections = [
  (
    icon: Icons.people_outline_rounded,
    title: 'Who can call',
    lines: [
      'You can call only your matches, inside Silarah. Nobody sees your phone number.',
      'Premium members start calls. When a man is on the call, he needs Premium.',
      'Women answer calls free, without Premium.',
    ],
  ),
  (
    icon: Icons.timer_outlined,
    title: 'Call minutes',
    lines: [
      'Premium includes {included} call minutes every {period_days} days. Unused minutes do not carry over.',
      'Minute packs never expire, but you need Premium to use them.',
      'Only the caller\'s minutes are used, per started minute. A call lasts up to {max_call} minutes at a time.',
      'Minute packs are non-refundable, except as set out in the Refund Policy.',
      'If Google Play refunds a pack, its minutes are removed. If you had used them, add minutes before calling again.',
    ],
  ),
  (
    icon: Icons.notifications_active_outlined,
    title: 'Ringing and your choices',
    lines: [
      'A call rings for {ring} seconds. Choose Ring, Silent or Calls off in Settings.',
      'You can mute or block calls from one person; they are not told.',
      'If Silarah\'s notifications are off on your phone, calls cannot reach you.',
    ],
  ),
  (
    icon: Icons.shield_outlined,
    title: 'Protection from unwanted calls',
    lines: [
      'If you call someone {limit} times without an answer, you can call them again the next day. This protects members from unwanted calls.',
      'Report a call from the call screen or your Calls tab. Reporting ends the call.',
    ],
  ),
  (
    icon: Icons.event_available_outlined,
    title: 'Planned calls',
    lines: [
      'Suggest a time to talk, at least {lead} minutes and up to {days_ahead} days ahead. The other member accepts or declines.',
      'You both get a reminder {reminder} minutes before. If you do not talk within {window} minutes of the time, the plan ends.',
    ],
  ),
  (
    icon: Icons.lock_outline_rounded,
    title: 'Privacy',
    lines: [
      'Calls are never recorded. Silarah keeps only when calls happened and how long they lasted, for {retention} months.',
      'If you use Guardian mode, your Guardian sees call times and lengths only.',
    ],
  ),
];

/// Fills {placeholders} in [line] from [rules].
String guideLine(BuildContext context, String line, CallingRules rules) =>
    context.uiCopyWith(line, rules.copyValues);

/// Shows the guide. Returns true when the member tapped Continue.
Future<bool> showCallingGuide(BuildContext context, {String? continueLabel}) async {
  final shown = await showSilarahBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CallingGuideSheet(continueLabel: continueLabel),
  );
  unawaited(_markSeen());
  return shown ?? false;
}

/// Before a member's first call: the guide, once. False when they closed it.
Future<bool> ensureCallingGuideSeen(BuildContext context) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_guideSeenKey) == true) return true;
  } catch (_) {
    return true;
  }
  if (!context.mounted) return false;
  return showCallingGuide(context, continueLabel: 'Got it, call');
}

Future<void> _markSeen() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guideSeenKey, true);
  } catch (_) {}
}

class _CallingGuideSheet extends StatefulWidget {
  const _CallingGuideSheet({this.continueLabel});

  final String? continueLabel;

  @override
  State<_CallingGuideSheet> createState() => _CallingGuideSheetState();
}

class _CallingGuideSheetState extends State<_CallingGuideSheet> {
  @override
  void initState() {
    super.initState();
    if (CallsHub.instance.rules.value == null) unawaited(CallsHub.instance.refresh());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CallingRules?>(
      valueListenable: CallsHub.instance.rules,
      builder: (context, rules, _) {
        return SilarahBottomSheet(
          title: context.uiCopy('How calling works'),
          primaryAction: BottomSheetAction(
            label: context.uiCopy(widget.continueLabel ?? 'Got it'),
            onTap: () => Navigator.of(context).pop(true),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .62),
            child: rules == null
                ? const _GuidePlaceholder()
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final section in callingGuideSections)
                        _GuideSection(section: section, rules: rules),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

/// The guide while the rules load: its sections' gold icon circles and
/// lines, in Silarah's breathing placeholder motion.
class _GuidePlaceholder extends StatelessWidget {
  const _GuidePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.uiCopy('Loading'),
      liveRegion: true,
      child: ExcludeSemantics(
        child: SilarahBreathing(
          builder: (context, pulse) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 4; i++)
                Opacity(
                  opacity: 1 - i * .16,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.space16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.goldGlow,
                            border: Border.all(color: AppColors.champagneGold.withValues(alpha: .10 + pulse * .12)),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SilarahLoaderBar(width: 120.0 + (i % 2) * 30, height: 13, opacity: .30 + pulse * .08),
                              const SizedBox(height: AppDimensions.space8),
                              FractionallySizedBox(
                                widthFactor: .92,
                                alignment: AlignmentDirectional.centerStart,
                                child: SilarahLoaderBar(width: double.infinity, height: 10, opacity: .20 + pulse * .07),
                              ),
                              const SizedBox(height: AppDimensions.space6),
                              SilarahLoaderBar(width: 150.0 - (i % 3) * 24, height: 10, opacity: .18 + pulse * .07),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.section, required this.rules});

  final CallingGuideSection section;
  final CallingRules rules;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.goldGlow),
            child: Icon(section.icon, color: AppColors.champagneGold, size: 18),
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: UiText(section.title, style: AppTypography.bodyMedium),
                ),
                const SizedBox(height: AppDimensions.space4),
                for (final line in section.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.space4),
                    child: UiText.verbatim(
                      guideLine(context, line, rules),
                      style: AppTypography.caption.copyWith(height: 1.45, color: AppColors.pearlWhite),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The ⓘ that opens the guide (Calls tab header, minutes sheet).
class CallingGuideButton extends StatelessWidget {
  const CallingGuideButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      semanticLabel: context.uiCopy('How calling works'),
      onTap: () => unawaited(showCallingGuide(context)),
      child: Container(
        width: AppDimensions.minTouchTarget,
        height: AppDimensions.minTouchTarget,
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Icon(Icons.info_outline_rounded, color: AppColors.slateMist, size: AppDimensions.iconSizeLarge),
      ),
    );
  }
}
