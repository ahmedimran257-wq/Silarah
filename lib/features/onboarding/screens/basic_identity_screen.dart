// SILARAH - Basic Identity Screen (fast-start step 3)
// Saves required profile identity after gender is mirrored to public.users.
// Location is read from Quick Location and shown as confirmed context.
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

import '../../../core/data/country_data.dart';
import '../../../core/services/country_context_service.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/copy_engine.dart';
import '../../../core/utils/validation_snackbar.dart';
import '../../../core/widgets/inputs/silarah_text_field.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

// Complexion options
const _kComplexions = <String>[
  'Fair',
  'Medium',
  'Olive',
  'Dark',
  'Prefer not to say',
];

// Residency status options
const _kResidencyOptions = <String>[
  'Citizen',
  'Permanent Resident',
  'Work Visa',
  'Student Visa',
  'Other',
  'Prefer not to say',
];

// Special needs options
const _kSpecialNeedsOptions = <String>[
  'None',
  'Physical disability',
  'Hearing impairment',
  'Visual impairment',
  'Other',
  'Prefer not to say',
];

// Screen
class BasicIdentityScreen extends StatefulWidget {
  const BasicIdentityScreen({super.key});

  @override
  State<BasicIdentityScreen> createState() => _BasicIdentityScreenState();
}

