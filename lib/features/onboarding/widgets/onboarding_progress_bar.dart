// SILARAH — Onboarding Progress Bar
// Thin segmented bar + "Step X of Y" counter.
// Filled segments animate in Champagne Gold.
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({
    super.key,
    required this.currentStep,
    this.totalSteps = 10,
  });

  /// 0-indexed step within the onboarding form (steps 0–9).
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedDefaultTextStyle(
          duration: AppDimensions.durationTransition,
          style: AppTypography.caption.copyWith(
            fontSize: 10,
            color: AppColors.champagneLight,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          child: UiText(
            context.uiCopyWith('Step {current} of {total}', {
              'current': (currentStep + 1).clamp(1, totalSteps),
              'total': totalSteps,
            }),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(totalSteps, (index) {
            final isFilled = index <= currentStep;
            final isCurrent = index == currentStep;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                height: isCurrent ? 4 : 3,
                margin: EdgeInsetsDirectional.only(
                  end: index < totalSteps - 1 ? 4 : 0,
                ),
                decoration: BoxDecoration(
                  gradient: isFilled
                      ? LinearGradient(
                          colors: [
                            AppColors.champagneLight,
                            AppColors.champagneGold,
                            AppColors.antiqueGold,
                          ],
                        )
                      : null,
                  color: isFilled ? null : AppColors.progressBarBase,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color:
                                AppColors.champagneGold.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
