// SILARAH — Legal Gate Screen
// Two mandatory checkboxes (age + terms).
// Cannot proceed without both checked.
// Consent is cached pre-auth and flushed to user_consents after email OTP auth.
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_primary_button.dart';
import '../../../core/widgets/buttons/silarah_secondary_button.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/notification_navigation.dart';
import '../../home/screens/legal_doc_screen.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/services/legal_consent_service.dart';

class LegalGateScreen extends StatefulWidget {
  const LegalGateScreen({super.key});

  @override
  State<LegalGateScreen> createState() => _LegalGateScreenState();
}

class _LegalGateScreenState extends State<LegalGateScreen> {
  bool _ageConfirmed = false;
  bool _termsConfirmed = false;
  bool _specialCategoryConsent = false;
  bool _isSaving = false;
  String? _saveError;

  bool get _canProceed =>
      !_isSaving && _ageConfirmed && _termsConfirmed && _specialCategoryConsent;

  Future<void> _continue() async {
    if (!_canProceed) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    final saved =
        await LegalConsentService.instance.recordPendingOnboardingConsents();
    if (!mounted) return;

    if (!saved) {
      setState(() {
        _isSaving = false;
        _saveError = 'Could not save. Please try again.';
      });
      return;
    }

    setState(() => _isSaving = false);
    context.push('${AppRoutes.email}?mode=signup');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.5), // slightly above center
            radius: 1.2,
            colors: [
              AppColors.navyCharcoal, // Deep premium navy-charcoal core
              AppColors.obsidianNight, // Deep midnight edges
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            // Stretch so the header aligns to the screen edge instead of
            // centring around the title's width.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.space24,
                  AppDimensions.space32,
                  AppDimensions.space24,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back
                    GestureDetector(
                      // A member sent back to accept again arrives as the root.
                      onTap: () => popOrGoToFallback(
                        GoRouter.of(context),
                        AppRoutes.splash,
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGlass,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.arrow_forward_ios_rounded
                              : Icons.arrow_back_ios_new_rounded,
                          color: AppColors.pearlWhite,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space32),
                    UiText(l10n.legal_title, style: AppTypography.screenTitle),
                    const SizedBox(height: AppDimensions.space8),
                    UiText(
                      l10n.legal_subtitle,
                      style: AppTypography.bodyMuted,
                    ),
                  ],
                ),
              ),

              // Scrollable body
              Expanded(
                // Scrolled text fades out under the heading and above the
                // button instead of being cut off.
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00FFFFFF),
                      Color(0xFFFFFFFF),
                      Color(0xFFFFFFFF),
                      Color(0x00FFFFFF),
                    ],
                    stops: [0, 0.04, 0.95, 1],
                  ).createShader(bounds),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space24,
                      vertical: AppDimensions.space24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TermsSummaryCard(),
                        const SizedBox(height: AppDimensions.space24),

                        // Checkboxes
                        _SilarahCheckbox(
                          value: _ageConfirmed,
                          onChanged: (v) =>
                              setState(() => _ageConfirmed = v ?? false),
                          label: l10n.legal_checkbox_age,
                        ),
                        const SizedBox(height: AppDimensions.space16),
                        _SilarahCheckbox(
                          value: _termsConfirmed,
                          onChanged: (v) =>
                              setState(() => _termsConfirmed = v ?? false),
                          richLabel: TextSpan(
                            style: AppTypography.body,
                            children: [
                              TextSpan(text: '${l10n.legal_checkbox_terms}\n'),
                              TextSpan(
                                text: l10n.legal_document_terms,
                                style: AppTypography.body
                                    .copyWith(color: AppColors.champagneGold),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const LegalDocScreen(
                                            type: 'tos',
                                          ),
                                        ),
                                      ),
                              ),
                              const TextSpan(text: ' · '),
                              TextSpan(
                                text: l10n.legal_document_privacy,
                                style: AppTypography.body
                                    .copyWith(color: AppColors.champagneGold),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const LegalDocScreen(
                                            type: 'privacy',
                                          ),
                                        ),
                                      ),
                              ),
                              const TextSpan(text: ' · '),
                              TextSpan(
                                text: l10n.legal_document_community,
                                style: AppTypography.body
                                    .copyWith(color: AppColors.champagneGold),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const LegalDocScreen(
                                            type: 'community-guidelines',
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space16),
                        _SilarahCheckbox(
                          value: _specialCategoryConsent,
                          onChanged: (v) => setState(
                              () => _specialCategoryConsent = v ?? false),
                          label: l10n.legal_specialCategoryConsent,
                        ),
                        const SizedBox(height: AppDimensions.space48),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.space24,
                  0,
                  AppDimensions.space24,
                  AppDimensions.space32,
                ),
                child: AnimatedOpacity(
                  opacity: _canProceed || _isSaving ? 1.0 : 0.45,
                  duration: AppDimensions.durationTransition,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_saveError != null) ...[
                        _LegalSaveError(
                          message: _saveError!,
                          isLoading: _isSaving,
                          onRetry: _continue,
                        ),
                        const SizedBox(height: AppDimensions.space12),
                      ],
                      SilarahPrimaryButton(
                        label: l10n.legal_button_continue,
                        onTap: _canProceed ? _continue : null,
                        isLoading: _isSaving,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Terms Summary Card
class _LegalSaveError extends StatelessWidget {
  const _LegalSaveError({
    required this.message,
    required this.isLoading,
    required this.onRetry,
  });

  final String message;
  final bool isLoading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space14),
      decoration: BoxDecoration(
        color: AppColors.softCoral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(
          color: AppColors.softCoral.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: AppColors.softCoral,
                size: AppDimensions.iconSizeMedium,
              ),
              const SizedBox(width: AppDimensions.space8),
              Expanded(
                child: UiText(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.pearlWhite,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space10),
          SilarahSecondaryButton(
            label: l10n.common_button_retry,
            icon: Icons.refresh_rounded,
            isLoading: isLoading,
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}

class _TermsSummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      (
        icon: Icons.security_outlined,
        text: l10n.legal_summary_1,
      ),
      (
        icon: Icons.photo_camera_outlined,
        text: l10n.legal_summary_2,
      ),
      (
        icon: Icons.block_outlined,
        text: l10n.legal_summary_3,
      ),
      (
        icon: Icons.family_restroom_outlined,
        text: l10n.legal_summary_4,
      ),
      (
        icon: Icons.delete_outline_rounded,
        text: l10n.legal_summary_5,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppDimensions.space20),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.space16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: AppColors.champagneGold, size: 20),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: UiText(item.text, style: AppTypography.body),
                ),
              ],
            ),
          );
        }).toList()
          ..last = Padding(
            padding: EdgeInsets.zero,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.delete_outline_rounded,
                    color: AppColors.champagneGold, size: 20),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: UiText(
                    l10n.legal_summary_5,
                    style: AppTypography.body,
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }
}

// Silarah Checkbox
class _SilarahCheckbox extends StatelessWidget {
  const _SilarahCheckbox({
    required this.value,
    required this.onChanged,
    this.label = '',
    this.richLabel,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;
  final InlineSpan? richLabel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onChanged(!value);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: AppDimensions.durationTransition,
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: value ? AppColors.champagneGold : AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? AppColors.champagneGold : AppColors.slateMist,
                width: value ? 0 : 1,
              ),
            ),
            child: value
                ? Icon(Icons.check_rounded,
                    color: AppColors.obsidianNight, size: 16)
                : null,
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: richLabel != null
                ? RichText(text: richLabel!)
                : UiText(label, style: AppTypography.body),
          ),
        ],
      ),
    );
  }
}