class _BasicIdentityScreenState extends State<BasicIdentityScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _guardianEmailCtrl = TextEditingController();
  DateTime? _dob;
  Gender? _gender;
  String _dobError = '';

  // City search
  String? _selectedCity;
  String? _selectedCountryCode;
  String? _selectedCountryName;
  String? _selectedStateName;

  // Demographics from CountryContextService
  List<String> _loadedLanguages = [];
  List<String> _loadedCommunities = ['Prefer not to say'];
  bool _isLoadingLanguages = false;
  int _demographicsRequest = 0;

  // New fields
  int _heightCm = 165;
  String? _complexion;
  String? _motherTongue;

  // Section anchors so a missing-field message can scroll to the field.
  final _nameKey = GlobalKey();
  final _dobKey = GlobalKey();
  final _genderKey = GlobalKey();
  final _motherTongueKey = GlobalKey();
  String? _community;
  String? _residencyStatus;
  String? _specialNeeds;

  // Guardian mode — derived from previous screens
  bool _isGuardianMode = false;
  String _candidateLabel = ''; // 'son', 'daughter', 'brother', 'sister'

  // What was last loaded from the cubit.
  OnboardingData? _loadedData;
  String _loadedGuardianEmail = '';
  Gender? _loadedGender;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl.addListener(_refreshCtaState);
    _lastNameCtrl.addListener(_refreshCtaState);
    _guardianEmailCtrl.addListener(_refreshCtaState);
    _applyOnboardingData(context.read<OnboardingCubit>().currentData);
  }

  /// After a re-sign-in this screen can build before the saved profile has
  /// loaded, so it applies each arrival. A field that no longer matches what
  /// was last loaded has been changed by the member and is left alone.
  void _applyOnboardingData(OnboardingData data) {
    final previous = _loadedData ?? const OnboardingData();
    final previousGuardianEmail = _loadedGuardianEmail;
    final previousGender = _loadedGender;
    _loadedData = data;

    final authState = context.read<AuthCubit>().state;
    _isGuardianMode = data.profileOwnerType == ProfileOwnerType.guardian ||
        data.profileFor == ProfileFor.guardian ||
        data.isGuardianMode ||
        (authState is AuthAuthenticated && authState.isGuardianPath);
    _candidateLabel =
        data.wardRelationship ?? data.profileCreatorRelation ?? 'self';
    final authEmail = authState is AuthAuthenticated ? authState.email : null;

    _loadedGuardianEmail = data.guardianEmail ?? data.email ?? authEmail ?? '';
    _replaceIfUntouched(
        _guardianEmailCtrl, previousGuardianEmail, _loadedGuardianEmail);

    _loadedGender = _isGuardianMode
        ? data.wardGender ??
            data.gender ??
            _wardGenderForRelation(_candidateLabel)
        : data.gender;
    if (_gender == previousGender) _gender = _loadedGender;

    _replaceIfUntouched(
        _firstNameCtrl, previous.firstName ?? '', data.firstName ?? '');
    _replaceIfUntouched(
        _lastNameCtrl, previous.lastName ?? '', data.lastName ?? '');
    if (_dob == previous.dateOfBirth) _dob = data.dateOfBirth;
    if (_heightCm == (previous.heightCm ?? 165)) {
      _heightCm = data.heightCm ?? 165;
    }
    if (_complexion == previous.complexion) _complexion = data.complexion;
    if (_motherTongue == previous.motherTongue) {
      _motherTongue = data.motherTongue;
    }
    if (_community == previous.community) _community = data.community;
    if (_residencyStatus == previous.residencyStatus) {
      _residencyStatus = data.residencyStatus;
    }
    if (_specialNeeds == previous.specialNeeds) {
      _specialNeeds = data.specialNeeds;
    }

    final previousCountryCode = _selectedCountryCode;
    final previousStateName = _selectedStateName;
    final previousCity = _selectedCity;

    if (data.countryCode != null) {
      _selectedCountryCode = data.countryCode;
      final match = kAllCountries.where(
          (c) => c.iso2.toUpperCase() == _selectedCountryCode!.toUpperCase());
      if (match.isNotEmpty) {
        _selectedCountryName = match.first.name;
      }
    }

    final savedStateName = data.stateName?.trim();
    if (savedStateName != null && savedStateName.isNotEmpty) {
      _selectedStateName = savedStateName;
    }

    if (data.cityName != null) {
      final parts = data.cityName!.split(', ');
      if (parts.length > 1) {
        _selectedCity = parts[0];
        _selectedStateName ??= parts[1];
      } else {
        _selectedCity = data.cityName;
      }
    }
    final locationChanged = _selectedCountryCode != previousCountryCode ||
        _selectedStateName != previousStateName ||
        _selectedCity != previousCity;
    if (_selectedCountryCode != null && locationChanged) {
      _fetchDemographics(
        _selectedCountryCode!,
        stateName: _selectedStateName,
        cityName: _selectedCity,
      );
    }
  }

  void _replaceIfUntouched(
    TextEditingController controller,
    String lastLoaded,
    String loaded,
  ) {
    if (controller.text == lastLoaded && controller.text != loaded) {
      controller.text = loaded;
    }
  }

  Future<void> _fetchDemographics(
    String countryCode, {
    String? stateName,
    String? cityName,
  }) async {
    final requestId = ++_demographicsRequest;
    setState(() {
      _isLoadingLanguages = true;
      _loadedLanguages = [];
    });

    final results = await Future.wait<Object>([
      CountryContextService.instance.getContext(countryCode),
      CountryContextService.instance.getLanguagesForLocation(
        countryCode: countryCode,
        stateName: stateName,
        cityName: cityName,
      ),
    ]);
    if (!mounted || requestId != _demographicsRequest) return;

    final ctx = results[0] as CountryContext;
    final languages = results[1] as List<String>;
    setState(() {
      // Urdu and Hindi lead for Indian Muslim members; the rest stay in
      // catalogue order.
      _loadedLanguages = [
        for (final top in const ['Urdu', 'Hindi'])
          if (languages.contains(top)) top,
        for (final language in languages)
          if (language != 'Urdu' && language != 'Hindi') language,
      ];
      _isLoadingLanguages = false;
      if (_motherTongue != null && !_loadedLanguages.contains(_motherTongue)) {
        _motherTongue = null;
      }
      _loadedCommunities = [...ctx.communities];
      if (!_loadedCommunities.contains('Prefer not to say')) {
        _loadedCommunities.add('Prefer not to say');
      }
    });
  }

  String get _creatorRelation =>
      context.read<OnboardingCubit>().currentData.profileCreatorRelation ??
      'self';

  bool get _hasConfirmedLocation {
    final data = context.read<OnboardingCubit>().currentData;
    return _selectedCountryCode != null &&
        _selectedCity != null &&
        data.lat != null &&
        data.lng != null;
  }

  bool get _hasGuardianDetails {
    if (!_isGuardianMode) return true;
    return _isValidEmail(_guardianEmailCtrl.text.trim());
  }

  bool get _canProceed =>
      _firstNameCtrl.text.trim().isNotEmpty &&
      _lastNameCtrl.text.trim().isNotEmpty &&
      _dob != null &&
      _dobError.isEmpty &&
      _gender != null &&
      _hasGuardianDetails &&
      _hasConfirmedLocation &&
      _motherTongue != null;

  void _showValidation() {
    final missing = <String>[];
    final firstNameLabel =
        _isGuardianMode ? "Candidate's first name" : 'First name';
    if (_firstNameCtrl.text.trim().isEmpty) missing.add(firstNameLabel);
    if (_lastNameCtrl.text.trim().isEmpty) missing.add('Last name');
    if (_dob == null) missing.add('Date of birth');
    if (_dobError.isNotEmpty) missing.add('Valid date of birth (18+)');
    if (_gender == null) missing.add('Gender');
    if (_isGuardianMode && !_isValidEmail(_guardianEmailCtrl.text.trim())) {
      missing.add('Guardian email');
    }
    if (!_hasConfirmedLocation) missing.add('Confirmed location');
    if (_motherTongue == null) missing.add('Mother tongue');
    showValidationSnackbar(context, missing);

    // Bring the first missing field into view; it may be below the fold.
    final target =
        _firstNameCtrl.text.trim().isEmpty || _lastNameCtrl.text.trim().isEmpty
            ? _nameKey
            : _dob == null || _dobError.isNotEmpty
                ? _dobKey
                : _gender == null && !_isGuardianMode
                    ? _genderKey
                    : _motherTongue == null
                        ? _motherTongueKey
                        : null;
    final targetContext = target?.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: AppDimensions.durationTransition,
        curve: Curves.easeOutCubic,
        alignment: 0.2,
      );
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.removeListener(_refreshCtaState);
    _lastNameCtrl.removeListener(_refreshCtaState);
    _guardianEmailCtrl.removeListener(_refreshCtaState);
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _guardianEmailCtrl.dispose();
    super.dispose();
  }

  void _refreshCtaState() {
    if (mounted) setState(() {});
  }

  String _getLocalizedRelation(AppLocalizations l10n) {
    if (_candidateLabel == 'son') {
      return l10n.onboarding_profileForWhom_relation_son;
    }
    if (_candidateLabel == 'daughter') {
      return l10n.onboarding_profileForWhom_relation_daughter;
    }
    if (_candidateLabel == 'brother') {
      return l10n.onboarding_profileForWhom_relation_brother;
    }
    if (_candidateLabel == 'sister') {
      return l10n.onboarding_profileForWhom_relation_sister;
    }
    return _candidateLabel;
  }

  String _wardPhrase() {
    switch (_candidateLabel) {
      case 'son':
        return 'Tell us about your son';
      case 'daughter':
        return 'Tell us about your daughter';
      case 'brother':
        return 'Tell us about your brother';
      case 'sister':
        return 'Tell us about your sister';
      default:
        return "Tell us about the person you're registering";
    }
  }

  Gender? _wardGenderForRelation(String relation) {
    switch (relation) {
      case 'daughter':
      case 'sister':
        return Gender.female;
      case 'son':
      case 'brother':
        return Gender.male;
      default:
        return null;
    }
  }

  bool _isValidEmail(String value) {
    if (value.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  String _getLocalizedComplexion(AppLocalizations l10n, String raw) {
    switch (raw) {
      case 'Fair':
        return l10n.onboarding_complexion_fair;
      case 'Medium':
        return l10n.onboarding_complexion_medium;
      case 'Olive':
        return l10n.onboarding_complexion_olive;
      case 'Dark':
        return l10n.onboarding_complexion_dark;
      case 'Prefer not to say':
        return l10n.onboarding_label_preferNotToSay;
    }
    return raw;
  }

  String _getLocalizedResidency(AppLocalizations l10n, String raw) {
    switch (raw) {
      case 'Citizen':
        return l10n.onboarding_residency_citizen;
      case 'Permanent Resident':
        return l10n.onboarding_residency_permanentResident;
      case 'Work Visa':
        return l10n.onboarding_residency_workVisa;
      case 'Student Visa':
        return l10n.onboarding_residency_studentVisa;
      case 'Other':
        return l10n.lang_other;
      case 'Prefer not to say':
        return l10n.onboarding_label_preferNotToSay;
    }
    return raw;
  }

  String _getLocalizedSpecialNeeds(AppLocalizations l10n, String raw) {
    switch (raw) {
      case 'None':
        return l10n.onboarding_specialNeeds_none;
      case 'Physical disability':
        return l10n.onboarding_specialNeeds_physical;
      case 'Hearing impairment':
        return l10n.onboarding_specialNeeds_hearing;
      case 'Visual impairment':
        return l10n.onboarding_specialNeeds_visual;
      case 'Other':
        return l10n.lang_other;
      case 'Prefer not to say':
        return l10n.onboarding_label_preferNotToSay;
    }
    return raw;
  }

  void _pickDob() async {
    _dismissKeyboard();
    final l10n = AppLocalizations.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.champagneGold,
              onPrimary: AppColors.obsidianNight,
              surface: AppColors.surfaceMid,
              onSurface: AppColors.pearlWhite,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    final age = _calcAge(picked);
    setState(() {
      _dob = picked;
      _dobError = age < 18
          ? _isGuardianMode
              ? l10n.onboarding_error_under18_guardian(
                  _getLocalizedRelation(l10n))
              : l10n.onboarding_error_under18_self
          : '';
    });
  }

  int _calcAge(DateTime dob) {
    final now = DateTime.now();
    int years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }

  String _formatDob(DateTime d) => '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
      '${d.year}';

  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  void _showMotherTonguePicker() {
    _dismissKeyboard();
    final l10n = AppLocalizations.of(context);
    if (_selectedCountryCode == null || _selectedCity == null) {
      showValidationSnackbar(context, ['City']);
      return;
    }
    if (_isLoadingLanguages || _loadedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UiText(
              context.uiCopy('Loading languages for the selected location...')),
        ),
      );
      return;
    }
    showSilarahBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceMid,
      isScrollControlled: true,
      // Keeps the full-height list clear of the status bar.
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GenericListPicker(
        title: l10n.onboarding_label_motherTongue,
        options: _loadedLanguages,
        selected: _motherTongue,
        onSelected: (v) {
          _dismissKeyboard();
          setState(() => _motherTongue = v);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showCommunityPicker() {
    _dismissKeyboard();
    final l10n = AppLocalizations.of(context);
    showSilarahBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceMid,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GenericListPicker(
        title: CopyEngine.communityQuestion(l10n, _creatorRelation),
        options: _loadedCommunities,
        selected: _community,
        onSelected: (v) {
          _dismissKeyboard();
          setState(() => _community = v);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _advance() async {
    _dismissKeyboard();
    final authCubit = context.read<AuthCubit>();
    final onboardingCubit = context.read<OnboardingCubit>();
    final data = onboardingCubit.currentData.copyWith(
      profileFor: _isGuardianMode ? ProfileFor.guardian : ProfileFor.myself,
      profileOwnerType:
          _isGuardianMode ? ProfileOwnerType.guardian : ProfileOwnerType.self,
      wardRelationship: _isGuardianMode ? _candidateLabel : null,
      wardGender: _isGuardianMode ? _gender : null,
      isGuardianMode: _isGuardianMode,
      guardianMode: 'none',
      guardianEmail: _isGuardianMode ? _guardianEmailCtrl.text.trim() : null,
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      dateOfBirth: _dob,
      gender: _gender,
      heightCm: _heightCm,
      complexion: _complexion,
      motherTongue: _motherTongue,
      community: _community,
      residencyStatus: _residencyStatus,
      specialNeeds: _specialNeeds,
    );

    // Gender & Country propagation
    // Persist gender before profile writes so DB triggers use the same value.
    if (_gender != null) {
      try {
        // public.users.gender is the DB source of truth. The profiles.gender
        // trigger reads from it, so this must finish before saveAndAdvance().
        await authCubit.setGender(_gender == Gender.female ? 'female' : 'male');
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: UiText(
                context.uiCopy('Could not save gender. Please try again.')),
          ),
        );
        return;
      }
    }

    // Save country code for regional pricing (subscription screen)
    if (mounted) {
      await onboardingCubit.saveAndAdvance(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localizedRelation = _getLocalizedRelation(l10n);
    return BlocConsumer<OnboardingCubit, OnboardingState>(
      listener: (context, state) => setState(() {
        _applyOnboardingData(context.read<OnboardingCubit>().currentData);
      }),
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          ctaLabel: l10n.legal_button_continue,
          onCta: _advance,
          isCtaEnabled: _canProceed,
          isCtaLoading: isLoading,
          onCtaDisabledTap: _showValidation,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),

              // Guardian mode banner
              if (_isGuardianMode) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimensions.space14),
                  decoration: BoxDecoration(
                    color: AppColors.champagneGold.withValues(alpha: 0.06),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(color: AppColors.goldBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          color: AppColors.champagneGold, size: 16),
                      const SizedBox(width: AppDimensions.space10),
                      Expanded(
                        child: UiText(
                          l10n.onboarding_basicIdentity_guardianBanner(
                              localizedRelation),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.champagneGold,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.space20),
              ],

              StepHeader(
                title: _isGuardianMode
                    ? _wardPhrase()
                    : l10n.onboarding_basicIdentity_title,
                subtitle: _isGuardianMode
                    ? 'These details describe the person you are registering, not you.'
                    : l10n.onboarding_basicIdentity_subtitle_self,
              ),
              const SizedBox(height: AppDimensions.space32),

              if (_isGuardianMode) ...[
                UiText(context.uiCopy('GUARDIAN CONTACT INFO'),
                    style: AppTypography.sectionLabel),
                const SizedBox(height: AppDimensions.space8),
                SilarahTextField(
                  controller: _guardianEmailCtrl,
                  label: 'Guardian email',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: Icons.email_outlined,
                  readOnly: true,
                ),
                const SizedBox(height: AppDimensions.space28),
              ],

              // Name row
              Row(
                key: _nameKey,
                children: [
                  Expanded(
                    child: SilarahTextField(
                      controller: _firstNameCtrl,
                      label: _isGuardianMode
                          ? l10n.onboarding_label_firstName_guardian
                          : l10n.onboarding_label_firstName_self,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: SilarahTextField(
                      controller: _lastNameCtrl,
                      label: l10n.onboarding_label_lastName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.space20),

              // Date of birth
              UiText(l10n.onboarding_label_dateOfBirth.toUpperCase(),
                  key: _dobKey, style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space8),
              GestureDetector(
                onTap: _pickDob,
                child: Container(
                  height: AppDimensions.buttonHeight,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppDimensions.space16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.inputSurface,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          color: AppColors.slateMist,
                          size: AppDimensions.iconSizeMedium),
                      const SizedBox(width: AppDimensions.space12),
                      Expanded(
                        child: UiText(
                          _dob != null
                              ? _formatDob(_dob!)
                              : l10n.onboarding_hint_selectDateOfBirth,
                          style: _dob != null
                              ? AppTypography.inputText
                              : AppTypography.inputText
                                  .copyWith(color: AppColors.slateMist),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_dobError.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.space8),
                UiText(_dobError,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.softCoral)),
              ],

              if (!_isGuardianMode) ...[
                const SizedBox(height: AppDimensions.space20),

                // Gender
                UiText(
                  l10n.onboarding_label_gender_self.toUpperCase(),
                  key: _genderKey,
                  style: AppTypography.sectionLabel,
                ),
                const SizedBox(height: AppDimensions.space8),
                Row(
                  children: [
                    Expanded(
                      child: _GenderPill(
                        label: l10n.onboarding_label_male,
                        icon: Icons.male_rounded,
                        isSelected: _gender == Gender.male,
                        onTap: () {
                          _dismissKeyboard();
                          setState(() => _gender = Gender.male);
                        },
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: _GenderPill(
                        label: l10n.onboarding_label_female,
                        icon: Icons.female_rounded,
                        isSelected: _gender == Gender.female,
                        onTap: () {
                          _dismissKeyboard();
                          setState(() => _gender = Gender.female);
                        },
                      ),
                    ),
                  ],
                ),
              ],

              // Location comes only from Quick Location; Basic Identity shows it read-only.
              const SizedBox(height: AppDimensions.space20),

              // Premium Confirmed Location Card
              if (_hasConfirmedLocation && _selectedCity != null) ...[
                const SizedBox(height: AppDimensions.space12),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.space16),
                  decoration: BoxDecoration(
                    color: AppColors.inputSurface,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(
                        color: AppColors.champagneGold.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.champagneGold.withValues(alpha: 0.05),
                        blurRadius: 16,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: AppColors.champagneGold, size: 18),
                          const SizedBox(width: AppDimensions.space8),
                          UiText(l10n.onboarding_location_confirmed,
                              style: AppTypography.captionMedium
                                  .copyWith(color: AppColors.champagneGold)),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.space16),
                      // City
                      Row(
                        children: [
                          Icon(Icons.location_city_rounded,
                              color: AppColors.slateMist, size: 18),
                          const SizedBox(width: AppDimensions.space12),
                          UiText(l10n.onboarding_label_city,
                              style: AppTypography.inputLabel),
                          const Spacer(),
                          UiText(_selectedCity!,
                              style: AppTypography.bodyMedium),
                        ],
                      ),
                      // State
                      if (_selectedStateName != null &&
                          _selectedStateName!.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child:
                              Divider(color: AppColors.cardBorder, height: 1),
                        ),
                        Row(
                          children: [
                            Icon(Icons.map_outlined,
                                color: AppColors.slateMist, size: 18),
                            const SizedBox(width: AppDimensions.space12),
                            UiText(l10n.onboarding_label_stateRegion,
                                style: AppTypography.inputLabel),
                            const Spacer(),
                            UiText(_selectedStateName!,
                                style: AppTypography.bodyMedium),
                          ],
                        ),
                      ],
                      // Country
                      if (_selectedCountryName != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child:
                              Divider(color: AppColors.cardBorder, height: 1),
                        ),
                        Row(
                          children: [
                            Icon(Icons.public,
                                color: AppColors.slateMist, size: 18),
                            const SizedBox(width: AppDimensions.space12),
                            UiText(
                                _isGuardianMode
                                    ? l10n.onboarding_label_country_guardian
                                    : l10n.onboarding_label_country_self,
                                style: AppTypography.inputLabel),
                            const Spacer(),
                            UiText(_selectedCountryName!,
                                style: AppTypography.bodyMedium),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: AppDimensions.space12),
                _MissingLocationCard(
                  countryName: _selectedCountryName,
                  onTap: () {
                    _dismissKeyboard();
                    context.read<OnboardingCubit>().goBack();
                  },
                ),
              ],

              const SizedBox(height: AppDimensions.space28),

              // HEIGHT
              UiText(
                  _isGuardianMode
                      ? l10n.onboarding_label_height_guardian.toUpperCase()
                      : l10n.onboarding_label_height_self.toUpperCase(),
                  style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              _HeightStepper(
                heightCm: _heightCm,
                onChanged: (v) {
                  _dismissKeyboard();
                  setState(() => _heightCm = v);
                },
              ),

              const SizedBox(height: AppDimensions.space24),

              // MOTHER TONGUE (Required)
              UiText(l10n.onboarding_label_motherTongue.toUpperCase(),
                  key: _motherTongueKey, style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              GestureDetector(
                onTap: _showMotherTonguePicker,
                child: Container(
                  height: AppDimensions.buttonHeight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.inputSurface,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(
                      color: _motherTongue != null
                          ? AppColors.champagneGold
                          : AppColors.cardBorder,
                      width: AppDimensions.borderThin,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.translate_rounded,
                          color: _motherTongue != null
                              ? AppColors.champagneGold
                              : AppColors.slateMist,
                          size: AppDimensions.iconSizeMedium),
                      const SizedBox(width: AppDimensions.space12),
                      Expanded(
                        child: UiText(
                          _motherTongue ?? l10n.onboarding_hint_selectLanguage,
                          style: AppTypography.inputText.copyWith(
                            color: _motherTongue != null
                                ? AppColors.pearlWhite
                                : AppColors.slateMist,
                          ),
                        ),
                      ),
                      Icon(Icons.expand_more_rounded,
                          color: AppColors.slateMist),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.space28),

              ExpansionTile(
                key: const PageStorageKey('identity-optional-details'),
                maintainState: true,
                initiallyExpanded: _community != null ||
                    _complexion != null ||
                    _residencyStatus != null ||
                    _specialNeeds != null,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 12, bottom: 12),
                collapsedIconColor: AppColors.slateMist,
                iconColor: AppColors.champagneGold,
                shape: Border(top: BorderSide(color: AppColors.cardBorder)),
                collapsedShape:
                    Border(top: BorderSide(color: AppColors.cardBorder)),
                title: UiText(l10n.guide_optional_details,
                    style: AppTypography.bodyMedium),
                subtitle: UiText(l10n.guide_optional_details_body,
                    style: AppTypography.caption),
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // COMMUNITY / BIRADARI (Optional)
                      Builder(builder: (ctx) {
                        final l10nBuild = AppLocalizations.of(ctx);
                        final rel = ctx
                                .read<OnboardingCubit>()
                                .currentData
                                .profileCreatorRelation ??
                            'self';
                        return UiText(
                            '${CopyEngine.communityQuestion(l10nBuild, rel).toUpperCase()}  (${l10nBuild.common_label_optional})',
                            style: AppTypography.sectionLabel);
                      }),
                      const SizedBox(height: AppDimensions.space12),
                      GestureDetector(
                        onTap: _showCommunityPicker,
                        child: Container(
                          height: AppDimensions.buttonHeight,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.space16),
                          decoration: BoxDecoration(
                            color: AppColors.inputSurface,
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusButton),
                            border: Border.all(
                              color: _community != null
                                  ? AppColors.champagneGold
                                  : AppColors.cardBorder,
                              width: AppDimensions.borderThin,
                            ),
                          ),
                          child: Row(children: [
                            Icon(Icons.groups_outlined,
                                color: _community != null
                                    ? AppColors.champagneGold
                                    : AppColors.slateMist,
                                size: AppDimensions.iconSizeMedium),
                            const SizedBox(width: AppDimensions.space12),
                            Expanded(
                                child: UiText(
                              _community ??
                                  l10n.onboarding_hint_selectCommunity,
                              style: AppTypography.inputText.copyWith(
                                color: _community != null
                                    ? AppColors.pearlWhite
                                    : AppColors.slateMist,
                              ),
                            )),
                            Icon(Icons.expand_more_rounded,
                                color: AppColors.slateMist),
                          ]),
                        ),
                      ),

                      const SizedBox(height: AppDimensions.space28),

                      // COMPLEXION (Optional)
                      UiText(l10n.onboarding_label_complexion.toUpperCase(),
                          style: AppTypography.sectionLabel),
                      const SizedBox(height: AppDimensions.space12),
                      Wrap(
                        spacing: AppDimensions.space8,
                        runSpacing: AppDimensions.space8,
                        children: _kComplexions
                            .map((o) => _SelectChip(
                                  label: _getLocalizedComplexion(l10n, o),
                                  isSelected: _complexion == o,
                                  onTap: () => setState(() => _complexion =
                                      _complexion == o ? null : o),
                                ))
                            .toList(),
                      ),

                      const SizedBox(height: AppDimensions.space24),

                      // RESIDENCY STATUS (Optional)
                      UiText(
                          l10n.onboarding_label_residencyStatus.toUpperCase(),
                          style: AppTypography.sectionLabel),
                      const SizedBox(height: AppDimensions.space12),
                      Wrap(
                        spacing: AppDimensions.space8,
                        runSpacing: AppDimensions.space8,
                        children: _kResidencyOptions
                            .map((o) => _SelectChip(
                                  label: _getLocalizedResidency(l10n, o),
                                  isSelected: _residencyStatus == o,
                                  onTap: () => setState(() => _residencyStatus =
                                      _residencyStatus == o ? null : o),
                                ))
                            .toList(),
                      ),

                      const SizedBox(height: AppDimensions.space28),

                      // SPECIAL NEEDS (Optional)
                      UiText(l10n.onboarding_label_specialNeeds.toUpperCase(),
                          style: AppTypography.sectionLabel),
                      const SizedBox(height: AppDimensions.space4),
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.space10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGlass,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusChip),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                color: AppColors.slateMist, size: 14),
                            const SizedBox(width: AppDimensions.space8),
                            Expanded(
                              child: UiText(
                                l10n.onboarding_specialNeeds_privacy,
                                style: AppTypography.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space12),
                      Wrap(
                        spacing: AppDimensions.space8,
                        runSpacing: AppDimensions.space8,
                        children: _kSpecialNeedsOptions
                            .map((o) => _SelectChip(
                                  label: _getLocalizedSpecialNeeds(l10n, o),
                                  isSelected: _specialNeeds == o,
                                  onTap: () => setState(() => _specialNeeds =
                                      _specialNeeds == o ? null : o),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.space32),
            ],
          ),
        );
      },
    );
  }
}

// Gender pill button
class _MissingLocationCard extends StatelessWidget {
  const _MissingLocationCard({
    required this.countryName,
    required this.onTap,
  });

  final String? countryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.softCoral.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.softCoral.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_off_outlined,
              color: AppColors.softCoral, size: 20),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(
                  context.uiCopy('Complete confirmed location'),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.pearlWhite,
                  ),
                ),
                const SizedBox(height: AppDimensions.space4),
                UiText(
                  countryName == null
                      ? 'Choose your country and city before continuing.'
                      : context.uiCopyWith(
                          'Choose a city in {country} before continuing.',
                          {'country': '$countryName'}),
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppDimensions.space10),
                GestureDetector(
                  onTap: onTap,
                  child: UiText(
                    context.uiCopy('Go to location step'),
                    style: AppTypography.captionMedium.copyWith(
                      color: AppColors.champagneGold,
                      decoration: TextDecoration.none,
                      decorationColor: AppColors.champagneGold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderPill extends StatelessWidget {
  const _GenderPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        height: AppDimensions.buttonHeight,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.1)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: AppDimensions.borderThin,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color:
                    isSelected ? AppColors.champagneGold : AppColors.slateMist,
                size: AppDimensions.iconSizeMedium),
            const SizedBox(width: AppDimensions.space8),
            UiText(label,
                style: AppTypography.bodyMedium.copyWith(
                  color: isSelected
                      ? AppColors.champagneGold
                      : AppColors.pearlWhite,
                )),
          ],
        ),
      ),
    );
  }
}

// Height Stepper
class _HeightStepper extends StatelessWidget {
  const _HeightStepper({
    required this.heightCm,
    required this.onChanged,
  });
  final int heightCm;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space12,
      ),
      decoration: BoxDecoration(
        color: AppColors.inputSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          // Minus button
          _StepperButton(
            icon: Icons.remove_rounded,
            onTap: heightCm > 140 ? () => onChanged(heightCm - 1) : null,
          ),
          const SizedBox(width: AppDimensions.space12),

          // Height display
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UiText(
                  '$heightCm cm',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.champagneGold,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                UiText(
                  _feetInchDisplay(context, heightCm),
                  style: AppTypography.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(width: AppDimensions.space12),
          // Plus button
          _StepperButton(
            icon: Icons.add_rounded,
            onTap: heightCm < 210 ? () => onChanged(heightCm + 1) : null,
          ),
        ],
      ),
    );
  }

  String _feetInchDisplay(BuildContext context, int cm) {
    final totalInches = cm / 2.54;
    final feet = totalInches ~/ 12;
    final inches = totalInches.round() % 12;
    return context.uiHeightImperial(feet, inches);
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              FocusManager.instance.primaryFocus?.unfocus();
              onTap!();
            },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.champagneGold.withValues(alpha: 0.12)
              : AppColors.surfaceGlassHover,
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? AppColors.goldBorder : AppColors.cardBorder,
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.champagneGold : AppColors.slateMist,
          size: 20,
        ),
      ),
    );
  }
}

