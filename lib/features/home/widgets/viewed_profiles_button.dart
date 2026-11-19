import 'package:flutter/material.dart';
import 'package:silarah/l10n/ui_copy.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../screens/viewed_profiles_screen.dart';

/// Discover header entry to the "Viewed profiles" gallery. It sits beside
/// the notification bell with the same shape, and warms to the accent once
/// the member has viewed someone today, when going back is most useful.
class ViewedProfilesButton extends StatelessWidget {
  const ViewedProfilesButton({super.key, this.highlighted = false});

  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      semanticLabel: 'Viewed profiles',
      onTap: () => ViewedProfilesScreen.open(context),
      child: AnimatedContainer(
        duration: AppDimensions.durationTactile,
        curve: Curves.easeOutCubic,
        width: AppDimensions.minTouchTarget,
        height: AppDimensions.minTouchTarget,
        decoration: BoxDecoration(
          color: highlighted
              ? AppColors.champagneGold.withValues(alpha: 0.10)
              : AppColors.surfaceGlass,
          shape: BoxShape.circle,
          border: Border.all(
            color: highlighted
                ? AppColors.champagneGold.withValues(alpha: 0.38)
                : AppColors.cardBorder,
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: AppColors.goldGlow,
                    blurRadius: 14,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.history_rounded,
          color: highlighted ? AppColors.champagneGold : AppColors.slateMist,
          size: AppDimensions.iconSizeLarge,
        ),
      ),
    );
  }
}

/// Quiet text action for the moments a member runs out of new profiles:
/// the daily limit and the end of the feed.
class SeeViewedProfilesAction extends StatelessWidget {
  const SeeViewedProfilesAction({super.key});

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      semanticLabel: 'See profiles you viewed',
      onTap: () => ViewedProfilesScreen.open(context),
      child: Container(
        constraints:
            const BoxConstraints(minHeight: AppDimensions.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              size: AppDimensions.iconSizeSmall + 2,
              color: AppColors.champagneGold,
            ),
            const SizedBox(width: AppDimensions.space8),
            Flexible(
              child: UiText(
                'See profiles you viewed',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.buttonSecondary.copyWith(fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
