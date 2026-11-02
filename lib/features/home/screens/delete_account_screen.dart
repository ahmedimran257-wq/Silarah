// SILARAH — Delete Account Screen (Feature 15)
// Multi-step AnimatedSwitcher flow:
//   Step 1: Warning + 30-day grace info
//   Step 2: Reason selection
//   Step 3: Type "DELETE" confirmation field
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../l10n/generated/app_localizations.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  int _step = 1;
  String? _reason;
  // One deletion request at a time; a second tap would also sign out twice.
  bool _submitting = false;
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _next() => setState(() => _step++);

  void _back() {
    if (_step > 1) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await _requestDeletion();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _requestDeletion() async {
    HapticFeedback.mediumImpact();

    if (SupabaseService.isInitialized) {
      try {
        final userId = SupabaseService.currentUserId;
        if (userId != null) {
          // A stalled connection ends in the error message, not a spinner.
          await SupabaseService.client.rpc(
            'request_my_account_deletion',
            params: {'p_reason': _reason},
          ).timeout(const Duration(seconds: 20));

          // Store identity is cleared by the shared auth sign-out listener.
          // FCM onUserLogout deletes the device token before sign-out.
          try {
            await FcmService.instance.onUserLogout();
          } catch (e) {
            debugPrint('FCM onUserLogout error: $e');
          }
        }
      } catch (e) {
        debugPrint('Account deletion error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: UiText(context.uiDeleteFailed(e),
                  style: AppTypography.body.copyWith(
                    color: AppColors.readableOn(AppColors.errorRed),
                  )),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return;
      }
    }

    if (mounted) {
      // The app-level messenger outlives this route, so the confirmation is
      // still visible on the welcome screen after sign-out.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UiText(context.uiCopy(
              'Your account will be deleted in 30 days. You can log back in anytime before then to cancel.')),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
      context.read<AuthCubit>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: AppColors.obsidianNight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: _back,
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
        title: UiText(
          AppLocalizations.of(context).deleteAccount_title,
          style: AppTypography.screenTitle
              .copyWith(fontSize: 20, color: AppColors.softCoral),
        ),
      ),
      body: AnimatedSwitcher(
        duration: AppDimensions.durationReveal,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.1, 0),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: switch (_step) {
          1 => _Step1(
              key: const ValueKey(1),
              onKeepAccount: () => Navigator.pop(context),
              onContinue: _next),
          2 => _Step2(
              key: const ValueKey(2),
              reason: _reason,
              onSelect: (r) => setState(() => _reason = r),
              onContinue: _next),
          _ => _Step3(
              key: const ValueKey(3),
              ctrl: _confirmCtrl,
              submitting: _submitting,
              onConfirm: _confirm,
              onChange: () => setState(() {})),
        },
      ),
    );
  }
}

// Step 1 — Warning
class _Step1 extends StatelessWidget {
  const _Step1(
      {super.key, required this.onKeepAccount, required this.onContinue});
  final VoidCallback onKeepAccount;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppDimensions.space32),
          Container(
            padding: const EdgeInsets.all(AppDimensions.space24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.softCoral.withValues(alpha: 0.10),
              border: Border.all(
                  color: AppColors.softCoral.withValues(alpha: 0.4), width: 2),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: AppColors.softCoral,
              size: 56,
            ),
          ),
          const SizedBox(height: AppDimensions.space32),
          UiText(
            context.uiCopy('Delete your account?'),
            style: AppTypography.screenTitle.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.space16),
          UiText(
            context.uiCopy(
                'We\'d hate to see you go. Before you proceed, here\'s what will happen:'),
            style: AppTypography.bodyMuted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.space24),
          _InfoCard(
            icon: Icons.timer_outlined,
            color: AppColors.premiumGold,
            title: '30-day grace period',
            body:
                'Your account will be scheduled for deletion. You can log back in any time within 30 days to cancel.',
          ),
          const SizedBox(height: AppDimensions.space12),
          _InfoCard(
            icon: Icons.delete_sweep_outlined,
            color: AppColors.softCoral,
            title: 'Permanent data loss',
            body:
                'All matches, messages, and profile data will be permanently deleted after 30 days. This cannot be undone.',
          ),
          const SizedBox(height: AppDimensions.space12),
          _InfoCard(
            icon: Icons.credit_card_off_outlined,
            color: AppColors.slateMist,
            title: 'Cancel store billing separately',
            body:
                'Deleting Silarah does not cancel Apple or Google billing. Cancel your subscription in the store before continuing.',
          ),
          const SizedBox(height: AppDimensions.space40),
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.champagneGold,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                ),
              ),
              onPressed: onKeepAccount,
              child: UiText(context.uiCopy('Keep My Account'),
                  style: AppTypography.button),
            ),
          ),
          const SizedBox(height: AppDimensions.space12),
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeight,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.softCoral),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                ),
              ),
              onPressed: onContinue,
              child: UiText(context.uiCopy('Continue'),
                  style:
                      AppTypography.body.copyWith(color: AppColors.softCoral)),
            ),
          ),
          const SizedBox(height: AppDimensions.space40),
        ],
      ),
    );
  }
}

