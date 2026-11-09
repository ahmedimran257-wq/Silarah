// SILARAH — Edit Profile Screen
//
// Full editable profile with sections matching OnboardingData:
//   Photos · Basic Info · Islamic Identity · About
//   Education & Career · Family · Partner Preferences
//
// Reads current values from OnboardingCubit.
// Save triggers OnboardingCubit.saveAndAdvance and shows
// a success SnackBar before popping.
import 'package:silarah/l10n/ui_copy.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/discovery/discovery_feed_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/data/country_data.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/services/country_context_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/profile_photo_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/country_picker_screen.dart';
import '../../../core/widgets/inputs/city_search_field.dart';
import '../../../core/widgets/inputs/region_search_field.dart';
import '../../../core/widgets/inputs/silarah_field_frame.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../onboarding/screens/photo_upload_screen.dart';

// City data import — reuse same list from basic_identity_screen
// (Inline minimal wrapper to avoid cross-file private access)

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Local mutable copies of OnboardingData fields
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _professionCtrl;
  late TextEditingController _bioCtrl;

  late CountryInfo _country;
  RegionResult? _region;
  CityResult? _selectedCity;
  String? _initialRegion;
  String? _initialCity;
  bool _locationChanged = false;

  // Islamic
  Sect? _sect;
  DeenLevel? _deenLevel;
  bool _praysFive = false;
  String? _hijabStyle;
  String? _beardStyle; // 'yes','no','prefer_not_to_say'

  // Education & career
  String? _educationLabel;

  // Family
  FamilyType? _familyType;
  int _siblingCount = 0;
  String? _parentsStatus;
  String? _marriageTimeline;
  String? _willingToRelocate;

  // Partner preferences
  double _partnerAgeMin = 22;
  double _partnerAgeMax = 35;
  bool _openToDivorced = false;
  bool _openToWidowed = false;
  bool _openToHasChildren = false;
  bool _openToDiaspora = false;

  // About
  List<String> _interests = [];

  Gender? _gender;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = context.read<OnboardingCubit>().currentData;
    _firstNameCtrl = TextEditingController(text: d.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: d.lastName ?? '');
    _professionCtrl = TextEditingController(text: d.profession ?? '');
    _bioCtrl = TextEditingController(text: d.bio ?? '');

    final countryMatches = kAllCountries.where(
      (country) =>
          country.iso2.toUpperCase() == d.countryCode?.trim().toUpperCase(),
    );
    _country = countryMatches.isEmpty ? deviceCountry() : countryMatches.first;
    final savedRegion = d.stateName?.trim().isNotEmpty == true
        ? d.stateName!.trim()
        : _stateFromCityName(d.cityName);
    _initialRegion = savedRegion;
    if (savedRegion != null) {
      _region = RegionResult(
        id: '',
        name: savedRegion,
        countryCode: _country.iso2,
        country: _country.name,
      );
    }
    _initialCity = d.cityName;
    if (d.cityName?.trim().isNotEmpty == true &&
        d.lat != null &&
        d.lng != null) {
      final cityName = d.cityName!.split(',').first.trim();
      _selectedCity = CityResult(
        city: cityName,
        state: savedRegion ?? '',
        country: _country.name,
        countryCode: _country.iso2,
        postalCode: d.postalCode ?? '',
        fullAddress: [
          cityName,
          if (savedRegion != null) savedRegion,
          _country.name,
        ].join(', '),
        placeId: d.cityId ?? '',
        lat: d.lat!,
        lng: d.lng!,
      );
    }

    _sect = d.sect;
    _deenLevel = d.deenLevel;
    _praysFive = d.praysFiveDaily ?? false;
    _hijabStyle = d.hijabStyle;
    _beardStyle = d.beardStyle;
    _educationLabel = d.educationLabel;
    _familyType = d.familyType;
    _siblingCount = d.siblingCount ?? 0;
    _parentsStatus = d.parentsStatus;
    _marriageTimeline = d.marriageTimeline;
    _willingToRelocate = d.willingToRelocate;
    _partnerAgeMin = (d.preferredAgeMin ?? 22).toDouble();
    _partnerAgeMax = (d.preferredAgeMax ?? 35).toDouble();
    _openToDivorced = d.openToDivorced ?? false;
    _openToWidowed = d.openToWidowed ?? false;
    _openToHasChildren = d.openToWithChildren ?? false;
    _openToDiaspora = d.openToDiaspora ?? false;
    _interests = List<String>.from(d.interests ?? []);
    _gender = d.gender;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _professionCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  String? _stateFromCityName(String? cityName) {
    final parts = cityName?.split(',') ?? const <String>[];
    if (parts.length < 2) return null;
    final state = parts[1].trim();
    return state.isEmpty ? null : state;
  }

  void _selectCountry(CountryInfo country) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (country.iso2 == _country.iso2) return;
    setState(() {
      _country = country;
      _region = null;
      _selectedCity = null;
      _initialRegion = null;
      _initialCity = null;
      _locationChanged = true;
    });
  }

  void _selectRegion(RegionResult region) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _region = region;
      _selectedCity = null;
      _initialRegion = null;
      _initialCity = null;
      _locationChanged = true;
    });
  }

  void _selectCity(CityResult city) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedCity = city;
      _initialCity = null;
      _locationChanged = true;
    });
  }

  void _clearCity() {
    setState(() {
      _selectedCity = null;
      _initialCity = null;
      _locationChanged = true;
    });
  }

  void _showSaveError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: UiText(
          message,
          style: AppTypography.body.copyWith(
            color: AppColors.readableOn(AppColors.softCoral),
          ),
        ),
        backgroundColor: AppColors.softCoral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      _showSaveError('First and last name are required.');
      return;
    }
    if (_locationChanged && _selectedCity == null) {
      _showSaveError('Select a city from the verified search results.');
      return;
    }
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    String? resolvedCityId;
    if (_locationChanged) {
      final resolution = await LocationService.resolveCity(_selectedCity!);
      if (!mounted) return;
      if (!resolution.isSuccess) {
        setState(() => _isSaving = false);
        _showSaveError(
          resolution.errorMessage ??
              'We could not verify that city. Please select it again.',
        );
        return;
      }
      resolvedCityId = resolution.cityId;
    }

    final cubit = context.read<OnboardingCubit>();
    var updated = cubit.currentData.copyWith(
      firstName: firstName,
      lastName: lastName,
      profession: _professionCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      sect: _sect,
      deenLevel: _deenLevel,
      praysFiveDaily: _praysFive,
      hijabStyle: _hijabStyle,
      beardStyle: _beardStyle,
      educationLabel: _educationLabel,
      familyType: _familyType,
      siblingCount: _siblingCount,
      parentsStatus: _parentsStatus,
      marriageTimeline: _marriageTimeline,
      willingToRelocate: _willingToRelocate,
      preferredAgeMin: _partnerAgeMin.round(),
      preferredAgeMax: _partnerAgeMax.round(),
      openToDivorced: _openToDivorced,
      openToWidowed: _openToWidowed,
      openToWithChildren: _openToHasChildren,
      openToDiaspora: _openToDiaspora,
      interests: _interests,
    );
    if (_locationChanged) {
      final city = _selectedCity!;
      final stateName = city.state.trim().isNotEmpty
          ? city.state.trim()
          : _region?.name.trim() ?? '';
      final displayCity = stateName.isEmpty
          ? city.city.trim()
          : '${city.city.trim()}, $stateName';
      updated = updated.copyWith(
        cityId: resolvedCityId,
        cityName: displayCity,
        stateName: stateName,
        countryCode: _country.iso2,
        postalCode: city.postalCode,
        lat: city.lat,
        lng: city.lng,
      );
    }

    final saved = await cubit.updateProfile(
      updated,
      locationChanged: _locationChanged,
    );
    if (!mounted) return;
    if (!saved) {
      setState(() => _isSaving = false);
      _showSaveError('Could not save profile. Please try again.');
      return;
    }

    if (_locationChanged) {
      await context.read<AuthCubit>().setCountryCode(_country.iso2);
      if (!mounted) return;
      final discovery = context.read<DiscoveryFeedCubit>();
      discovery.clear();
      unawaited(discovery.loadInitial(force: true));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle_rounded,
              color: AppColors.champagneGold, size: 18),
          const SizedBox(width: AppDimensions.space8),
          UiText(
            context.uiCopy('Profile saved'),
            style: AppTypography.body.copyWith(
              color: AppColors.readableOn(AppColors.surfaceGlassHover),
            ),
          ),
        ]),
        backgroundColor: AppColors.surfaceGlassHover,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          side: BorderSide(color: AppColors.goldBorder),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
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
            title: UiText(context.uiCopy('Edit Profile'),
                style: AppTypography.screenTitle.copyWith(fontSize: 20)),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
              decoration: BoxDecoration(
                color: AppColors.navBarSurface,
                border: Border(top: BorderSide(color: AppColors.cardBorder)),
              ),
              child: SilarahPressable(
                onTap: _isSaving ? null : _saveProfile,
                semanticLabel: context.uiCopy('Save profile changes'),
                child: AnimatedContainer(
                  duration: AppDimensions.durationTransition,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: _isSaving
                        ? null
                        : LinearGradient(colors: [
                            AppColors.champagneLight,
                            AppColors.champagneGold,
                          ]),
                    color: _isSaving ? AppColors.surfaceGlassHover : null,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                  child: _isSaving
                      ? const SilarahPulseLoader(size: 26)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded,
                                color: AppColors.obsidianNight, size: 20),
                            const SizedBox(width: AppDimensions.space8),
                            UiText(context.uiCopy('Save changes'),
                                style: AppTypography.button),
                          ],
                        ),
                ),
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.space24,
              AppDimensions.space8,
              AppDimensions.space24,
              AppDimensions.space40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _EditorIntro(),
                const SizedBox(height: AppDimensions.space24),
                // Photos
                const _SectionHeader(label: 'Photos'),
                const SizedBox(height: AppDimensions.space12),
                _PhotoGrid(
                  onTap: () async {
                    final onboardingCubit = context.read<OnboardingCubit>();
                    final saved = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => const PhotoUploadScreen(
                          returnToPreviousOnSave: true,
                        ),
                      ),
                    );
                    if (saved == true && mounted) {
                      await onboardingCubit.refreshProfileFromDb(force: true);
                      setState(() {});
                    }
                  },
                ),
                const SizedBox(height: AppDimensions.space28),

                // Basic Info
                const _SectionHeader(label: 'Basic Info'),
                const SizedBox(height: AppDimensions.space12),
                _SilarahTextField(
                  label: 'First name',
                  controller: _firstNameCtrl,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppDimensions.space12),
                _SilarahTextField(
                  label: 'Last name',
                  controller: _lastNameCtrl,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppDimensions.space24),
                _LocationEditor(
                  country: _country,
                  region: _region,
                  selectedCity: _selectedCity,
                  initialRegion: _initialRegion,
                  initialCity: _initialCity,
                  onCountryTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CountryPickerScreen(
                          selected: _country,
                          onSelected: _selectCountry,
                        ),
                      ),
                    );
                  },
                  onRegionSelected: _selectRegion,
                  onRegionCleared: () => setState(() {
                    _region = null;
                    _initialRegion = null;
                    _selectedCity = null;
                    _initialCity = null;
                    _locationChanged = true;
                  }),
                  onCitySelected: _selectCity,
                  onCityCleared: _clearCity,
                ),
                const SizedBox(height: AppDimensions.space28),

                // Islamic Identity
                const _SectionHeader(label: 'Islamic Identity'),
                const SizedBox(height: AppDimensions.space12),
                _DropdownField(
                  label: 'Sect',
                  value: _sectValue(_sect),
                  options: const ['sunni', 'shia', 'preferNotToSay', 'other'],
                  optionLabels: const [
                    'Sunni',
                    'Shia',
                    'Prefer not to say',
                    'Other'
                  ],
                  onChanged: (v) => setState(() => _sect = _parseSect(v)),
                ),
                const SizedBox(height: AppDimensions.space12),
                _DropdownField(
                  label: 'Deen Level',
                  value: _deenLevelValue(_deenLevel),
                  options: const ['practicing', 'moderate', 'cultural'],
                  optionLabels: const [
                    'Practicing',
                    'Moderate',
                    'Cultural Muslim'
                  ],
                  onChanged: (v) =>
                      setState(() => _deenLevel = _parseDeenLevel(v)),
                ),
                const SizedBox(height: AppDimensions.space12),
                _ToggleRow(
                  label: 'Prays five times daily',
                  value: _praysFive,
                  onChanged: (v) => setState(() => _praysFive = v),
                ),
                // Female-only: hijab dropdown
                if (_gender == Gender.female) ...[
                  const SizedBox(height: AppDimensions.space12),
                  _DropdownField(
                    label: 'Hijab style',
                    value: _hijabStyle ?? 'No hijab',
                    options: const [
                      'No hijab',
                      'Occasionally',
                      'Hijab',
                      'Niqab',
                    ],
                    onChanged: (v) => setState(() => _hijabStyle = v),
                  ),
                ],
                // Male-only: beard toggle
                if (_gender == Gender.male) ...[
                  const SizedBox(height: AppDimensions.space12),
                  _DropdownField(
                    label: 'Beard',
                    value: _beardStyle ?? 'prefer_not_to_say',
                    options: const ['yes', 'no', 'prefer_not_to_say'],
                    optionLabels: const ['Yes', 'No', 'Prefer not to say'],
                    onChanged: (v) => setState(() => _beardStyle = v),
                  ),
                ],
                const SizedBox(height: AppDimensions.space28),

                // About
                const _SectionHeader(label: 'About'),
                const SizedBox(height: AppDimensions.space12),
                _SilarahTextField(
                  label: 'Bio',
                  hint: 'Describe yourself with honesty and dignity.',
                  controller: _bioCtrl,
                  maxLines: 5,
                  maxLength: 300,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppDimensions.space12),
                _InterestChips(
                  selected: _interests,
                  onChanged: (v) => setState(() => _interests = v),
                ),
                const SizedBox(height: AppDimensions.space28),

                // Education & Career
                const _SectionHeader(label: 'Education & Career'),
                const SizedBox(height: AppDimensions.space12),
                _DropdownField(
                  label: 'Education Level',
                  value: _educationLabel ?? 'Bachelor\'s Degree',
                  options: const [
                    'Below Secondary',
                    'Secondary / O-Level',
                    'Higher Secondary / A-Level',
                    'Diploma / Associate',
                    'Bachelor\'s Degree',
                    'Master\'s Degree',
                    'Doctorate / PhD',
                  ],
                  onChanged: (v) => setState(() => _educationLabel = v),
                ),
                const SizedBox(height: AppDimensions.space12),
                _SilarahTextField(
                  label: 'Profession',
                  hint: 'e.g. Software Engineer',
                  controller: _professionCtrl,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppDimensions.space28),

                // Family
                const _SectionHeader(label: 'Family'),
                const SizedBox(height: AppDimensions.space12),
                _DropdownField(
                  label: 'Family Type',
                  value: _familyTypeValue(_familyType),
                  options: const ['nuclear', 'joint', 'extended'],
                  optionLabels: const ['Nuclear', 'Joint', 'Extended'],
                  onChanged: (v) =>
                      setState(() => _familyType = _parseFamilyType(v)),
                ),
                const SizedBox(height: AppDimensions.space12),
                _StepperRow(
                  label: 'Siblings',
                  value: _siblingCount,
                  min: 0,
                  max: 15,
                  onChanged: (v) => setState(() => _siblingCount = v),
                ),
                const SizedBox(height: AppDimensions.space12),
                _DropdownField(
                  label: 'Parents\' Status',
                  value: _parentsStatus ?? 'Both alive',
                  options: const [
                    'Both alive',
                    'Father passed away',
                    'Mother passed away',
                    'Both passed away',
                  ],
                  onChanged: (v) => setState(() => _parentsStatus = v),
                ),
                const SizedBox(height: AppDimensions.space12),
                _DropdownField(
                  label: 'Marriage Timeline',
                  value: _marriageTimeline ?? 'not_sure',
                  options: const [
                    'asap',
                    '6_months',
                    '1_year',
                    '2_plus_years',
                    'not_sure'
                  ],
                  optionLabels: const [
                    'ASAP',
                    '6 Months',
                    '1 Year',
                    '2+ Years',
                    'Not Sure'
                  ],
                  onChanged: (v) => setState(() => _marriageTimeline = v),
                ),
                const SizedBox(height: AppDimensions.space12),
                _DropdownField(
                  label: 'Willing to Relocate',
                  value: _willingToRelocate ?? 'open_to_discussion',
                  options: const ['yes', 'no', 'open_to_discussion'],
                  optionLabels: const ['Yes', 'No', 'Open to Discussion'],
                  onChanged: (v) => setState(() => _willingToRelocate = v),
                ),
                const SizedBox(height: AppDimensions.space28),

                // Partner Preferences
                const _SectionHeader(label: 'Partner Preferences'),
                const SizedBox(height: AppDimensions.space12),
                _AgeRangeField(
                  min: _partnerAgeMin,
                  max: _partnerAgeMax,
                  onChanged: (lo, hi) => setState(() {
                    _partnerAgeMin = lo;
                    _partnerAgeMax = hi;
                  }),
                ),
                const SizedBox(height: AppDimensions.space12),
                _ToggleRow(
                  label: 'Open to divorced',
                  value: _openToDivorced,
                  onChanged: (v) => setState(() => _openToDivorced = v),
                ),
                const SizedBox(height: AppDimensions.space12),
                _ToggleRow(
                  label: 'Open to widowed',
                  value: _openToWidowed,
                  onChanged: (v) => setState(() => _openToWidowed = v),
                ),
                const SizedBox(height: AppDimensions.space12),
                _ToggleRow(
                  label: 'Open to someone with children',
                  value: _openToHasChildren,
                  onChanged: (v) => setState(() => _openToHasChildren = v),
                ),
                const SizedBox(height: AppDimensions.space12),
                _ToggleRow(
                  label: 'Open to members living abroad',
                  value: _openToDiaspora,
                  onChanged: (v) => setState(() => _openToDiaspora = v),
                ),

                const SizedBox(height: AppDimensions.space40),
              ],
            ),
          ),
        );
      },
    );
  }

  // Enum helpers
  String _sectValue(Sect? s) {
    switch (s) {
      case Sect.sunni:
        return 'sunni';
      case Sect.shia:
        return 'shia';
      case Sect.preferNotToSay:
        return 'preferNotToSay';
      case Sect.other:
        return 'other';
      case null:
        return 'sunni';
    }
  }

  Sect _parseSect(String? v) {
    switch (v) {
      case 'shia':
        return Sect.shia;
      case 'preferNotToSay':
        return Sect.preferNotToSay;
      case 'other':
        return Sect.other;
      default:
        return Sect.sunni;
    }
  }

  String _deenLevelValue(DeenLevel? d) {
    switch (d) {
      case DeenLevel.moderate:
        return 'moderate';
      case DeenLevel.cultural:
        return 'cultural';
      default:
        return 'practicing';
    }
  }

  DeenLevel _parseDeenLevel(String? v) {
    switch (v) {
      case 'moderate':
        return DeenLevel.moderate;
      case 'cultural':
        return DeenLevel.cultural;
      default:
        return DeenLevel.practicing;
    }
  }

  String _familyTypeValue(FamilyType? f) {
    switch (f) {
      case FamilyType.joint:
        return 'joint';
      case FamilyType.extended:
        return 'extended';
      default:
        return 'nuclear';
    }
  }

  FamilyType _parseFamilyType(String? v) {
    switch (v) {
      case 'joint':
        return FamilyType.joint;
      case 'extended':
        return FamilyType.extended;
      default:
        return FamilyType.nuclear;
    }
  }
}

