// SILARAH — Bottom Navigation Bar
// Tabs: Discover / Interests / Chat / Calls (while calling is on) / Profile,
// passed by name (HomeTab).
// Active: Champagne Gold icon in a capsule that widens on selection
// Inactive: Slate Mist
// Badges: Gold bubble on Interests (pending received count), Chat (total
//         unread count) and Calls (unseen missed calls, from the server)
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/interests/interests_cubit.dart';
import '../../../core/cubits/interests/interests_state.dart';
import '../../../core/cubits/chat/chat_cubit.dart';
import '../../../core/cubits/chat/chat_state.dart';
import '../../../core/router/home_tab.dart';
import '../../calls/calls_hub.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';

class SilarahBottomNav extends StatelessWidget {
  const SilarahBottomNav({
    super.key,
    required this.tabs,
    required this.current,
    required this.onTabSelected,
  });

  final List<HomeTab> tabs;
  final HomeTab current;
  final ValueChanged<HomeTab> onTabSelected;

  static const _items = {
    HomeTab.discover: _NavItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore_rounded,
        label: 'Discover'),
    HomeTab.interests: _NavItem(
        icon: Icons.favorite_outline_rounded,
        activeIcon: Icons.favorite_rounded,
        label: 'Interests'),
    HomeTab.chats: _NavItem(
        icon: Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
        label: 'Chat'),
    HomeTab.calls: _NavItem(
        icon: Icons.call_outlined,
        activeIcon: Icons.call_rounded,
        label: 'Calls'),
    HomeTab.profile: _NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile'),
  };

  @override
  Widget build(BuildContext context) {
    return BlocSelector<InterestsCubit, InterestsState, int>(
      selector: (state) => state.unreadCount,
      builder: (context, interestUnread) {
        return BlocSelector<ChatCubit, ChatState, int>(
          selector: (state) => state.totalUnread,
          builder: (context, chatUnread) => ValueListenableBuilder<int>(
            valueListenable: CallsHub.instance.unseenMissed,
            builder: (context, missedCalls, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.navBarSurface,
                border: Border(
                  top: BorderSide(
                    color: AppColors.navBarBorder,
                    width: AppDimensions.borderThin,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 4),
                child: SizedBox(
                  height: 68,
                  child: Row(
                    children: [
                      for (final tab in tabs)
                        Expanded(
                          child: RepaintBoundary(
                            child: _NavTab(
                              item: _items[tab]!,
                              isActive: tab == current,
                              badgeCount: switch (tab) {
                                HomeTab.interests => interestUnread,
                                HomeTab.chats => chatUnread,
                                HomeTab.calls => missedCalls,
                                _ => 0,
                              },
                              onTap: () {
                                if (tab == current) return;
                                HapticFeedback.selectionClick();
                                onTabSelected(tab);
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ),
        );
      },
    );
  }
}

// Nav Item data
class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

// Nav Tab
class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.isActive,
    required this.badgeCount,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      onTap: onTap,
      haptic: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // One state marker: the capsule widens behind the active icon.
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: AppDimensions.durationTransition,
                  curve: Curves.easeOutCubic,
                  width: isActive ? 56 : 34,
                  height: 30,
                  decoration: BoxDecoration(
                    color:
                        isActive ? AppColors.goldGlow : AppColors.transparent,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    isActive ? item.activeIcon : item.icon,
                    color: isActive
                        ? AppColors.champagneGold
                        : AppColors.slateMist,
                    size: 21,
                  ),
                ),

                // Badge — only visible when count > 0
                if (badgeCount > 0)
                  PositionedDirectional(
                    top: -4,
                    end: -6,
                    child: _Badge(count: badgeCount),
                  ),
              ],
            ),

            const SizedBox(height: 4),

            // Label
            AnimatedDefaultTextStyle(
              duration: AppDimensions.durationTransition,
              style: AppTypography.caption.copyWith(
                color: isActive ? AppColors.champagneGold : AppColors.slateMist,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.2,
                height: 1.0,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: UiText(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Badge bubble
class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 9 ? '9+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.premiumGold,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.navBarSurface,
          width: 1.5,
        ),
      ),
      child: Center(
        child: UiText(
          label,
          style: AppTypography.badge.copyWith(
            fontSize: 9,
            color: AppColors.readableOn(AppColors.premiumGold),
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