// Step 2 — Reason
class _Step2 extends StatelessWidget {
  const _Step2({
    super.key,
    required this.reason,
    required this.onSelect,
    required this.onContinue,
  });
  final String? reason;
  final ValueChanged<String> onSelect;
  final VoidCallback onContinue;

  static const _reasons = [
    'Found my match on Silarah',
    'Found match elsewhere',
    'Taking a break',
    'Privacy concerns',
    'App quality issues',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.space16),
          UiText(context.uiCopy('Why are you leaving?'),
              style: AppTypography.screenTitle.copyWith(fontSize: 22)),
          const SizedBox(height: AppDimensions.space8),
          UiText('This helps us improve Silarah for others.',
              style: AppTypography.bodyMuted),
          const SizedBox(height: AppDimensions.space24),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: List.generate(_reasons.length, (i) {
                final r = _reasons[i];
                final isSelected = reason == r;
                final isLast = i == _reasons.length - 1;
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () => onSelect(r),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: AppDimensions.durationTransition,
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? AppColors.champagneGold
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.champagneGold
                                      : AppColors.slateMist,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? Icon(Icons.check_rounded,
                                      color: AppColors.obsidianNight, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: UiText(r, style: AppTypography.body),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      Divider(color: AppColors.divider, height: 1, indent: 52),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: AppDimensions.space32),
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: reason != null
                    ? AppColors.softCoral
                    : AppColors.surfaceGlassHover,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                ),
              ),
              onPressed: reason != null ? onContinue : null,
              child: UiText(context.uiCopy('Continue'),
                  style: AppTypography.button.copyWith(
                    color: reason != null ? Colors.white : AppColors.slateMist,
                  )),
            ),
          ),
          const SizedBox(height: AppDimensions.space40),
        ],
      ),
    );
  }
}

// Step 3 — Confirmation
class _Step3 extends StatelessWidget {
  const _Step3({
    super.key,
    required this.ctrl,
    required this.submitting,
    required this.onConfirm,
    required this.onChange,
  });
  final TextEditingController ctrl;
  final bool submitting;
  final VoidCallback onConfirm;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final canConfirm = ctrl.text.trim() == 'DELETE' && !submitting;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.space16),
          UiText(context.uiCopy('Last step'),
              style: AppTypography.screenTitle.copyWith(fontSize: 22)),
          const SizedBox(height: AppDimensions.space8),
          UiText(
              context.uiCopy(
                  'Type DELETE to confirm you want to delete your account.'),
              style: AppTypography.bodyMuted),
          const SizedBox(height: AppDimensions.space24),

          // Confirmation info card
          Container(
            padding: const EdgeInsets.all(AppDimensions.space16),
            decoration: BoxDecoration(
              color: AppColors.softCoral.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              border:
                  Border.all(color: AppColors.softCoral.withValues(alpha: 0.3)),
            ),
            child: UiText(
              context.uiCopy(
                  'Your account will be deleted in 30 days. You can log back in anytime before then to cancel.'),
              style: AppTypography.body
                  .copyWith(color: AppColors.softCoral.withValues(alpha: 0.9)),
            ),
          ),
          const SizedBox(height: AppDimensions.space24),

          // Type DELETE field
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              border: Border.all(
                color: canConfirm ? AppColors.softCoral : AppColors.cardBorder,
                width: canConfirm
                    ? AppDimensions.borderFocus
                    : AppDimensions.borderThin,
              ),
            ),
            child: TextField(
              controller: ctrl,
              onChanged: (_) => onChange(),
              style: AppTypography.inputText.copyWith(
                letterSpacing: 2,
                color: canConfirm ? AppColors.softCoral : AppColors.pearlWhite,
              ),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: context.uiCopy('DELETE'),
                hintText: context.uiCopy('Type DELETE here'),
                hintStyle: AppTypography.inputText
                    .copyWith(color: AppColors.slateMist),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space16,
                    vertical: AppDimensions.space16),
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.space32),
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: canConfirm
                    ? AppColors.softCoral
                    : AppColors.surfaceGlassHover,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                ),
              ),
              onPressed: canConfirm ? onConfirm : null,
              child: submitting
                  ? const SilarahPulseLoader(size: 26)
                  : UiText(
                      context.uiCopy('Delete Account'),
                      style: AppTypography.button.copyWith(
                        color: canConfirm ? Colors.white : AppColors.slateMist,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppDimensions.space40),
        ],
      ),
    );
  }
}

// Info card for step 1
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: AppDimensions.iconSizeLarge),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(title,
                    style: AppTypography.bodyMedium.copyWith(color: color)),
                const SizedBox(height: AppDimensions.space4),
                UiText(body, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