// Photo Grid (4-slot)
class _PhotoGrid extends StatefulWidget {
  const _PhotoGrid({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<_PhotoGrid> {
  late final Future<String?> _primaryPhoto =
      ProfilePhotoService.instance.getPrimaryPhotoUrl();

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.space12),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          children: [
            FutureBuilder<String?>(
              future: _primaryPhoto,
              builder: (context, snapshot) => ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                child: Container(
                  width: 92,
                  height: 116,
                  color: AppColors.surfaceGlassHover,
                  child: snapshot.data != null
                      ? CachedNetworkImage(
                          imageUrl: snapshot.data!,
                          fit: BoxFit.cover,
                          memCacheWidth: 276,
                          maxWidthDiskCache: 384,
                        )
                      : Icon(Icons.add_a_photo_outlined,
                          color: AppColors.champagneGold, size: 30),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText(context.uiCopy('Manage your photos'),
                      style: AppTypography.bodyMedium),
                  const SizedBox(height: AppDimensions.space6),
                  UiText(
                    context.uiCopy(
                        'Reorder, replace or add photos. Every new upload runs through the safety scan.'),
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  Row(
                    children: [
                      UiText(context.uiCopy('Open photo manager'),
                          style: AppTypography.buttonSecondary),
                      const SizedBox(width: AppDimensions.space4),
                      Icon(Icons.arrow_forward_rounded,
                          color: AppColors.champagneGold, size: 17),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Section Header
class _EditorIntro extends StatelessWidget {
  const _EditorIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.midnightPlum.withValues(alpha: 0.34),
            AppColors.champagneGold.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_outlined,
              color: AppColors.champagneGold, size: 22),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(context.uiCopy('Shape your first impression'),
                    style: AppTypography.bodyMedium),
                const SizedBox(height: AppDimensions.space4),
                UiText(
                  context.uiCopy(
                      'Changes are saved securely and reflected in discovery immediately.'),
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationEditor extends StatelessWidget {
  const _LocationEditor({
    required this.country,
    required this.region,
    required this.selectedCity,
    required this.initialRegion,
    required this.initialCity,
    required this.onCountryTap,
    required this.onRegionSelected,
    required this.onRegionCleared,
    required this.onCitySelected,
    required this.onCityCleared,
  });

  final CountryInfo country;
  final RegionResult? region;
  final CityResult? selectedCity;
  final String? initialRegion;
  final String? initialCity;
  final VoidCallback onCountryTap;
  final ValueChanged<RegionResult> onRegionSelected;
  final VoidCallback onRegionCleared;
  final ValueChanged<CityResult> onCitySelected;
  final VoidCallback onCityCleared;

  @override
  Widget build(BuildContext context) {
    final city = selectedCity;
    final locationLabel = city == null
        ? null
        : [
            city.city,
            if (city.state.trim().isNotEmpty) city.state.trim(),
            country.name,
          ].join(', ');

    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.goldGlow,
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: AppColors.champagneGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppDimensions.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UiText(
                      context.uiCopy('Discovery location'),
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.pearlWhite,
                      ),
                    ),
                    const SizedBox(height: 3),
                    UiText(
                      context.uiCopy(
                          'Used for nearby matches. Your exact address is never shown.'),
                      style: AppTypography.caption.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space20),
          UiText(context.uiCopy('COUNTRY'), style: AppTypography.sectionLabel),
          const SizedBox(height: AppDimensions.space8),
          Semantics(
            button: true,
            label: context.uiChangeCountry(country.name),
            child: InkWell(
              onTap: onCountryTap,
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    UiText(country.flag, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: UiText(country.name, style: AppTypography.body),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.champagneGold,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: AppDimensions.space24),
          UiText(context.uiCopy('STATE / REGION'),
              style: AppTypography.sectionLabel),
          const SizedBox(height: AppDimensions.space8),
          RegionSearchField(
            key: ValueKey('edit_region_${country.iso2}'),
            countryCode: country.iso2,
            initialValue: initialRegion,
            hint: 'Optional — narrow city results',
            onSelected: onRegionSelected,
            onCleared: onRegionCleared,
          ),
          const SizedBox(height: AppDimensions.space16),
          UiText(context.uiCopy('CITY'), style: AppTypography.sectionLabel),
          const SizedBox(height: AppDimensions.space8),
          CitySearchField(
            key: ValueKey('edit_city_${country.iso2}_${region?.name ?? ''}'),
            countryCode: country.iso2,
            regionName: region?.name,
            initialValue: initialCity,
            hint: region == null
                ? 'Search your city or area'
                : context.uiCopyWith(
                    'Search city in {region}', {'region': region!.name}),
            onSelected: onCitySelected,
            onCleared: onCityCleared,
          ),
          AnimatedSwitcher(
            duration: AppDimensions.durationTransition,
            child: locationLabel == null
                ? Padding(
                    key: const ValueKey('location-guidance'),
                    padding: const EdgeInsets.only(top: AppDimensions.space10),
                    child: UiText(
                      context.uiCopy(
                          'Choose a verified result so distance matching stays accurate.'),
                      style: AppTypography.caption,
                    ),
                  )
                : Padding(
                    key: ValueKey(locationLabel),
                    padding: const EdgeInsets.only(top: AppDimensions.space12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: AppColors.verifiedTeal,
                          size: 17,
                        ),
                        const SizedBox(width: AppDimensions.space8),
                        Expanded(
                          child: UiText(
                            context.uiCopyWith('Matching from {location}',
                                {'location': locationLabel}),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.verifiedTeal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final icon = switch (label) {
      'Photos' => Icons.photo_library_outlined,
      'Basic Info' => Icons.person_outline_rounded,
      'Islamic Identity' => Icons.mosque_outlined,
      'About' => Icons.format_quote_rounded,
      'Education & Career' => Icons.school_outlined,
      'Family' => Icons.family_restroom_rounded,
      _ => Icons.favorite_border_rounded,
    };
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.champagneGold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: AppColors.champagneGold, size: 18),
        ),
        const SizedBox(width: AppDimensions.space10),
        UiText(label, style: AppTypography.bodyMedium),
        const SizedBox(width: AppDimensions.space12),
        Expanded(child: Divider(color: AppColors.divider, height: 1)),
      ],
    );
  }
}

// SILARAH Text Field
class _SilarahTextField extends StatefulWidget {
  const _SilarahTextField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String> onChanged;

  @override
  State<_SilarahTextField> createState() => _SilarahTextFieldState();
}

class _SilarahTextFieldState extends State<_SilarahTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiText(widget.label, style: AppTypography.inputLabel),
        const SizedBox(height: AppDimensions.space6),
        Focus(
          onFocusChange: (f) => setState(() => _focused = f),
          child: SilarahFieldFrame(
            focused: _focused,
            minHeight: widget.maxLines > 1
                ? AppDimensions.inputHeight + AppDimensions.space40
                : AppDimensions.inputHeight,
            child: TextField(
              controller: widget.controller,
              maxLines: widget.maxLines,
              maxLength: widget.maxLength,
              style: AppTypography.inputText,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppTypography.inputLabel,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space16,
                  vertical: AppDimensions.space16,
                ),
                counterStyle: AppTypography.caption,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Dropdown Field
class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    this.optionLabels,
    required this.onChanged,
  });
  final String label;
  final String value;
  final List<String> options;
  final List<String>? optionLabels;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = options.contains(value) ? value : options.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiText(label, style: AppTypography.inputLabel),
        const SizedBox(height: AppDimensions.space6),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16,
            vertical: AppDimensions.space2,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: safeValue,
            style: AppTypography.inputText,
            dropdownColor: AppColors.surfaceElevated,
            isExpanded: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: false,
              fillColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
            ),
            icon: Icon(
              Icons.expand_more_rounded,
              color: AppColors.slateMist,
            ),
            items: List.generate(options.length, (i) {
              final val = options[i];
              final lbl = optionLabels?[i] ?? val;
              return DropdownMenuItem(
                value: val,
                child: UiText(
                  lbl,
                  style: AppTypography.body,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// Toggle Row
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(child: UiText(label, style: AppTypography.body)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.champagneGold,
            activeTrackColor: AppColors.champagneGold.withValues(alpha: 0.3),
            inactiveThumbColor: AppColors.slateMist,
            inactiveTrackColor: AppColors.surfaceGlassHover,
          ),
        ],
      ),
    );
  }
}

// Stepper Row
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(child: UiText(label, style: AppTypography.body)),
          GestureDetector(
            onTap: value > min ? () => onChanged(value - 1) : null,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: value > min
                    ? AppColors.champagneGold.withValues(alpha: 0.15)
                    : AppColors.surfaceGlassHover,
                shape: BoxShape.circle,
                border: Border.all(
                  color: value > min
                      ? AppColors.champagneGold.withValues(alpha: 0.5)
                      : AppColors.cardBorder,
                ),
              ),
              child: Icon(Icons.remove,
                  size: 16,
                  color: value > min
                      ? AppColors.champagneGold
                      : AppColors.slateMist),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppDimensions.space12),
            child: UiText(
              '$value',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.pearlWhite,
                fontSize: 16,
              ),
            ),
          ),
          GestureDetector(
            onTap: value < max ? () => onChanged(value + 1) : null,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: value < max
                    ? AppColors.champagneGold.withValues(alpha: 0.15)
                    : AppColors.surfaceGlassHover,
                shape: BoxShape.circle,
                border: Border.all(
                  color: value < max
                      ? AppColors.champagneGold.withValues(alpha: 0.5)
                      : AppColors.cardBorder,
                ),
              ),
              child: Icon(Icons.add,
                  size: 16,
                  color: value < max
                      ? AppColors.champagneGold
                      : AppColors.slateMist),
            ),
          ),
        ],
      ),
    );
  }
}

