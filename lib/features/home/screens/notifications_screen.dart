// SILARAH — Notifications Screen (Feature 11)
// Shows all notifications with read/unread state.
// AppBar: "Mark all read" text button.
// Each row: type icon in colored circle + title + body + time.
// Unread rows: gold 3px left border.
import 'dart:async';

import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/cubits/chat/chat_cubit.dart';
import '../../../core/cubits/notifications/notifications_cubit.dart';
import '../../../core/cubits/interests/interests_cubit.dart';
import '../../../core/cubits/subscription/subscription_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/overlays/silarah_dialog.dart';
import '../../../l10n/generated/app_localizations.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: AppColors.obsidianNight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(AppDimensions.space8),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.pearlWhite,
              size: AppDimensions.iconSizeMedium,
            ),
          ),
        ),
        title: UiText(AppLocalizations.of(context).notifications_title,
            style: AppTypography.screenTitle.copyWith(fontSize: 20)),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) {
              if (state.items.isEmpty) return const SizedBox.shrink();
              return PopupMenuButton<_NotificationMenuAction>(
                tooltip: context.uiCopy('Notification options'),
                color: AppColors.surfaceElevated,
                icon:
                    Icon(Icons.more_horiz_rounded, color: AppColors.slateMist),
                onSelected: (action) async {
                  final cubit = context.read<NotificationsCubit>();
                  if (action == _NotificationMenuAction.markAllRead) {
                    await cubit.markAllRead();
                    return;
                  }
                  final confirmed = await _confirmClearAll(context);
                  if (!confirmed || !context.mounted) return;
                  final deleted = await cubit.clearAllNotifications();
                  if (!deleted && context.mounted) {
                    _showDeleteError(context);
                  }
                },
                itemBuilder: (_) => [
                  if (state.unreadCount > 0)
                    PopupMenuItem(
                      value: _NotificationMenuAction.markAllRead,
                      child: Row(
                        children: [
                          Icon(Icons.done_all_rounded,
                              color: AppColors.verifiedTeal, size: 19),
                          const SizedBox(width: AppDimensions.space10),
                          UiText(
                            AppLocalizations.of(context)
                                .notifications_markAllRead,
                            style: AppTypography.body,
                          ),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: _NotificationMenuAction.clearAll,
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep_outlined,
                            color: AppColors.softCoral, size: 19),
                        const SizedBox(width: AppDimensions.space10),
                        UiText(context.uiCopy('Clear all notifications'),
                            style: AppTypography.body),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: AppDimensions.space8),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            itemCount: state.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final item = state.items[i];
              return Dismissible(
                key: ValueKey(item.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDeleteOne(context),
                onDismissed: (_) async {
                  final deleted = await context
                      .read<NotificationsCubit>()
                      .deleteNotification(item.id);
                  if (!deleted && context.mounted) _showDeleteError(context);
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppDimensions.space20),
                  decoration: BoxDecoration(
                    color: AppColors.softCoral.withValues(alpha: 0.14),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(
                        color: AppColors.softCoral.withValues(alpha: 0.35)),
                  ),
                  child: Icon(Icons.delete_outline_rounded,
                      color: AppColors.softCoral),
                ),
                child: _NotificationTile(
                  item: item,
                  onTap: () async {
                    await context.read<NotificationsCubit>().markRead(item.id);
                    if (item.type == 'referral_reward' && context.mounted) {
                      await context
                          .read<SubscriptionCubit>()
                          .refreshEntitlement();
                    }
                    final path = notificationPathFor(item);
                    if (path != null && context.mounted) {
                      if (item.type == 'interest_received' ||
                          item.type == 'interest_accepted' ||
                          item.type == 'match' ||
                          item.type == 'match_accepted') {
                        unawaited(
                          context
                              .read<InterestsCubit>()
                              .refreshIfChanged(forceCheck: true),
                        );
                      }
                      if (item.type == 'new_message') {
                        context.read<ChatCubit>().scheduleInboxReconciliation();
                      }
                      if (item.type == 'referral_reward') {
                        context.go(path);
                      } else {
                        context.push(path);
                      }
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Notification tile
enum _NotificationMenuAction { markAllRead, clearAll }

Future<bool> _confirmDeleteOne(BuildContext context) async {
  return await showSilarahDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: UiText(context.uiCopy('Remove notification?'),
              style: AppTypography.bodyMedium),
          content: UiText(
            context.uiCopy(
                'This notification will be permanently removed from your account.'),
            style: AppTypography.bodyMuted,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: UiText(context.uiCopy('Keep')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: UiText(context.uiCopy('Remove'),
                  style: TextStyle(color: AppColors.softCoral)),
            ),
          ],
        ),
      ) ??
      false;
}

Future<bool> _confirmClearAll(BuildContext context) async {
  return await showSilarahDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: UiText(context.uiCopy('Clear notification history?'),
              style: AppTypography.bodyMedium),
          content: UiText(
            context.uiCopy(
                'Every notification will be permanently removed. New notifications will continue to arrive normally.'),
            style: AppTypography.bodyMuted,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: UiText(context.uiCopy('Cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: UiText(context.uiCopy('Clear all'),
                  style: TextStyle(color: AppColors.softCoral)),
            ),
          ],
        ),
      ) ??
      false;
}

void _showDeleteError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: UiText(
          context.uiCopy('Could not remove notifications. Please try again.')),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
  });
  final NotificationItem item;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final iconData = _iconFor(item.type);
    final iconColor = _colorFor(item.type);
    final title =
        item.title.trim().isEmpty ? 'Notification' : item.title.trim();
    final body = item.body.trim().isEmpty
        ? 'Open Silarah to view the latest update.'
        : item.body.trim();

    return RepaintBoundary(
      child: Material(
        color: AppColors.surfaceGlass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          side: BorderSide(
            // Unread is carried by the dot and a faint accent edge; a full
            // dark outline on every card read as harsh, not premium.
            color: item.isRead
                ? AppColors.cardBorder
                : AppColors.champagneGold.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor.withValues(alpha: 0.15),
                    border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(iconData, color: iconColor, size: 20),
                ),
                const SizedBox(width: AppDimensions.space12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: UiText(
                              title,
                              style: item.isRead
                                  ? AppTypography.body
                                  : AppTypography.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.space8),
                          UiText(
                            _timeLabel(context, item.time),
                            style: AppTypography.caption,
                          ),
                          if (!item.isRead) ...[
                            const SizedBox(width: AppDimensions.space6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: AppColors.champagneGold,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppDimensions.space4),
                      UiText(
                        body,
                        style: AppTypography.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'interest_received':
        return Icons.favorite_rounded;
      case 'interest_accepted':
        return Icons.check_circle_rounded;
      case 'interest_expiring':
        return Icons.schedule_rounded;
      case 'interest_expired':
        return Icons.history_toggle_off_rounded;
      case 'new_message':
        return Icons.chat_bubble_rounded;
      case 'boost_ready':
        return Icons.rocket_launch_rounded;
      case 'profile_live':
        return Icons.verified_rounded;
      case 'new_compatible_profiles':
        return Icons.explore_rounded;
      case 'photo_access_request':
        return Icons.lock_person_outlined;
      case 'photo_access_granted':
        return Icons.photo_library_outlined;
      case 'profile_returned_to_review':
      case 'photo_rejected':
      case 'photo_verification_reviewed':
        return Icons.info_rounded;
      case 'photo_approved':
      case 'photo_verification_approved':
      case 'account_restored':
        return Icons.check_circle_rounded;
      case 'account_suspended':
      case 'account_banned':
        return Icons.block_rounded;
      case 'subscription_active':
      case 'subscription_renewed':
      case 'subscription_updated':
        return Icons.workspace_premium_rounded;
      case 'subscription_cancelled':
      case 'subscription_expired':
      case 'subscription_refunded':
        return Icons.workspace_premium_outlined;
      case 'billing_issue':
        return Icons.credit_card_off_rounded;
      case 'profile_view':
        return Icons.visibility_rounded;
      case 'festival_greeting':
        return Icons.nightlight_round;
      case 'profile_nudge':
        return Icons.person_add_alt_1_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'interest_received':
        return AppColors.champagneGold;
      case 'interest_accepted':
        return AppColors.verifiedTeal;
      case 'interest_expiring':
        return AppColors.expiryAmber;
      case 'interest_expired':
        return AppColors.slateMist;
      case 'new_message':
        return AppColors.messageBlue;
      case 'boost_ready':
        return AppColors.champagneGold;
      case 'profile_live':
        return AppColors.verifiedTeal;
      case 'new_compatible_profiles':
        return AppColors.verifiedTeal;
      case 'photo_access_request':
        return AppColors.champagneGold;
      case 'photo_access_granted':
        return AppColors.verifiedTeal;
      case 'profile_returned_to_review':
      case 'photo_rejected':
      case 'photo_verification_reviewed':
        return AppColors.champagneGold;
      case 'photo_approved':
      case 'photo_verification_approved':
      case 'account_restored':
        return AppColors.verifiedTeal;
      case 'account_suspended':
      case 'account_banned':
        return AppColors.errorRed;
      case 'festival_greeting':
        return AppColors.champagneGold;
      case 'profile_nudge':
        return AppColors.champagneGold;
      default:
        return AppColors.slateMist;
    }
  }

  String _timeLabel(BuildContext context, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return context.uiMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return context.uiHoursAgo(diff.inHours);
    if (diff.inDays == 1) return context.uiCopy('Yesterday');
    return context.uiDaysAgo(diff.inDays);
  }
}

// Empty state
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.space24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder, width: 2),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: AppColors.slateMist,
              size: 48,
            ),
          ),
          const SizedBox(height: AppDimensions.space24),
          UiText(
            AppLocalizations.of(context).notifications_empty_title,
            style: AppTypography.screenTitle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: AppDimensions.space8),
          UiText(
            AppLocalizations.of(context).notifications_empty_subtitle,
            style: AppTypography.bodyMuted,
          ),
        ],
      ),
    );
  }
}
