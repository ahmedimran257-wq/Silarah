// SILARAH - Profile For Whom Screen (fast-start step 1)
// Two primary options: Myself / Guardian.
// Selecting Guardian expands to show relationship sub-options:
//   Son, Daughter, Brother, Sister.
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/animations/silarah_motion.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../widgets/step_header.dart';

class ProfileForWhomScreen extends StatefulWidget {
  const ProfileForWhomScreen({super.key});

  @override
  State<ProfileForWhomScreen> createState() => _ProfileForWhomScreenState();
}

class _ProfileForWhomScreenState extends State<ProfileForWhomScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedCategory;
  String? _selectedRelation;
  bool _advancing = false;
  String? _saveError;

  late final AnimationController _expandCtrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _expandAnim = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeOutCubic,
    );

    final data = context.read<OnboardingCubit>().currentData;
    if (data.profileFor != null) {
      _selectedCategory =
          data.profileFor == ProfileFor.myself ? 'self' : 'guardian';
    }
    if (data.profileCreatorRelation != null &&
        data.profileCreatorRelation != 'self') {
      _selectedRelation = data.profileCreatorRelation;
    }
    if (_selectedCategory == 'guardian') {
      _expandCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  void _selectSelf() async {
    if (_advancing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.lightImpact();
    setState(() {
      _selectedCategory = 'self';
      _selectedRelation = null;
      _advancing = true;
      _saveError = null;
    });
    _expandCtrl.reverse();

    if (!mounted) return;
    final cubit = context.read<OnboardingCubit>();
    final current = cubit.currentData;
    await cubit.saveAndAdvance(current.copyWith(
      profileFor: ProfileFor.myself,
      profileOwnerType: ProfileOwnerType.self,
      wardRelationship: 'self',
      profileCreatorRelation: 'self',
      isGuardianMode: false,
      guardianMode: 'none',
    ));
    if (mounted && context.read<OnboardingCubit>().currentStep == 0) {
      setState(() => _advancing = false);
    }
  }

  void _selectGuardian() {
    if (_advancing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.lightImpact();
    setState(() {
      _selectedCategory = 'guardian';
      _selectedRelation = null;
      _saveError = null;
    });
    _expandCtrl.forward();
  }

  void _selectRelation(String relation) async {
    if (_advancing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedRelation = relation;
      _advancing = true;
      _saveError = null;
    });

    if (!mounted) return;
    final cubit = context.read<OnboardingCubit>();
    final current = cubit.currentData;
    final wardGender = _wardGenderForRelation(relation);
    await cubit.saveAndAdvance(current.copyWith(
      profileFor: ProfileFor.guardian,
      profileOwnerType: ProfileOwnerType.guardian,
      wardRelationship: relation,
      wardGender: wardGender,
      gender: wardGender,
      profileCreatorRelation: relation,
      isGuardianMode: true,
      guardianMode: 'none',
    ));
    if (mounted && context.read<OnboardingCubit>().currentStep == 0) {
      setState(() => _advancing = false);
    }
  }

  Gender _wardGenderForRelation(String relation) {
    switch (relation) {
      case 'daughter':
      case 'sister':
        return Gender.female;
      case 'son':
      case 'brother':
      default:
        return Gender.male;
    }
  }

  Future<void> _exitOnboarding() async {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.lightImpact();
    await context.read<AuthCubit>().signOut();
    if (!mounted) return;
    context.go(AppRoutes.splash);
  }

  Future<void> _retrySave() async {
    setState(() {
      _advancing = true;
      _saveError = null;
    });
    await context.read<OnboardingCubit>().retryFailedSave();
    if (mounted && context.read<OnboardingCubit>().state is OnboardingError) {
      setState(() => _advancing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocListener<OnboardingCubit, OnboardingState>(
      listener: (context, state) {
        // Navigation is handled by GoRouter after AuthCubit step updates.
        if (state is OnboardingSaved && state.step > 0) {
          if (mounted) setState(() => _advancing = false);
          context.go(onboardingPathForStep(state.step));
        }
        if (state is OnboardingError) {
          setState(() {
            _advancing = false;
            _saveError = state.message;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: UiText(
                state.message,
                style: TextStyle(
                  color: AppColors.readableOn(AppColors.softCoral),
                ),
              ),
              backgroundColor: AppColors.softCoral,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.obsidianNight,
        body: SafeArea(
          child: SilarahEntrance(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.space24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: GestureDetector(
                            onTap: _exitOnboarding,
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
                                semanticLabel: context.uiCopy('Back'),
                                color: AppColors.pearlWhite,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space24),
                        StepHeader(
                          title: l10n.onboarding_profileForWhom_title,
                          subtitle: l10n.guide_profile_ownership,
                        ),
                        const SizedBox(height: AppDimensions.space32),

                        // Option 1: Myself
                        _SelectionCard(
                          icon: Icons.person_outline_rounded,
                          title: l10n.onboarding_profileForWhom_myself,
                          subtitle: l10n.onboarding_profileForWhom_myselfSub,
                          isSelected: _selectedCategory == 'self',
                          onTap: _advancing ? null : _selectSelf,
                          showChevron: true,
                        ),
                        const SizedBox(height: AppDimensions.space16),

                        // Option 2: Guardian
                        _SelectionCard(
                          icon: Icons.family_restroom_rounded,
                          title:
                              l10n.onboarding_profileForWhom_guardianCardTitle,
                          subtitle:
                              l10n.onboarding_profileForWhom_guardianCardSub,
                          isSelected: _selectedCategory == 'guardian',
                          onTap: _advancing ? null : _selectGuardian,
                          showChevron: true,
                          isExpanded: _selectedCategory == 'guardian',
                        ),

                        // Guardian sub-options (animated expand)
                        SilarahSizeReveal(
                          factor: _expandAnim,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: AppDimensions.space12,
                              left: AppDimensions.space8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: AppDimensions.space12,
                                    bottom: AppDimensions.space10,
                                  ),
                                  child: UiText(
                                    l10n.onboarding_profileForWhom_creatingFor,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.champagneGold,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _RelationChip(
                                        icon: Icons.boy_rounded,
                                        label: l10n
                                            .onboarding_profileForWhom_relation_son,
                                        isSelected: _selectedRelation == 'son',
                                        onTap: _advancing
                                            ? null
                                            : () => _selectRelation('son'),
                                      ),
                                    ),
                                    const SizedBox(
                                        width: AppDimensions.space10),
                                    Expanded(
                                      child: _RelationChip(
                                        icon: Icons.girl_rounded,
                                        label: l10n
                                            .onboarding_profileForWhom_relation_daughter,
                                        isSelected:
                                            _selectedRelation == 'daughter',
                                        onTap: _advancing
                                            ? null
                                            : () => _selectRelation('daughter'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppDimensions.space10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _RelationChip(
                                        icon: Icons.person_outline_rounded,
                                        label: l10n
                                            .onboarding_profileForWhom_relation_brother,
                                        isSelected:
                                            _selectedRelation == 'brother',
                                        onTap: _advancing
                                            ? null
                                            : () => _selectRelation('brother'),
                                      ),
                                    ),
                                    const SizedBox(
                                        width: AppDimensions.space10),
                                    Expanded(
                                      child: _RelationChip(
                                        icon: Icons.person_outline_rounded,
                                        label: l10n
                                            .onboarding_profileForWhom_relation_sister,
                                        isSelected:
                                            _selectedRelation == 'sister',
                                        onTap: _advancing
                                            ? null
                                            : () => _selectRelation('sister'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_saveError != null) ...[
                          const SizedBox(height: AppDimensions.space16),
                          _ProfileForWhomSaveError(
                            message: _saveError!,
                            isLoading: _advancing,
                            onRetry: _retrySave,
                          ),
                        ],

                        const Spacer(),

                        // Subtle note
                        Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: _advancing
                                ? const SilarahPulseLoader(
                                    key: ValueKey('profile-for-whom-loading'),
                                    size: 24,
                                  )
                                : UiText(
                                    key:
                                        const ValueKey('profile-for-whom-hint'),
                                    _selectedCategory == 'guardian' &&
                                            _selectedRelation == null
                                        ? l10n
                                            .onboarding_profileForWhom_selectRelation
                                        : l10n
                                            .onboarding_profileForWhom_selectOne,
                                    style: AppTypography.caption,
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space24),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileForWhomSaveError extends StatelessWidget {
  const _ProfileForWhomSaveError({
    required this.message,
    required this.isLoading,
    required this.onRetry,
  });

  final String message;
  final bool isLoading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
      child: Row(
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
          TextButton.icon(
            onPressed: isLoading ? null : onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: UiText(context.uiCopy('Retry')),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.champagneGold,
            ),
          ),
        ],
      ),
    );
  }
}

// Selection Card (primary option)
class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.showChevron = false,
    this.isExpanded = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      haptic: false,
      onTap: onTap == null
          ? null
          : () {
              FocusManager.instance.primaryFocus?.unfocus();
              onTap!();
            },
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(AppDimensions.space20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.08)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: AppDimensions.borderThin,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.champagneGold.withValues(alpha: 0.15)
                    : AppColors.surfaceGlassHover,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color:
                    isSelected ? AppColors.champagneGold : AppColors.slateMist,
                size: AppDimensions.iconSizeLarge,
              ),
            ),
            const SizedBox(width: AppDimensions.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText(
                    title,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isSelected
                          ? AppColors.champagneGold
                          : AppColors.pearlWhite,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  UiText(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            if (showChevron)
              AnimatedRotation(
                turns: isExpanded ? 0.25 : 0.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: isSelected
                      ? AppColors.champagneGold
                      : AppColors.slateMist,
                  size: 22,
                ),
              )
            else
              AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.0,
                duration: AppDimensions.durationTransition,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.champagneGold,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: AppColors.obsidianNight,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Relation Chip (guardian sub-option)
class _RelationChip extends StatelessWidget {
  const _RelationChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      haptic: false,
      onTap: onTap == null
          ? null
          : () {
              FocusManager.instance.primaryFocus?.unfocus();
              onTap!();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space14,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.12)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: AppDimensions.borderThin,
          ),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppDimensions.space8,
          runSpacing: AppDimensions.space4,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.champagneGold : AppColors.slateMist,
              size: 20,
            ),
            UiText(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color:
                    isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
                fontSize: 14,
              ),
            ),
            if (isSelected) ...[
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.champagneGold,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: AppColors.obsidianNight,
                  size: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
