//
//   fake_profile, inappropriate_photos, harassment, scam,
//   underage, already_married, offensive_bio, other
//
// Step 1: Select reason (radio list, 8 options)
// Step 2: "Other" only — free-text description (300 chars)
// Step 3: Confirmation ("Thank you. Review within 48 hours.")
//
// On submit:
//   - blockReportCubit.reportUser(reason, description)
//   - blockReportCubit.hideProfile(profileId)  [auto-hidden]
import 'package:silarah/l10n/generated/app_localizations.dart';
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/block_report/block_report_cubit.dart';
import '../../../core/cubits/block_report/block_report_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';

class ReportBottomSheet {
  static Future<bool> show(
    BuildContext context, {
    required String reportedUserId,
    required String reportedName,
  }) {
    return showSilarahBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<BlockReportCubit>(),
        child: _ReportContent(
          reportedUserId: reportedUserId,
          reportedName: reportedName,
        ),
      ),
    ).then((value) => value ?? false);
  }
}

class _ReportContent extends StatefulWidget {
  final String reportedUserId;
  final String reportedName;

  const _ReportContent({
    required this.reportedUserId,
    required this.reportedName,
  });

  @override
  State<_ReportContent> createState() => _ReportContentState();
}

class _ReportContentState extends State<_ReportContent> {
  // Step 1 | 2 | 3
  int _step = 1;
  bool _blocking = false;

  Future<void> _blockAfterReport() async {
    if (_blocking) return;
    setState(() => _blocking = true);
    final blocked = await context.read<BlockReportCubit>().blockUser(
          userId: widget.reportedUserId,
          name: widget.reportedName,
          lastInitial: '',
        );
    if (!mounted) return;
    setState(() => _blocking = false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!blocked) {
      messenger?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: UiText(context
            .uiCopy('We could not block this member. Please try again.')),
      ));
      return;
    }
    Navigator.pop(context, true);
    messenger?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: UiText(context.uiCopy(
          'Blocked. They can no longer see your profile or contact you.')),
    ));
  }

  ReportReason? _selected;
  final _descController = TextEditingController();

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final cubit = context.read<BlockReportCubit>();
    if (cubit.state.isSubmitting) return;
    final submitted = await cubit.reportUser(
      reportedUserId: widget.reportedUserId,
      reportedName: widget.reportedName,
      reason: _selected!,
      description:
          _selected == ReportReason.other ? _descController.text.trim() : null,
    );
    if (!mounted) return;
    if (submitted) {
      setState(() => _step = 3);
      return;
    }
    final message =
        cubit.state.error ?? 'Report could not be submitted. Please retry.';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: UiText(context.uiCopy(message))));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).viewPadding.bottom;

    return BlocBuilder<BlockReportCubit, BlockReportState>(
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceMid,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.goldBorder)),
          ),
          padding: EdgeInsets.fromLTRB(
              AppDimensions.space24,
              AppDimensions.space20,
              AppDimensions.space24,
              AppDimensions.space24 + bottomPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.space20),

              // Animated step content
              AnimatedSwitcher(
                duration: AppDimensions.durationTransition,
                child: _step == 1
                    ? _Step1(
                        key: const ValueKey(1),
                        reportedName: widget.reportedName,
                        selected: _selected,
                        isLoading: state.isSubmitting,
                        onSelect: (r) => setState(() => _selected = r),
                        onNext: () {
                          if (_selected == ReportReason.other) {
                            setState(() => _step = 2);
                          } else {
                            _onSubmit();
                          }
                        },
                      )
                    : _step == 2
                        ? _Step2(
                            key: const ValueKey(2),
                            controller: _descController,
                            isLoading: state.isSubmitting,
                            onBack: () => setState(() => _step = 1),
                            onSubmit: _onSubmit,
                          )
                        : _Step3(
                            key: const ValueKey(3),
                            reportedName: widget.reportedName,
                            isBlocking: _blocking,
                            onDone: () => Navigator.pop(context, true),
                            // Some members cannot open the chat or profile
                            // again after a report (it is hidden from their
                            // feed), so blocking is offered right here.
                            onBlock: _blockAfterReport,
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Step 1: Select Reason
class _Step1 extends StatelessWidget {
  final String reportedName;
  final ReportReason? selected;
  final ValueChanged<ReportReason> onSelect;
  final bool isLoading;
  final VoidCallback onNext;

  const _Step1({
    super.key,
    required this.reportedName,
    required this.selected,
    required this.onSelect,
    required this.isLoading,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        UiText(
          context.uiCopyWith('Report {name}', {'name': reportedName}),
          style: AppTypography.screenTitle.copyWith(fontSize: 20),
        ),
        const SizedBox(height: AppDimensions.space6),
        UiText(
          context.uiCopy(
              'Help keep the community safe. We don\'t tell this member who reported them, unless a fair process or the law requires it.'),
          style: AppTypography.bodyMuted,
        ),
        const SizedBox(height: AppDimensions.space20),

        // Scrollable reason list
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              children: ReportReason.values
                  .map(
                    (reason) => _ReasonTile(
                      reason: reason,
                      isSelected: selected == reason,
                      onTap: () => onSelect(reason),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),

        const SizedBox(height: AppDimensions.space20),

        // Next / Submit button
        GestureDetector(
          onTap: selected == null || isLoading ? null : onNext,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected == null || isLoading
                  ? AppColors.surfaceGlass
                  : AppColors.softCoral,
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SilarahPulseLoader(
                    size: 24,
                    accentColor: AppColors.pearlWhite,
                    highlightColor: AppColors.pearlWhite,
                    markColor: AppColors.softCoral,
                    coreGradientColors: [
                      AppColors.pearlWhite,
                      AppColors.pearlWhite,
                    ],
                  )
                : UiText(
                    selected == ReportReason.other ? 'Next' : 'Submit Report',
                    style: AppTypography.button.copyWith(
                      color: selected == null
                          ? AppColors.slateMist
                          : AppColors.readableOn(AppColors.softCoral),
                    ),
                  ),
          ),
        ),

        const SizedBox(height: AppDimensions.space10),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: UiText(context.uiCopy('Cancel'),
                style: AppTypography.bodyMuted),
          ),
        ),
      ],
    );
  }
}

