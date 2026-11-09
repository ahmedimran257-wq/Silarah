import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';

import '../../../core/cubits/interests/interests_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_curves.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import '../screens/subscription_screen.dart';

/// The single quota-exhaustion surface used by discovery, profile detail and
/// the Interests tab. Entitlement values come from Supabase; this widget never
/// infers Premium from a numeric limit.
class InterestQuotaSheet {
  const InterestQuotaSheet._();

  static Future<void> show(
    BuildContext context, {
    required InterestsState quota,
  }) {
    return showSilarahBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.obsidianNight.withValues(alpha: 0.82),
      builder: (_) => _InterestQuotaContent(quota: quota),
    );
  }
}

class _InterestQuotaContent extends StatelessWidget {
  const _InterestQuotaContent({required this.quota});

  final InterestsState quota;

  String _resetLabel(BuildContext context) {
    final reset = quota.quotaResetsAt;
    if (reset == null) return 'Your daily allowance renews tomorrow.';
    final local = reset.toLocal();
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return context.uiRenewsAt(time);
  }

  @override
  Widget build(BuildContext context) {
    final premium = quota.isPremium;
    final navigator = Navigator.of(context);

    return Semantics(
      container: true,
      liveRegion: true,
      label: context.uiCopyWith(
          'Daily interest allowance used. {sent} of {limit} sent.', {
        'sent': quota.dailyLimit,
        'limit': quota.dailyLimit,
      }),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceMid,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: AppColors.champagneGold.withValues(alpha: 0.48),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.obsidianNight.withValues(alpha: 0.58),
              blurRadius: 32,
              offset: const Offset(0, -12),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          AppDimensions.space24,
          AppDimensions.space12,
          AppDimensions.space24,
          AppDimensions.space24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.champagneGold.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(
                      color: AppColors.champagneGold.withValues(alpha: 0.32),
                    ),
                  ),
                  child: Icon(
                    Icons.favorite_border_rounded,
                    color: AppColors.champagneGold,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppDimensions.space14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UiText(
                        context.uiCopy('DAILY INTRODUCTIONS'),
                        style: AppTypography.sectionLabel.copyWith(
                          color: AppColors.champagneGold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space6),
                      UiText(
                        premium
                            ? "You've reached today's allowance"
                            : "You've used today's interests",
                        style: AppTypography.screenTitle.copyWith(fontSize: 23),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space14),
            UiText(
              premium
                  ? 'Your 25 daily interests help keep introductions considered and respectful.'
                  : 'You can wait for your allowance to renew, or use Premium for 25 considered introductions each day.',
              style: AppTypography.bodyMuted.copyWith(height: 1.55),
            ),
            const SizedBox(height: AppDimensions.space20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.space16),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      UiText(
                        context.uiCopyWith('{sent} of {limit} sent', {
                          'sent': quota.dailyLimit,
                          'limit': quota.dailyLimit,
                        }),
                        style: AppTypography.bodyMedium,
                      ),
                      const Spacer(),
                      UiText(
                        _resetLabel(context),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.champagneGold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 650),
                    curve: AppCurves.reveal,
                    builder: (_, value, __) => SilarahLinearProgress(
                      value: value,
                      height: 5,
                      trackColor: AppColors.surfaceGlassHover,
                      color: AppColors.champagneGold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.space20),
            SilarahPressable(
              semanticLabel: premium ? 'Close' : 'View Premium plans',
              onTap: premium
                  ? navigator.pop
                  : () {
                      navigator.pop();
                      navigator.push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      );
                    },
              child: Container(
                width: double.infinity,
                height: AppDimensions.buttonHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.champagneGold,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                ),
                child: UiText(
                  premium ? 'Got it' : 'Explore Premium',
                  style: AppTypography.button,
                ),
              ),
            ),
            if (!premium) ...[
              const SizedBox(height: AppDimensions.space8),
              Center(
                child: TextButton(
                  onPressed: navigator.pop,
                  child: UiText(
                    context.uiCopy("I'll wait until tomorrow"),
                    style: AppTypography.bodyMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