// Select Chip
class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.12)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: AppDimensions.borderThin,
          ),
        ),
        child: UiText(
          label,
          style: AppTypography.chipLabel.copyWith(
            color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
          ),
        ),
      ),
    );
  }
}

// Generic List Picker sheet (replaces _MotherTonguePicker)
// Used for both Mother Tongue and Community pickers.
// Accepts any List<String> as options.

class _GenericListPicker extends StatefulWidget {
  const _GenericListPicker({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
  });
  final String title;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  State<_GenericListPicker> createState() => _GenericListPickerState();
}

class _GenericListPickerState extends State<_GenericListPicker> {
  final _searchCtrl = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.options);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      _filtered = lower.isEmpty
          ? List.from(widget.options)
          : widget.options
              .where((l) => l.toLowerCase().contains(lower))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppDimensions.space16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slateMist.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppDimensions.space16),
            UiText(widget.title, style: AppTypography.bodyMedium),
            const SizedBox(height: AppDimensions.space12),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                style: AppTypography.inputText,
                decoration: InputDecoration(
                  hintText: context.uiCopy('Search…'),
                  hintStyle: AppTypography.inputLabel,
                  prefixIcon: Icon(Icons.search_rounded,
                      color: AppColors.slateMist, size: 20),
                  filled: true,
                  fillColor: AppColors.inputSurface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space12,
                      vertical: AppDimensions.space10),
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusButton),
                      borderSide: BorderSide(color: AppColors.cardBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusButton),
                      borderSide: BorderSide(color: AppColors.cardBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusButton),
                      borderSide: BorderSide(
                          color: AppColors.champagneGold,
                          width: AppDimensions.borderThin)),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
            Flexible(
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppDimensions.space24),
                      child: UiText(context.uiCopy('Nothing found.'),
                          style: AppTypography.bodyMuted,
                          textAlign: TextAlign.center),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final item = _filtered[i];
                        final isSel = item == widget.selected;
                        return ListTile(
                          title: UiText(item, style: AppTypography.body),
                          trailing: isSel
                              ? Icon(Icons.check_rounded,
                                  color: AppColors.champagneGold, size: 20)
                              : null,
                          selected: isSel,
                          selectedColor: AppColors.champagneGold,
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            widget.onSelected(item);
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: AppDimensions.space16),
          ],
        ),
      ),
    );
  }
}