// Age Range Slider
class _AgeRangeField extends StatelessWidget {
  const _AgeRangeField({
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final double min;
  final double max;
  final void Function(double lo, double hi) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.space16,
        AppDimensions.space12,
        AppDimensions.space16,
        AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UiText(context.uiCopy('Partner age range'),
                  style: AppTypography.body),
              const Spacer(),
              UiText(
                context.uiAgeRange(min.round(), max.round()),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.champagneGold,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.champagneGold,
              inactiveTrackColor: AppColors.progressBarBase,
              thumbColor: AppColors.champagneGold,
              overlayColor: AppColors.champagneGold.withValues(alpha: 0.15),
              rangeThumbShape:
                  const RoundRangeSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: RangeSlider(
              values: RangeValues(min, max),
              min: 18,
              max: 60,
              divisions: 42,
              onChanged: (rv) => onChanged(rv.start, rv.end),
            ),
          ),
        ],
      ),
    );
  }
}

// Interest Chips
const _kAllInterests = <String>[
  'Reading',
  'Travel',
  'Cooking',
  'Fitness',
  'Photography',
  'Technology',
  'Art',
  'Music',
  'Hiking',
  'Languages',
  'Calligraphy',
  'Poetry',
  'Finance',
  'Medicine',
  'Education',
  'Design',
  'Architecture',
  'Yoga',
  'Running',
  'Gaming',
];