// Step 2: Other — free text
class _Step2 extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const _Step2({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Back link
        GestureDetector(
          onTap: onBack,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_rounded,
                  color: AppColors.slateMist, size: 16),
              const SizedBox(width: AppDimensions.space4),
              UiText(context.uiCopy('Back'),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.slateMist)),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.space16),

        UiText(context.uiCopy('Tell us more'),
            style: AppTypography.bodyMedium.copyWith(fontSize: 18)),
        const SizedBox(height: AppDimensions.space6),
        UiText(context.uiCopy('Optional — helps our team review faster.'),
            style: AppTypography.bodyMuted),
        const SizedBox(height: AppDimensions.space16),

        TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 300,
          style: AppTypography.body,
          decoration: InputDecoration(
            hintText: context.uiCopy('Describe the issue…'),
            hintStyle: AppTypography.bodyMuted,
            fillColor: AppColors.surfaceGlass,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.champagneGold,
                width: AppDimensions.borderThin,
              ),
            ),
            counterStyle: AppTypography.caption,
          ),
        ),
        const SizedBox(height: AppDimensions.space20),

        GestureDetector(
          onTap: isLoading ? null : onSubmit,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isLoading
                  ? AppColors.softCoral.withValues(alpha: 0.5)
                  : AppColors.softCoral,
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SilarahPulseLoader(
                    size: 24,
                    accentColor: AppColors.pearlWhite,
                    highlightColor: AppColors.pearlWhite,
                    markColor: AppColors.softCoral,
                    coreGradientColors: [
                      AppColors.pearlWhite,
                      AppColors.pearlWhite,
                    ],
                  )
                : UiText(context.uiCopy('Submit Report'),
                    style: AppTypography.button.copyWith(
                        color: AppColors.readableOn(AppColors.softCoral))),
          ),
        ),
      ],
    );
  }
}

// Step 3: Confirmation
class _Step3 extends StatelessWidget {
  final String reportedName;
  final bool isBlocking;
  final VoidCallback onDone;
  final VoidCallback onBlock;

  const _Step3({
    super.key,
    required this.reportedName,
    required this.isBlocking,
    required this.onDone,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppDimensions.space8),

        // Success icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.verifiedTeal.withValues(alpha: 0.12),
            border: Border.all(color: AppColors.verifiedTeal, width: 1.5),
          ),
          child: Icon(Icons.check_rounded,
              color: AppColors.verifiedTeal, size: 32),
        ),
        const SizedBox(height: AppDimensions.space20),

        UiText(context.uiCopy('Thank you for reporting.'),
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.pearlWhite, fontSize: 18),
            textAlign: TextAlign.center),
        const SizedBox(height: AppDimensions.space12),

        UiText(
          context.uiCopy(
            'We review every report within 48 hours.\n'
            'This profile has been hidden from your feed.',
          ),
          style: AppTypography.bodyMuted.copyWith(height: 1.7),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.space28),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.champagneGold,
              foregroundColor: AppColors.obsidianNight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
            child: UiText(context.uiCopy('Done'), style: AppTypography.button),
          ),
        ),
        const SizedBox(height: AppDimensions.space8),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            key: const ValueKey('report-also-block'),
            onPressed: isBlocking ? null : onBlock,
            icon: Icon(Icons.block_rounded, color: AppColors.softCoral),
            label: UiText(
              AppLocalizations.of(context).safety_blockMember(reportedName),
              style: AppTypography.button.copyWith(color: AppColors.softCoral),
            ),
          ),
        ),
      ],
    );
  }
}

// Reason Tile
class _ReasonTile extends StatelessWidget {
  final ReportReason reason;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.reason,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: AppDimensions.space8),
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space14, vertical: AppDimensions.space12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected
              ? AppColors.softCoral.withValues(alpha: 0.12)
              : AppColors.surfaceGlass,
          border: Border.all(
            color: isSelected ? AppColors.softCoral : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText(reason.label, style: AppTypography.body),
                  UiText(reason.detail,
                      style: AppTypography.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.softCoral : Colors.transparent,
                border: Border.all(
                  color:
                      isSelected ? AppColors.softCoral : AppColors.cardBorder,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded,
                      size: 12, color: AppColors.pearlWhite)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
