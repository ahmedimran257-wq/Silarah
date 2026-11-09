import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/data/country_data.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/services/country_context_service.dart';
import '../../../core/services/launch_configuration_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/country_picker_screen.dart';
import '../../../core/widgets/inputs/city_search_field.dart';
import '../../../core/widgets/inputs/region_search_field.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

class QuickLocationScreen extends StatefulWidget {
  const QuickLocationScreen({super.key});

  @override
  State<QuickLocationScreen> createState() => _QuickLocationScreenState();
}

class _QuickLocationScreenState extends State<QuickLocationScreen> {
  late CountryInfo _country;
  RegionResult? _region;
  String? _initialRegion;
  CityResult? _city;
  String? _initialCity;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = context.read<OnboardingCubit>().currentData;
    _country = kAllCountries.firstWhere((country) => country.iso2 == 'IN');
    _loadLaunchCountry(data);
  }

  void _restoreSavedLocation(
    OnboardingData data,
    CountryInfo selectedCountry,
  ) {
    final savedCountry = data.countryCode?.trim().toUpperCase();
    final locationBelongsToSelectedCountry = savedCountry == null ||
        savedCountry.isEmpty ||
        savedCountry == selectedCountry.iso2.toUpperCase();
    if (!locationBelongsToSelectedCountry) {
      _region = null;
      _initialRegion = null;
      _city = null;
      _initialCity = null;
      return;
    }

    final savedState = data.stateName?.trim().isNotEmpty == true
        ? data.stateName!.trim()
        : _stateFromCityName(data.cityName);
    if (savedState != null && savedState.isNotEmpty) {
      _initialRegion = savedState;
      _region = RegionResult(
        id: '',
        name: savedState,
        countryCode: selectedCountry.iso2,
        country: selectedCountry.name,
      );
    }
    _initialCity = data.cityName;
    if (data.cityName?.trim().isNotEmpty == true &&
        data.countryCode?.trim().isNotEmpty == true &&
        data.lat != null &&
        data.lng != null) {
      final cityOnly = data.cityName!.split(',').first.trim();
      _city = CityResult(
        city: cityOnly,
        state: savedState ?? data.stateName ?? '',
        country: selectedCountry.name,
        countryCode: selectedCountry.iso2,
        postalCode: data.postalCode ?? '',
        fullAddress: [
          cityOnly,
          if ((savedState ?? data.stateName)?.trim().isNotEmpty == true)
            (savedState ?? data.stateName)!.trim(),
          selectedCountry.name,
        ].join(', '),
        placeId: data.cityId ?? '',
        lat: data.lat!,
        lng: data.lng!,
      );
    }
  }

  Future<void> _loadLaunchCountry(OnboardingData data) async {
    final launch = await LaunchConfigurationService.load();
    if (!mounted) return;
    final preferred = data.countryCode?.trim().toUpperCase();
    final device = deviceCountry().iso2.toUpperCase();
    final selectedCode = launch.enabledCountries.contains(preferred)
        ? preferred!
        : launch.enabledCountries.contains(device)
            ? device
            : launch.defaultCountry;
    final matches = kAllCountries.where(
      (country) => country.iso2.toUpperCase() == selectedCode,
    );
    final selectedCountry = matches.isNotEmpty ? matches.first : _country;
    setState(() {
      _country = selectedCountry;
      _restoreSavedLocation(data, selectedCountry);
    });
  }

  bool get _isValid => _city != null && !_saving;

  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  void _selectCountry(CountryInfo country) {
    _dismissKeyboard();
    if (country.iso2 == _country.iso2) return;
    setState(() {
      _country = country;
      _region = null;
      _initialRegion = null;
      _city = null;
      _initialCity = null;
    });
  }

  void _selectRegion(RegionResult region) {
    _dismissKeyboard();
    setState(() {
      _region = region;
      _initialRegion = null;
      _city = null;
      _initialCity = null;
    });
  }

  String? _stateFromCityName(String? cityName) {
    final parts = cityName?.split(', ') ?? const <String>[];
    if (parts.length < 2) return null;
    final state = parts[1].trim();
    return state.isEmpty ? null : state;
  }

  Future<void> _continue() async {
    _dismissKeyboard();
    final city = _city;
    if (city == null || _saving) return;
    setState(() => _saving = true);

    final resolution = await LocationService.resolveCity(city);
    if (!mounted) return;
    if (!resolution.isSuccess) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: UiText(resolution.errorMessage!)),
      );
      return;
    }

    final stateName = city.state.isNotEmpty ? city.state : _region?.name ?? '';
    final cityName = stateName.isEmpty ? city.city : '${city.city}, $stateName';
    final cubit = context.read<OnboardingCubit>();
    final countrySaved = await context.read<AuthCubit>().setCountryCode(
          _country.iso2,
        );
    if (!mounted) return;
    if (!countrySaved) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                UiText(context.uiCopy('Could not save. Please try again.'))),
      );
      return;
    }
    await cubit.saveAndAdvance(cubit.currentData.copyWith(
      countryCode: _country.iso2,
      cityId: resolution.cityId,
      cityName: cityName,
      stateName: stateName,
      postalCode: city.postalCode,
      lat: city.lat,
      lng: city.lng,
    ));
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepHeader(
            title: 'Where are you?',
            subtitle: 'This helps us show you relevant matches nearby.',
          ),
          const SizedBox(height: AppDimensions.space32),
          UiText(context.uiCopy('Country'), style: AppTypography.sectionLabel),
          const SizedBox(height: AppDimensions.space8),
          InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            onTap: () {
              _dismissKeyboard();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CountryPickerScreen(
                  selected: _country,
                  onSelected: _selectCountry,
                ),
              ));
            },
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(children: [
                UiText(_country.flag, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                    child: UiText(_country.name, style: AppTypography.body)),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.slateMist),
              ]),
            ),
          ),
          const SizedBox(height: AppDimensions.space24),
          UiText(context.uiCopy('State / Region (optional)'),
              style: AppTypography.sectionLabel),
          const SizedBox(height: AppDimensions.space8),
          RegionSearchField(
            key: ValueKey('region_${_country.iso2}'),
            countryCode: _country.iso2,
            initialValue: _initialRegion,
            hint: 'Search state, province, or region',
            onSelected: _selectRegion,
            onCleared: () => setState(() {
              _region = null;
              _initialRegion = null;
              _city = null;
              _initialCity = null;
            }),
          ),
          const SizedBox(height: AppDimensions.space8),
          UiText(
            context.uiCopy(
                'Optional, but helps narrow city results in large countries.'),
            style: AppTypography.bodyMuted,
          ),
          const SizedBox(height: AppDimensions.space24),
          UiText(context.uiCopy('City'), style: AppTypography.sectionLabel),
          const SizedBox(height: AppDimensions.space8),
          CitySearchField(
            key: ValueKey('${_country.iso2}_${_region?.name ?? ''}'),
            countryCode: _country.iso2,
            regionName: _region?.name,
            initialValue: _initialCity,
            hint: _region == null
                ? 'Search your city or area'
                : context.uiCopyWith(
                    'Search city in {region}', {'region': _region!.name}),
            onSelected: (result) {
              _dismissKeyboard();
              setState(() {
                _city = result;
                _initialCity = null;
              });
            },
            onCleared: () => setState(() {
              _city = null;
              _initialCity = null;
            }),
          ),
          if (!_isValid) ...[
            const SizedBox(height: AppDimensions.space16),
            UiText(
              context.uiCopy('Select a city from the results to continue.'),
              style: AppTypography.bodyMuted,
            ),
          ],
        ],
      ),
      ctaLabel: 'Continue',
      onCta: _isValid ? _continue : null,
      isCtaEnabled: _isValid,
      isCtaLoading: _saving,
    );
  }
}