class _InterestChips extends StatelessWidget {
  const _InterestChips({
    required this.selected,
    required this.onChanged,
  });
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiText(context.uiCopy('Interests (up to 6)'),
            style: AppTypography.sectionLabel),
        const SizedBox(height: AppDimensions.space8),
        Wrap(
          spacing: AppDimensions.space8,
          runSpacing: AppDimensions.space8,
          children: _kAllInterests.map((interest) {
            final isOn = selected.contains(interest);
            return GestureDetector(
              onTap: () {
                final next = List<String>.from(selected);
                if (isOn) {
                  next.remove(interest);
                } else {
                  if (next.length >= 6) return;
                  next.add(interest);
                }
                onChanged(next);
              },
              child: AnimatedContainer(
                duration: AppDimensions.durationTransition,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space12,
                  vertical: AppDimensions.space6,
                ),
                decoration: BoxDecoration(
                  color: isOn
                      ? AppColors.champagneGold.withValues(alpha: 0.12)
                      : AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        isOn ? AppColors.champagneGold : AppColors.cardBorder,
                    width: isOn
                        ? AppDimensions.borderFocus
                        : AppDimensions.borderThin,
                  ),
                ),
                child: UiText(
                  interest,
                  style: AppTypography.caption.copyWith(
                    color:
                        isOn ? AppColors.champagneGold : AppColors.pearlWhite,
                    fontWeight: isOn ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (selected.length >= 6)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.space8),
            child: UiText(
              context.uiCopy('Maximum 6 interests selected.'),
              style: AppTypography.caption.copyWith(
                color: AppColors.champagneGold,
              ),
            ),
          ),
      ],
    );
  }
}
