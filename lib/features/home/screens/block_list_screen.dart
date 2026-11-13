//
// Shows all blocked profiles from BlockReportCubit.
// Each row: avatar, name, age, city, Unblock button.
// Empty state: SilarahEmptyState with block icon.
// Navigate from Settings → Safety → "Blocked Profiles".
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/block_report/block_report_cubit.dart';
import '../../../core/cubits/block_report/block_report_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/silarah_empty_state.dart';
import '../../../core/widgets/overlays/silarah_dialog.dart';

class BlockListScreen extends StatefulWidget {
  const BlockListScreen({super.key});

  @override
  State<BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends State<BlockListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BlockReportCubit>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BlockReportCubit, BlockReportState>(
      builder: (context, state) {
        final blocked = state.blockedUsers;

        return Scaffold(
          backgroundColor: AppColors.obsidianNight,
          appBar: _BlockListAppBar(count: blocked.length),
          body: blocked.isEmpty
              ? const SilarahEmptyState(
                  icon: Icons.block_rounded,
                  title: 'No blocked profiles',
                  subtitle: 'Profiles you block will appear here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space24,
                    vertical: AppDimensions.space16,
                  ),
                  itemCount: blocked.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppDimensions.space12),
                  itemBuilder: (_, i) {
                    final b = blocked[i];
                    return _BlockedTile(
                      blockedUser: b,
                      onUnblock: () => _showUnblockDialog(context, b),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showUnblockDialog(BuildContext context, BlockedUser user) {
    HapticFeedback.selectionClick();
    showSilarahDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        title: UiText(context.uiCopy('Unblock this person?'),
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.pearlWhite, fontSize: 17)),
        content: UiText(
          context.uiCopyWith('{name} will be able to find your profile again.',
              {'name': '${user.name} ${user.lastInitial}.'}),
          style: AppTypography.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: UiText(context.uiCopy('Cancel'),
                style:
                    AppTypography.caption.copyWith(color: AppColors.slateMist)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<BlockReportCubit>().unblockUser(user.userId);
            },
            child: UiText(context.uiCopy('Unblock'),
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.champagneGold, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// AppBar
class _BlockListAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _BlockListAppBar({required this.count});
  final int count;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: AppColors.obsidianNight,
        border: Border(
          bottom: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(AppDimensions.space8),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Icon(Icons.arrow_back_rounded,
                  semanticLabel: context.uiCopy('Back'),
                  color: AppColors.pearlWhite,
                  size: AppDimensions.iconSizeMedium),
            ),
          ),
          const SizedBox(width: AppDimensions.space8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(context.uiCopy('Blocked Profiles'),
                    style: AppTypography.bodyMedium),
                if (count > 0)
                  UiText(context.uiBlockedCount(count),
                      style: AppTypography.caption.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Blocked Tile
class _BlockedTile extends StatelessWidget {
  const _BlockedTile({
    required this.blockedUser,
    required this.onUnblock,
  });
  final BlockedUser blockedUser;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final name = '${blockedUser.name} ${blockedUser.lastInitial}.';
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceGlassHover,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: AppColors.slateMist,
              size: 26,
            ),
          ),
          const SizedBox(width: AppDimensions.space12),

          // Name + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(name, style: AppTypography.bodyMedium),
                const SizedBox(height: AppDimensions.space2),
                UiText(context.uiCopy('Blocked profile'),
                    style: AppTypography.caption),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.space12),

          // Unblock button
          OutlinedButton(
            onPressed: onUnblock,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.cardBorder),
              foregroundColor: AppColors.pearlWhite,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space14,
                vertical: AppDimensions.space8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              ),
            ),
            child: UiText(context.uiCopy('Unblock'),
                style: AppTypography.caption
                    .copyWith(color: AppColors.pearlWhite, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
