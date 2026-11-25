// Pieces of the Calls tab (docs/voice_calling_spec.md 12.5, 13). Silarah's
// own tokens, type and motion throughout; every row and action has a
// TalkBack label; long names and large fonts wrap instead of clipping.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:silarah/l10n/ui_copy.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_curves.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/loaders/silarah_blur_image.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../call_log.dart';
import '../call_models.dart';

String _locale(BuildContext context) => Localizations.localeOf(context).toLanguageTag();

/// "Today" / "Yesterday" / "Monday" / "12 Nov 2026" in the member's language.
String callDayLabel(BuildContext context, CallLogSection section) => switch (section.kind) {
      CallDayKind.today => context.uiCopy('Today'),
      CallDayKind.yesterday => context.uiCopy('Yesterday'),
      CallDayKind.thisWeek => DateFormat.EEEE(_locale(context)).format(section.day),
      CallDayKind.earlier => DateFormat.yMMMd(_locale(context)).format(section.day),
    };

/// "2 h 15 m" / "45 m" in the member's language.
String talkTimeLabel(BuildContext context, int seconds) {
  final parts = talkTimeParts(seconds);
  if (parts.hours == 0) {
    return context.uiCopyWith('{minutes} m', {'minutes': parts.minutes});
  }
  return context.uiCopyWith('{hours} h {minutes} m', {'hours': parts.hours, 'minutes': parts.minutes});
}

// ---------------------------------------------------------------------------
// Avatar
// ---------------------------------------------------------------------------

/// A member's photo where the server allows it, their initial otherwise, and
/// a neutral mark for a member who is no longer available.
class CallAvatar extends StatelessWidget {
  const CallAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    required this.unavailable,
    this.size = 48,
    this.badge,
    this.highlight = false,
  });

  final String name;
  final String? photoUrl;
  final bool unavailable;
  final double size;
  final Widget? badge;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '' : name.trim().characters.first.toUpperCase();
    final Widget face;
    if (unavailable) {
      face = Icon(Icons.person_off_outlined, color: AppColors.slateMist, size: size * .46);
    } else if (photoUrl != null && photoUrl!.isNotEmpty) {
      face = SilarahBlurImage(imageUrl: photoUrl!, width: size, height: size);
    } else {
      face = Center(
        child: UiText.verbatim(
          initial,
          style: AppTypography.screenTitle.copyWith(
            fontSize: size * .38,
            color: AppColors.champagneGold,
            height: 1,
          ),
        ),
      );
    }
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: AppDimensions.durationTransition,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceGlassHover,
                border: Border.all(
                  color: highlight ? AppColors.champagneGold : AppColors.cardBorder,
                  width: highlight ? 1.5 : 1,
                ),
              ),
              child: ClipOval(child: face),
            ),
            if (badge != null) PositionedDirectional(end: -2, bottom: -2, child: badge!),
          ],
        ),
      ),
    );
  }
}

/// Small direction mark on the avatar: outgoing, incoming, or missed in the
/// theme's error colour.
class CallDirectionBadge extends StatelessWidget {
  const CallDirectionBadge({super.key, required this.entry});

  final CallLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final missed = entry.missedByMe;
    final icon = switch (entry) {
      _ when missed => Icons.call_missed_rounded,
      _ when entry.outgoing => Icons.call_made_rounded,
      _ => Icons.call_received_rounded,
    };
    final color = missed ? AppColors.softCoral : AppColors.champagneGold;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceMid,
        border: Border.all(color: color.withValues(alpha: .55)),
      ),
      child: Icon(icon, size: 12, color: color),
    );
  }
}

// ---------------------------------------------------------------------------
// Minutes card (12.5.1)
// ---------------------------------------------------------------------------

/// When included minutes reset and when Premium ends, in the member's
/// language (docs/voice_calling_spec.md 6.4). Shared by the Calls tab card
/// and the minutes sheet.
List<String> callMinutesTermLines(BuildContext context, CallMinutesTerms terms, DateFormat format) => [
      if (terms.availableUntil != null)
        context.uiCopyWith('Available until {date}', {'date': format.format(terms.availableUntil!.toLocal())}),
      if (terms.resetsOn != null)
        context.uiCopyWith("Unused included minutes don't carry over; they reset on {date}.",
            {'date': format.format(terms.resetsOn!.toLocal())}),
    ];

