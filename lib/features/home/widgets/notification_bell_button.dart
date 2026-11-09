import 'package:flutter/material.dart';
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cubits/notifications/notifications_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_curves.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';

/// The single notification entry-point used across authenticated surfaces.
///
/// Keeping the realtime unread projection here prevents individual screens
/// from accidentally rendering a static bell that drifts from the global
/// [NotificationsCubit] state.
class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({
    super.key,
    required this.onTap,
    this.embedded = false,
  });

  final VoidCallback onTap;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<NotificationsCubit, NotificationsState, int>(
      selector: (state) => state.bellUnreadCount,
      builder: (context, unreadCount) {
        return SilarahPressable(
          semanticLabel: unreadCount == 0
              ? 'Notifications'
              : context.uiCopyWith(
                  'Notifications, {count} unread', {'count': unreadCount}),
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: AppDimensions.durationTransition,
                curve: Curves.easeOutCubic,
                width: AppDimensions.minTouchTarget,
                height: AppDimensions.minTouchTarget,
                decoration: embedded
                    ? null
                    : BoxDecoration(
                        color: AppColors.surfaceGlass,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: unreadCount > 0
                              ? AppColors.champagneGold.withValues(alpha: 0.38)
                              : AppColors.cardBorder,
                        ),
                      ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: unreadCount > 0
                      ? AppColors.champagneGold
                      : AppColors.slateMist,
                  size: AppDimensions.iconSizeLarge,
                ),
              ),
              Positioned(
                top: embedded ? 6 : 11,
                right: embedded ? 6 : 12,
                child: AnimatedSwitcher(
                  duration: AppDimensions.durationTransition,
                  switchInCurve: AppCurves.tactile,
                  switchOutCurve: AppCurves.dismiss,
                  child: unreadCount > 0
                      ? Container(
                          key: const ValueKey('notification-unread-dot'),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.champagneGold,
                            shape: BoxShape.circle,
                          ),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('notification-read-state'),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