class CallMinutesCard extends StatelessWidget {
  const CallMinutesCard({
    super.key,
    required this.overview,
    required this.includedMinutes,
    required this.onTopUp,
    required this.onPremium,
  });

  final CallOverview overview;

  /// Included minutes per Premium month, from the server's rules.
  final int includedMinutes;
  final VoidCallback onTopUp;
  final VoidCallback onPremium;

  @override
  Widget build(BuildContext context) {
    return overview.premium ? _premium(context) : _free(context);
  }

  Widget _frame({required Widget child, bool accent = false}) => Container(
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              AppColors.surfacePanelTop,
              AppColors.surfaceGlass,
            ],
          ),
          border: Border.all(color: accent ? AppColors.goldBorder : AppColors.cardBorder),
        ),
        child: child,
      );

  Widget _premium(BuildContext context) {
    final granted = overview.includedGranted;
    final included = overview.includedMinutes;
    final terms = overview.terms;
    final negative = overview.packMinutes < 0;
    final total = overview.availableMinutes;
    return _frame(
      accent: true,
      child: Semantics(
        container: true,
        label: context.uiCopyWith('{minutes} call minutes available', {'minutes': total}),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SilarahProgressRing(
                        value: granted == 0 ? 0 : included / granted,
                        size: 64,
                        strokeWidth: 4,
                        trackColor: AppColors.progressBarBase,
                      ),
                      // The ring is a fixed picture: its number shrinks to fit
                      // inside it at large text sizes. The same numbers are
                      // spelled out beside it and in the card's label.
                      ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                UiText.verbatim(
                                  '$total',
                                  style: AppTypography.screenTitle.copyWith(
                                    fontSize: 20,
                                    height: 1,
                                    color: AppColors.pearlWhite,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                UiText('min', style: AppTypography.caption.copyWith(fontSize: 10, height: 1)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UiText('Call minutes', style: AppTypography.bodyMedium),
                      const SizedBox(height: AppDimensions.space4),
                      UiText.verbatim(
                        context.uiCopyWith('{left} of {granted} included minutes left', {
                          'left': included,
                          'granted': granted,
                        }),
                        style: AppTypography.caption,
                      ),
                      for (final line in callMinutesTermLines(context, terms, DateFormat.MMMd(_locale(context)))) ...[
                        const SizedBox(height: 2),
                        UiText.verbatim(
                          line,
                          style: AppTypography.caption.copyWith(color: AppColors.slateMist),
                        ),
                      ],
                      const SizedBox(height: 2),
                      UiText.verbatim(
                        negative
                            ? context.uiCopy('Top up to call again: a refund took more minutes than you had.')
                            : context.uiCopyWith('{minutes} pack minutes', {'minutes': overview.packMinutes}),
                        style: AppTypography.caption.copyWith(
                          color: negative ? AppColors.softCoral : AppColors.slateMist,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (overview.canBuyPacks) ...[
              const SizedBox(height: AppDimensions.space12),
              _GoldButton(label: 'Top up', icon: Icons.add_rounded, onTap: onTopUp),
            ],
          ],
        ),
      ),
    );
  }

  Widget _free(BuildContext context) {
    final female = overview.female;
    return _frame(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.goldGlow,
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: Icon(Icons.workspace_premium_rounded, color: AppColors.champagneGold, size: 24),
          ),
          const SizedBox(width: AppDimensions.space14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(
                  female ? 'Answering is always free' : 'Talk with your matches',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppDimensions.space4),
                UiText.verbatim(
                  context.uiCopyWith(
                    female
                        ? 'Premium lets you call your matches too, with {included} minutes every month.'
                        : 'Calls are part of Premium. Premium includes {included} call minutes every month.',
                    {'included': overview.includedGranted > 0 ? overview.includedGranted : includedMinutes},
                  ),
                  style: AppTypography.caption,
                ),
                if (overview.terms.packsSavedWhileLapsed) ...[
                  const SizedBox(height: AppDimensions.space4),
                  UiText.verbatim(
                    context.uiCopyWith('Your {minutes} pack minutes are saved. Renew Premium to use them.',
                        {'minutes': overview.packMinutes}),
                    style: AppTypography.caption.copyWith(color: AppColors.champagneGold),
                  ),
                ],
                const SizedBox(height: AppDimensions.space10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _GoldButton(label: 'See Premium', compact: true, onTap: onPremium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.onTap, this.icon, this.compact = false});

  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      semanticLabel: context.uiCopy(label),
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 40 : AppDimensions.buttonHeightSmall),
        padding: EdgeInsets.symmetric(horizontal: compact ? AppDimensions.space16 : AppDimensions.space20),
        decoration: BoxDecoration(
          color: AppColors.champagneGold,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        ),
        child: Row(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.readableOn(AppColors.champagneGold)),
              const SizedBox(width: AppDimensions.space6),
            ],
            Flexible(
              child: UiText(
                label,
                style: AppTypography.button.copyWith(color: AppColors.readableOn(AppColors.champagneGold)),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet outlined action (Decline, Cancel, Message...).
class CallOutlineButton extends StatelessWidget {
  const CallOutlineButton({super.key, required this.label, required this.onTap, this.icon, this.danger = false});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.softCoral : AppColors.pearlWhite;
    return SilarahPressable(
      semanticLabel: context.uiCopy(label),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space14),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: danger ? AppColors.softCoral.withValues(alpha: .45) : AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppDimensions.space6),
            ],
            Flexible(
                child: UiText(label, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}

/// The primary call action (Call now, Accept).
class CallGoldButton extends StatelessWidget {
  const CallGoldButton({super.key, required this.label, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _GoldButton(label: label, icon: icon, onTap: onTap, compact: true);
}

// ---------------------------------------------------------------------------
// "Turn on call notifications" (12.2.4)
// ---------------------------------------------------------------------------

class CallNotificationsPrompt extends StatelessWidget {
  const CallNotificationsPrompt({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.space14),
        decoration: BoxDecoration(
          color: AppColors.expiryAmber.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.expiryAmber.withValues(alpha: .45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notifications_off_outlined, color: AppColors.expiryAmber, size: 22),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText('Turn on call notifications', style: AppTypography.bodyMedium),
                  const SizedBox(height: AppDimensions.space4),
                  UiText(
                    'Calls cannot ring on this phone. Your matches see that you are not taking calls.',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: AppDimensions.space10),
                  CallOutlineButton(label: 'Open settings', icon: Icons.settings_outlined, onTap: onOpenSettings),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Monthly insight (12.5.2)
// ---------------------------------------------------------------------------

class CallInsightLine extends StatelessWidget {
  const CallInsightLine({super.key, required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final text = context.uiCopyWith('You talked {time} this month', {'time': talkTimeLabel(context, seconds)});
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Row(
          children: [
            _VoiceWave(color: AppColors.champagneGold),
            const SizedBox(width: AppDimensions.space10),
            Expanded(child: UiText.verbatim(text, style: AppTypography.caption.copyWith(color: AppColors.pearlWhite))),
          ],
        ),
      ),
    );
  }
}

/// Five still bars: a voice line, Silarah's mark for talk time.
class _VoiceWave extends StatelessWidget {
  const _VoiceWave({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    const heights = [6.0, 12.0, 16.0, 10.0, 6.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final h in heights)
          Container(
            width: 2.5,
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Planned calls (13)
// ---------------------------------------------------------------------------

/// "Today, 8:00 PM" / "Tomorrow, 8:00 PM" / "Fri 14 Nov, 8:00 PM".
String planTimeLabel(BuildContext context, DateTime at, DateTime now) {
  final locale = _locale(context);
  final time = DateFormat.jm(locale).format(at);
  final kind = callDayKind(at, now);
  final day = switch (kind) {
    CallDayKind.today => context.uiCopy('Today'),
    _ when DateTime(at.year, at.month, at.day).difference(DateTime(now.year, now.month, now.day)).inDays == 1 =>
      context.uiCopy('Tomorrow'),
    _ => DateFormat.MMMEd(locale).format(at),
  };
  // Right-to-left languages use their own comma, and the time keeps its
  // direction ("10:30 AM" in Urdu must not read "AM 10:30").
  final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
  return rtl ? '${context.uiIsolate(day)}، ${context.uiIsolate(time)}' : '$day, $time';
}

/// "in 2 h 15 m" / "now".
String planCountdownLabel(BuildContext context, DateTime at, DateTime now) {
  final diff = at.difference(now);
  if (diff.inMinutes <= 0) return context.uiCopy('Now');
  final hours = diff.inHours;
  final minutes = diff.inMinutes % 60;
  if (hours >= 24) return context.uiCopyWith('in {days} d', {'days': (hours / 24).floor()});
  if (hours == 0) return context.uiCopyWith('in {minutes} m', {'minutes': minutes == 0 ? 1 : minutes});
  return context.uiCopyWith('in {hours} h {minutes} m', {'hours': hours, 'minutes': minutes});
}

class CallPlanCard extends StatefulWidget {
  const CallPlanCard({
    super.key,
    required this.plan,
    required this.photoUrl,
    required this.premium,
    required this.female,
    required this.onCall,
    required this.onPremium,
    required this.onRespond,
    required this.onCancel,
  });

  final CallPlan plan;
  final String? photoUrl;
  final bool premium;
  final bool female;
  final VoidCallback onCall;
  final VoidCallback onPremium;
  final ValueChanged<bool> onRespond;
  final VoidCallback onCancel;

  @override
  State<CallPlanCard> createState() => _CallPlanCardState();
}

class _CallPlanCardState extends State<CallPlanCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // The countdown and the moment "Call now" appears.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final now = DateTime.now();
    final when = planTimeLabel(context, plan.plannedFor, now);
    final status = switch (plan.status) {
      'proposed' when plan.iProposed => context.uiCopy('Waiting for their answer'),
      'proposed' => context.uiCopy('Suggested a time to talk'),
      'accepted' => planCountdownLabel(context, plan.plannedFor, now),
      'declined' => context.uiCopy('Not accepted'),
      'cancelled' => context.uiCopy('Cancelled'),
      'done' => context.uiCopy('You talked'),
      _ => context.uiCopy('Missed scheduled call'),
    };
    // Five minutes before the time, the member who can call is offered it.
    final callable = plan.accepted && plan.open && !now.isBefore(plan.callWindowOpens);
    final action = plan.actionNow(premium: widget.premium, female: widget.female, now: now);
    return Semantics(
      container: true,
      label: '${plan.displayName}, $when, $status',
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.space14),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: callable ? AppColors.goldBorder : AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Row(
                children: [
                  CallAvatar(
                    name: plan.firstName,
                    photoUrl: widget.photoUrl,
                    unavailable: plan.memberUnavailable,
                    size: 44,
                    highlight: callable,
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UiText.verbatim(plan.displayName, style: AppTypography.bodyMedium, maxLines: 2),
                        const SizedBox(height: 2),
                        UiText.verbatim(when, style: AppTypography.caption.copyWith(color: AppColors.pearlWhite)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppDimensions.space10, vertical: AppDimensions.space4),
                    decoration: BoxDecoration(
                      color: callable ? AppColors.goldGlow : AppColors.surfaceGlassHover,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                    ),
                    child: UiText.verbatim(
                      status,
                      style: AppTypography.caption.copyWith(
                        fontSize: 11,
                        color: callable ? AppColors.champagneGold : AppColors.slateMist,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (plan.open) ...[
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                alignment: WrapAlignment.end,
                children: [
                  if (action == CallPlanAction.respond) ...[
                    CallOutlineButton(label: 'Decline', onTap: () => widget.onRespond(false)),
                    CallGoldButton(label: 'Accept', icon: Icons.check_rounded, onTap: () => widget.onRespond(true)),
                  ] else ...[
                    CallOutlineButton(label: 'Cancel', onTap: widget.onCancel),
                    if (action == CallPlanAction.call)
                      CallGoldButton(label: 'Call now', icon: Icons.call_rounded, onTap: widget.onCall)
                    else if (action == CallPlanAction.paywall)
                      CallGoldButton(label: 'Get Premium to call', onTap: widget.onPremium)
                    else if (action == CallPlanAction.waitForCall)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppDimensions.space10),
                        child: UiText('They will call you', style: AppTypography.caption),
                      ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chips (12.5.4)
// ---------------------------------------------------------------------------

class CallFilterBar extends StatelessWidget {
  const CallFilterBar({super.key, required this.selected, required this.onSelected, required this.unseenMissed});

  final CallLogFilter selected;
  final ValueChanged<CallLogFilter> onSelected;
  final int unseenMissed;

  static const _labels = {
    CallLogFilter.all: 'All',
    CallLogFilter.missed: 'Missed',
    CallLogFilter.incoming: 'Incoming',
    CallLogFilter.outgoing: 'Outgoing',
    CallLogFilter.planned: 'Planned',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.horizontalMargin),
        children: [
          for (final filter in CallLogFilter.values) ...[
            _FilterChip(
              label: _labels[filter]!,
              selected: filter == selected,
              count: filter == CallLogFilter.missed ? unseenMissed : 0,
              onTap: () => onSelected(filter),
            ),
            const SizedBox(width: AppDimensions.space8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.count, required this.onTap});

  final String label;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: SilarahPressable(
        semanticLabel: context.uiCopy(label),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDimensions.durationTransition,
          curve: AppCurves.transition,
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.goldGlow : AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.goldBorder : AppColors.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              UiText(
                label,
                style: AppTypography.caption.copyWith(
                  color: selected ? AppColors.champagneGold : AppColors.pearlWhite,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: AppDimensions.space6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.softCoral,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: UiText.verbatim(
                    count > 9 ? '9+' : '$count',
                    style: AppTypography.badge.copyWith(
                      fontSize: 10,
                      color: AppColors.readableOn(AppColors.softCoral),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History rows (12.5.5–12.5.7)
// ---------------------------------------------------------------------------

/// "Missed" / "No answer" / "12:05 · 3 min used" for a row.
String callRowDetail(BuildContext context, CallLogEntry entry) {
  final direction = switch (entry.outcome) {
    CallLogOutcome.answered => context.uiCopy(entry.outgoing ? 'Outgoing' : 'Incoming'),
    CallLogOutcome.noAnswer => context.uiCopy('No answer'),
    CallLogOutcome.missed => context.uiCopy('Missed'),
    CallLogOutcome.declined => context.uiCopy('Declined'),
    CallLogOutcome.notConnected => context.uiCopy('Not connected'),
    CallLogOutcome.ringing => context.uiCopy('Ringing'),
    CallLogOutcome.live => context.uiCopy('On a call'),
  };
  final parts = [direction];
  final talk = entry.talkSeconds;
  if (entry.outcome == CallLogOutcome.answered && talk != null) parts.add(formatCallDuration(talk));
  final used = entry.minutesUsed;
  if (used != null && used > 0) parts.add(context.uiCopyWith('{minutes} min used', {'minutes': used}));
  return parts.join(' · ');
}

/// From this text size on (Android's "Large" font and up) a history row puts
/// the time under the name.
const callRowLargeTextScale = 1.3;

class CallRowTile extends StatelessWidget {
  const CallRowTile({
    super.key,
    required this.row,
    required this.photoUrl,
    required this.onOpen,
    required this.onCallBack,
    required this.onRemove,
  });

  final CallLogRow row;
  final String? photoUrl;
  final VoidCallback onOpen;
  final VoidCallback? onCallBack;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final entry = row.latest;
    // The row describes its latest call (icon, result, time), so its colour
    // does too: an answered call is never shown in the missed colour because
    // an earlier call that day was missed. New missed calls in the group
    // still stand out through [unseen] and the tab badge.
    final missed = entry.missedByMe;
    final unseen = row.anyUnseen;
    final time = DateFormat.jm(_locale(context)).format(entry.createdAt);
    final name = entry.memberUnavailable ? context.uiCopy('Member unavailable') : entry.displayName;
    final detail = callRowDetail(context, entry);
    final title = row.count > 1 ? '$name (${row.count})' : name;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // With large text the time moves under the name, so the name keeps the
    // row's width instead of breaking mid-word (gate 13: largest font).
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= callRowLargeTextScale;
    final timeText = UiText.verbatim(time, style: AppTypography.caption.copyWith(color: AppColors.slateMist));
    final nameStyle = (unseen ? AppTypography.bodyMedium : AppTypography.body).copyWith(
      color: missed ? AppColors.softCoral : AppColors.pearlWhite,
    );

    final tile = Semantics(
      button: true,
      label: '$title, $detail, $time',
      onTapHint: context.uiCopy('Call details'),
      child: SilarahPressable(
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            color: unseen ? AppColors.surfaceGlassHover : AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard - 6),
            border: Border.all(color: unseen ? AppColors.softCoral.withValues(alpha: .4) : AppColors.cardBorder),
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppDimensions.space14,
            AppDimensions.space12,
            AppDimensions.space8,
            AppDimensions.space12,
          ),
          child: ExcludeSemantics(
            child: Row(
              children: [
                CallAvatar(
                  name: entry.firstName,
                  photoUrl: photoUrl,
                  unavailable: entry.memberUnavailable,
                  badge: CallDirectionBadge(entry: entry),
                ),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Like WhatsApp and Telegram: the name keeps one line
                      // and ends in "…" when it does not fit, never broken
                      // mid-word (gate 13, largest font); the count stays
                      // whole beside it. The details sheet shows the full name.
                      // "Member unavailable" is words, not a name: it wraps
                      // between them rather than lose its meaning.
                      Row(
                        children: [
                          Flexible(
                            child: UiText.verbatim(
                              name,
                              maxLines: entry.memberUnavailable ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: nameStyle,
                            ),
                          ),
                          if (row.count > 1) UiText.verbatim(' (${row.count})', maxLines: 1, style: nameStyle),
                        ],
                      ),
                      const SizedBox(height: 3),
                      UiText.verbatim(
                        detail,
                        maxLines: largeText ? 3 : 2,
                        style: AppTypography.caption.copyWith(
                          color: missed ? AppColors.softCoral.withValues(alpha: .85) : AppColors.slateMist,
                        ),
                      ),
                      if (largeText) ...[
                        const SizedBox(height: 3),
                        timeText,
                      ],
                    ],
                  ),
                ),
                if (!largeText) ...[
                  const SizedBox(width: AppDimensions.space8),
                  timeText,
                ],
                if (onCallBack != null)
                  SilarahPressable(
                    semanticLabel: context.uiCopy('Call back'),
                    onTap: onCallBack,
                    child: SizedBox(
                      width: AppDimensions.minTouchTarget,
                      height: AppDimensions.minTouchTarget,
                      child: Icon(Icons.call_outlined, color: AppColors.champagneGold, size: 22),
                    ),
                  )
                else
                  const SizedBox(width: AppDimensions.space8),
              ],
            ),
          ),
        ),
      ),
    );

    // Swipe toward the end: call back. Toward the start: remove from history.
    return Dismissible(
      key: ValueKey('call-row-${entry.requestId}'),
      direction: onCallBack == null ? DismissDirection.endToStart : DismissDirection.horizontal,
      dismissThresholds: const {DismissDirection.startToEnd: .28, DismissDirection.endToStart: .38},
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onCallBack?.call();
          return false;
        }
        return true;
      },
      onDismissed: (_) => onRemove(),
      background: _SwipeBackground(
        icon: Icons.call_rounded,
        label: 'Call back',
        color: AppColors.verifiedTeal,
        alignment: rtl ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      ),
      secondaryBackground: _SwipeBackground(
        icon: Icons.delete_sweep_outlined,
        label: 'Remove',
        color: AppColors.softCoral,
        alignment: rtl ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      ),
      child: tile,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.icon, required this.label, required this.color, required this.alignment});

  final IconData icon;
  final String label;
  final Color color;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard - 6),
        border: Border.all(color: color.withValues(alpha: .5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          UiText(label, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class CallDayHeader extends StatelessWidget {
  const CallDayHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.space4,
          AppDimensions.space16,
          AppDimensions.space4,
          AppDimensions.space8,
        ),
        child: UiText.verbatim(
          label.toUpperCase(),
          style: AppTypography.sectionLabel.copyWith(color: AppColors.slateMist, letterSpacing: 1.1),
        ),
      ),
    );
  }
}

/// Loading placeholder shaped like the real rows, in Silarah's premium
/// placeholder motion (the same breathing as Discover's profile card, never a
/// light sweeping across the list). Each row is a little quieter than the one
/// above, so the list fades out instead of ending in a hard edge; the gold
/// mark sits where each row's call button will be.
class CallsListSkeleton extends StatelessWidget {
  const CallsListSkeleton({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.uiCopy('Loading calls'),
      liveRegion: true,
      child: ExcludeSemantics(
        child: SilarahBreathing(
          builder: (context, pulse) => Column(
            children: [
              for (var i = 0; i < rows; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                  child: Opacity(
                    opacity: 1 - i * .14,
                    child: _CallRowPlaceholder(index: i, pulse: pulse),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of [CallsListSkeleton], the size and frame of [CallRowTile].
class _CallRowPlaceholder extends StatelessWidget {
  const _CallRowPlaceholder({required this.index, required this.pulse});

  final int index;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard - 6),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.space14,
        AppDimensions.space12,
        AppDimensions.space8,
        AppDimensions.space12,
      ),
      child: Row(
        children: [
          _PlaceholderAvatar(size: 48, pulse: pulse),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SilarahLoaderBar(width: 96.0 + (index % 3) * 26, height: 13, opacity: .30 + pulse * .08),
                const SizedBox(height: AppDimensions.space8),
                SilarahLoaderBar(width: 132.0 - (index % 2) * 28, height: 10, opacity: .20 + pulse * .07),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.space8),
          SilarahLoaderBar(width: 40, height: 10, opacity: .20 + pulse * .07),
          SizedBox(
            width: AppDimensions.minTouchTarget,
            height: AppDimensions.minTouchTarget,
            child: Center(child: _GoldMark(pulse: pulse)),
          ),
        ],
      ),
    );
  }
}

/// A round avatar placeholder with the faint gold ring of the real avatar.
class _PlaceholderAvatar extends StatelessWidget {
  const _PlaceholderAvatar({required this.size, required this.pulse});

  final double size;
  final double pulse;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.slateMist.withValues(alpha: .16 + pulse * .06),
          border: Border.all(color: AppColors.champagneGold.withValues(alpha: .12 + pulse * .10)),
        ),
      );
}

/// The small glowing gold point of Silarah's placeholders (Discover's
/// focal mark), standing in for a gold control that is on its way.
class _GoldMark extends StatelessWidget {
  const _GoldMark({required this.pulse});

  final double pulse;

  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.champagneGold.withValues(alpha: .40 + pulse * .34),
          boxShadow: [
            BoxShadow(
              color: AppColors.champagneGold.withValues(alpha: .06 + pulse * .08),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
      );
}

/// The minutes card while the overview loads: the card's own frame and gold
/// border, the minutes ring as a breathing gold outline, and the button.
class CallMinutesCardPlaceholder extends StatelessWidget {
  const CallMinutesCardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SilarahBreathing(
        builder: (context, pulse) => Container(
          padding: const EdgeInsets.all(AppDimensions.space16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [AppColors.surfacePanelTop, AppColors.surfaceGlass],
            ),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: 4,
                        color: AppColors.champagneGold.withValues(alpha: .14 + pulse * .14),
                      ),
                    ),
                    child: _GoldMark(pulse: pulse),
                  ),
                  const SizedBox(width: AppDimensions.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SilarahLoaderBar(width: 118, height: 15, opacity: .30 + pulse * .08),
                        const SizedBox(height: AppDimensions.space10),
                        SilarahLoaderBar(width: 172, height: 10, opacity: .20 + pulse * .07),
                        const SizedBox(height: AppDimensions.space8),
                        SilarahLoaderBar(width: 136, height: 10, opacity: .18 + pulse * .07),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space16),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.champagneGold.withValues(alpha: .08 + pulse * .06),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  border: Border.all(color: AppColors.champagneGold.withValues(alpha: .12 + pulse * .08)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The call list in a member's details sheet while it loads: the sheet's
/// card with attempt rows (direction mark, result, date), breathing.
class CallAttemptsPlaceholder extends StatelessWidget {
  const CallAttemptsPlaceholder({super.key, this.rows = 3});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.uiCopy('Loading calls'),
      liveRegion: true,
      child: ExcludeSemantics(
        child: SilarahBreathing(
          builder: (context, pulse) => Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows; i++) ...[
                  if (i > 0) Divider(height: 1, color: AppColors.divider),
                  Opacity(
                    opacity: 1 - i * .18,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.space14,
                        vertical: AppDimensions.space14,
                      ),
                      child: Row(
                        children: [
                          _GoldMark(pulse: pulse),
                          const SizedBox(width: AppDimensions.space16),
                          SilarahLoaderBar(width: 92.0 + (i % 2) * 24, height: 12, opacity: .28 + pulse * .08),
                          const Spacer(),
                          SilarahLoaderBar(width: 104, height: 10, opacity: .18 + pulse * .07),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
