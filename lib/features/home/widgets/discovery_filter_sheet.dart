// SILARAH — Full Filter Bottom Sheet (Feature 8 + 9)
//
// Scrollable, server-authoritative discovery filters with saved presets.
//
// Presets (Feature 9):
//   "Save this filter" → name + persist via FilterPresetService
//   Horizontal preset chips above sections
//   Long-press preset chip → confirm delete
//
// Bottom: "Clear All" + "Apply Filters" buttons.
// Presented through Silarah's shared modal route from discovery filter chips.
import 'package:silarah/l10n/ui_copy.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cubits/discovery/discovery_feed_cubit.dart';
import '../../../core/cubits/discovery/discovery_filter.dart';
import '../../../core/cubits/subscription/subscription_cubit.dart';
import '../../../core/services/discovery_filter_options_service.dart';
import '../../../core/services/filter_preset_service.dart';
import '../../../core/services/launch_configuration_service.dart';
import '../../../core/services/country_context_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import '../../../core/widgets/overlays/silarah_dialog.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/inputs/city_search_field.dart';
import '../../../core/widgets/inputs/region_search_field.dart';
import '../screens/subscription_screen.dart';
import '../../../core/data/country_data.dart';

// Sheet entry point (called from DiscoveryFilterBar)
Future<void> showDiscoveryFilterSheet(
  BuildContext context, {
  DiscoveryFilter? initial,
  String? scrollToSection,
}) async {
  // The sheet paints its own rounded surface inside a DraggableScrollableSheet,
  // which fills the route. A transparent route keeps the theme's sheet surface
  // from showing as an empty band above it.
  await showSilarahBottomSheet<void>(
    context: context,
    builder: (sheetCtx) => BlocProvider.value(
      value: context.read<DiscoveryFeedCubit>(),
      child: DiscoveryFilterSheet(
        initial:
            initial ?? context.read<DiscoveryFeedCubit>().state.activeFilter,
        scrollToSection: scrollToSection,
      ),
    ),
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
  );
}

// Main widget
class DiscoveryFilterSheet extends StatefulWidget {
  const DiscoveryFilterSheet({
    super.key,
    required this.initial,
    this.scrollToSection,
  });

  final DiscoveryFilter initial;
  final String? scrollToSection;

  @override
  State<DiscoveryFilterSheet> createState() => _DiscoveryFilterSheetState();
}

class _DiscoveryFilterSheetState extends State<DiscoveryFilterSheet> {
  late DiscoveryFilter _draft;
  final _scrollCtrl = ScrollController();
  List<FilterPreset> _presets = [];
  bool _showSaveField = false;
  final _presetNameCtrl = TextEditingController();
  DiscoveryFilterOptions _options = DiscoveryFilterOptions.empty;
  bool _optionsLoading = true;
  bool _optionsLoadFailed = false;
  bool _singleCountryLaunch = true;
  bool _cityResolving = false;
  int _locationInputRevision = 0;

  // Section GlobalKeys for scroll-to
  final _genderKey = GlobalKey();
  final _ageKey = GlobalKey();
  final _sectKey = GlobalKey();
  final _deenKey = GlobalKey();
  final _eduKey = GlobalKey();
  final _familyKey = GlobalKey();
  final _maritalKey = GlobalKey();
  final _childrenKey = GlobalKey();
  final _verifiedKey = GlobalKey();
  final _allIndiaKey = GlobalKey();
  final _distanceKey = GlobalKey();
  final _locationKey = GlobalKey();
  final _tongueKey = GlobalKey();
  final _communityKey = GlobalKey();
  final _livingKey = GlobalKey();
  final _diasporaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _loadPresets();
    _loadLiveOptions();
    _loadLaunchConfiguration();
    if (widget.scrollToSection != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollTo(widget.scrollToSection!));
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _presetNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    final p = await FilterPresetService.load();
    if (mounted) setState(() => _presets = p);
  }

  Future<void> _loadLiveOptions() async {
    try {
      final options = await DiscoveryFilterOptionsService.load();
      if (mounted) {
        setState(() {
          _options = options;
          _optionsLoading = false;
          _optionsLoadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _options = DiscoveryFilterOptions.empty;
          _optionsLoading = false;
          _optionsLoadFailed = true;
        });
      }
    }
  }

  Future<void> _loadLaunchConfiguration() async {
    final config = await LaunchConfigurationService.load();
    if (!mounted) return;
    setState(() {
      _singleCountryLaunch = config.isSingleCountry;
      if (_singleCountryLaunch) {
        _draft = _draft.copyWith(
          diasporaMode: false,
          clearDiasporaCountries: true,
          clearBrowseCountries: true,
          clearDistanceLabel: _draft.distanceLabel == 'Same Country' ||
              _draft.distanceLabel == 'Anywhere',
          clearMaxDistance: false,
        );
      }
    });
  }

  void _scrollTo(String section) {
    final key = switch (section) {
      'gender' => _genderKey,
      'age' => _ageKey,
      'sect' => _sectKey,
      'deen' => _deenKey,
      'education' => _eduKey,
      'family' => _familyKey,
      'marital' => _maritalKey,
      'children' => _childrenKey,
      'verified' => _verifiedKey,
      'all_india' => _allIndiaKey,
      'distance' => _distanceKey,
      'location' => _locationKey,
      'diaspora' => _diasporaKey,
      'tongue' => _tongueKey,
      'community' => _communityKey,
      'living' => _livingKey,
      _ => _genderKey,
    };
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic);
    }
  }

  Future<void> _savePreset() async {
    final name = _presetNameCtrl.text.trim();
    if (name.isEmpty) return;
    final subscription = context.read<SubscriptionCubit>().state;
    if (_presets.isNotEmpty && !subscription.canSaveMultipleFilterPresets('')) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()),
      );
      return;
    }
    final updated = [..._presets, FilterPreset(name: name, filter: _draft)];
    await FilterPresetService.save(updated);
    if (mounted) {
      setState(() {
        _presets = updated.take(FilterPresetService.maxPresets).toList();
        _showSaveField = false;
        _presetNameCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UiText(
            context.uiCopyWith('Preset "{name}" saved', {'name': name}),
            style: AppTypography.body.copyWith(
              color: AppColors.readableOn(AppColors.surfaceGlassHover),
            ),
          ),
          backgroundColor: AppColors.surfaceGlassHover,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deletePreset(int index) async {
    final preset = _presets[index];
    final confirmed = await showSilarahDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: UiText(context.uiCopy('Delete preset?'),
            style: AppTypography.screenTitle.copyWith(fontSize: 18)),
        content: UiText(
          context.uiCopyWith('Remove "{name}"?', {'name': preset.name}),
          style: AppTypography.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: UiText(context.uiCopy('Cancel'), style: AppTypography.body),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: UiText(context.uiCopy('Delete'),
                style: AppTypography.body.copyWith(color: AppColors.softCoral)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final updated = List<FilterPreset>.from(_presets)..removeAt(index);
      await FilterPresetService.save(updated);
      if (mounted) setState(() => _presets = updated);
    }
  }

  void _applyPreset(FilterPreset preset) {
    setState(() {
      _draft = preset.filter;
      _locationInputRevision++;
    });
  }

  void _apply() {
    context.read<DiscoveryFeedCubit>().applyFilter(_draft);
    Navigator.pop(context);
  }

  void _clearAll() {
    setState(() {
      _draft = DiscoveryFilter.empty;
      _locationInputRevision++;
    });
  }

  void _selectState(RegionResult region) {
    setState(() {
      _draft = _draft.copyWith(
        stateName: region.name,
        clearCity: true,
        clearDistanceLabel: true,
        clearMaxDistance: true,
        diasporaMode: false,
        clearDiasporaCountries: true,
        clearBrowseCountries: true,
      );
      _locationInputRevision++;
    });
  }

  Future<void> _selectCity(CityResult city) async {
    if (_cityResolving) return;
    setState(() => _cityResolving = true);
    final resolution = await LocationService.resolveCity(city);
    if (!mounted) return;
    if (!resolution.isSuccess) {
      setState(() {
        _cityResolving = false;
        _locationInputRevision++;
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: UiText(
            resolution.errorMessage ??
                'That city could not be verified. Search and try again.',
          ),
        ));
      return;
    }
    setState(() {
      _cityResolving = false;
      _draft = _draft.copyWith(
        stateName: city.state.trim().isEmpty ? _draft.stateName : city.state,
        cityId: resolution.cityId,
        cityName: city.city,
        clearDistanceLabel: true,
        clearMaxDistance: true,
        diasporaMode: false,
        clearDiasporaCountries: true,
        clearBrowseCountries: true,
      );
      _locationInputRevision++;
    });
  }

  List<String> _withAny(List<String> values, {String? selected}) {
    final normalized = <String, String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      normalized[trimmed.toLowerCase()] = trimmed;
    }
    if (selected != null && selected.trim().isNotEmpty) {
      normalized[selected.trim().toLowerCase()] = selected.trim();
    }
    final live = normalized.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['Any', ...live];
  }

  List<String> _educationOptions() {
    final values = _options.educationRanks
        .map(_educationLabel)
        .whereType<String>()
        .toList();
    if (_draft.educationMin case final selected?) values.add(selected);
    return _withAny(values, selected: _draft.educationMin);
  }

  String? _educationLabel(int rank) {
    return switch (rank) {
      1 => 'Matric',
      2 => 'Intermediate',
      3 => "Bachelor's",
      4 => "Master's",
      5 => 'PhD',
      6 => 'Professional Degree',
      7 => 'Other',
      _ => null,
    };
  }

  String _facetLabel(String value) {
    if (value == 'no') return 'Never Married';
    if (value == 'prefer_not_to_say') return 'Prefer not to say';
    final words = value
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) {
      if (word.length <= 1) return word.toUpperCase();
      return '${word[0].toUpperCase()}${word.substring(1)}';
    });
    return words.join(' ');
  }

  List<String> _optionLabels(List<String> options) {
    return options
        .map((value) => value == 'Any' ? 'Any' : _facetLabel(value))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;
    final genderOptions = <String?>[
      null,
      ..._withAny(_options.genders, selected: _draft.genderPref).skip(1),
    ];
    final genderLabels = [
      'Any',
      ...genderOptions.skip(1).whereType<String>().map(_facetLabel),
    ];
    final sectOptions = _withAny(_options.sects, selected: _draft.sect);
    final deenOptions =
        _withAny(_options.deenLevels, selected: _draft.deenLevel);
    final educationOptions = _educationOptions();
    final familyOptions =
        _withAny(_options.familyTypes, selected: _draft.familyType);
    final maritalOptions =
        _withAny(_options.maritalStatuses, selected: _draft.maritalStatus);
    final tongueOptions =
        _withAny(_options.motherTongues, selected: _draft.motherTongue);
    final communityOptions =
        _withAny(_options.communities, selected: _draft.community);
    final livingOptions = _withAny(
      _options.livingExpectations,
      selected: _draft.livingExpectation,
    );
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: AppColors.cardBorder)),
          ),
          child: Column(
            children: [
              // Handle
              const Center(child: SilarahSheetHandle()),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 16, 12),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UiText(context.uiCopy('Refine discovery'),
                            style: AppTypography.screenTitle
                                .copyWith(fontSize: 20)),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: AppDimensions.durationTransition,
                          child: UiText(
                            _draft.activeCount == 0
                                ? 'Showing the broadest pool'
                                : context.uiCopyWith(
                                    '{count} preferences selected',
                                    {'count': _draft.activeCount}),
                            key: ValueKey(_draft.activeCount),
                            style: AppTypography.caption,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          setState(() => _showSaveField = !_showSaveField),
                      child: UiText(context.uiCopy('Save preset'),
                          style: AppTypography.caption
                              .copyWith(color: AppColors.champagneGold)),
                    ),
                  ],
                ),
              ),

              // Save preset field
              if (_showSaveField)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Row(children: [
                    Expanded(
                      child: _SheetTextField(
                        controller: _presetNameCtrl,
                        hint: 'Preset name (e.g. UK Sisters)',
                      ),
                    ),
                    const SizedBox(width: 8),
                    SilarahPressable(
                      semanticLabel: context.uiCopy('Save preset'),
                      onTap: _savePreset,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.champagneGold,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusButton),
                        ),
                        child: Icon(Icons.check_rounded,
                            color: AppColors.obsidianNight, size: 20),
                      ),
                    ),
                  ]),
                ),

              // Preset chips
              if (_presets.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _presets.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final p = _presets[i];
                        return SilarahPressable(
                          onTap: () => _applyPreset(p),
                          onLongPress: () => _deletePreset(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.champagneGold
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusChip),
                              border: Border.all(color: AppColors.goldBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bookmark_rounded,
                                    color: AppColors.champagneGold, size: 14),
                                const SizedBox(width: 4),
                                UiText(p.name,
                                    style: AppTypography.chipLabel.copyWith(
                                        color: AppColors.champagneGold)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              Divider(color: AppColors.divider, height: 1),
              if (_optionsLoading)
                SilarahLinearProgress(
                  height: 1,
                  color: AppColors.champagneGold,
                  trackColor: AppColors.surfaceGlass,
                ),
              if (_optionsLoadFailed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                  child: UiText(
                    context.uiCopy(
                        'Live filter options could not be loaded. Broad filters remain available.'),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.softCoral,
                    ),
                  ),
                ),

              // Scrollable content
              Expanded(
                child: Builder(
                  builder: (context) {
                    final sections = <Widget>[
                      // GENDER PREFERENCE
                      _SectionLabel(
                          key: _genderKey, label: 'GENDER PREFERENCE'),
                      const SizedBox(height: 8),
                      _RadioGroup<String?>(
                        options: genderOptions,
                        labels: genderLabels,
                        value: _draft.genderPref,
                        onChanged: (v) => setState(() => _draft =
                            _draft.copyWith(
                                genderPref: v, clearGenderPref: v == null)),
                      ),
                      const SizedBox(height: 20),

                      // AGE RANGE
                      _SectionLabel(key: _ageKey, label: 'AGE RANGE'),
                      const SizedBox(height: 8),
                      _AgeRangeField(
                        min: (_draft.ageMin ?? 22).toDouble(),
                        max: (_draft.ageMax ?? 35).toDouble(),
                        onChanged: (lo, hi) =>
                            setState(() => _draft = _draft.copyWith(
                                  ageMin: lo.round(),
                                  ageMax: hi.round(),
                                )),
                      ),
                      const SizedBox(height: 20),

                      // SECT
                      _SectionLabel(key: _sectKey, label: 'SECT'),
                      const SizedBox(height: 8),
                      _MultiChipGroup(
                        options: sectOptions,
                        optionLabels: _optionLabels(sectOptions),
                        selected: _draft.sect,
                        onChanged: (v) => setState(() => _draft =
                            _draft.copyWith(sect: v, clearSect: v == null)),
                      ),
                      const SizedBox(height: 20),

                      // DEEN LEVEL
                      _SectionLabel(key: _deenKey, label: 'DEEN LEVEL'),
                      const SizedBox(height: 8),
                      _MultiChipGroup(
                        options: deenOptions,
                        optionLabels: _optionLabels(deenOptions),
                        selected: _draft.deenLevel,
                        onChanged: (v) => setState(() => _draft = _draft
                            .copyWith(deenLevel: v, clearDeenLevel: v == null)),
                      ),
                      const SizedBox(height: 20),

                      // EDUCATION MINIMUM
                      _SectionLabel(key: _eduKey, label: 'EDUCATION MINIMUM'),
                      const SizedBox(height: 8),
                      _DropdownRow(
                        value: _draft.educationMin ?? 'Any',
                        options: educationOptions,
                        onChanged: (v) =>
                            setState(() => _draft = _draft.copyWith(
                                  educationMin: v == 'Any' ? null : v,
                                  clearEducationMin: v == 'Any',
                                )),
                      ),
                      const SizedBox(height: 20),

                      // FAMILY TYPE
                      _SectionLabel(key: _familyKey, label: 'FAMILY TYPE'),
                      const SizedBox(height: 8),
                      _MultiChipGroup(
                        options: familyOptions,
                        optionLabels: _optionLabels(familyOptions),
                        selected: _draft.familyType,
                        onChanged: (v) =>
                            setState(() => _draft = _draft.copyWith(
                                  familyType: v,
                                  clearFamilyType: v == null,
                                )),
                      ),
                      const SizedBox(height: 20),

                      // MARITAL STATUS
                      _SectionLabel(key: _maritalKey, label: 'MARITAL STATUS'),
                      const SizedBox(height: 8),
                      _MultiChipGroup(
                        options: maritalOptions,
                        optionLabels: _optionLabels(maritalOptions),
                        selected: _draft.maritalStatus,
                        onChanged: (v) =>
                            setState(() => _draft = _draft.copyWith(
                                  maritalStatus: v,
                                  clearMaritalStatus: v == null,
                                )),
                      ),
                      const SizedBox(height: 20),

                      // HAS CHILDREN
                      _SectionLabel(key: _childrenKey, label: 'HAS CHILDREN'),
                      const SizedBox(height: 8),
                      _RadioGroup<String?>(
                        options: const [null, 'No', 'Yes'],
                        labels: const ["Doesn't matter", 'No', 'Yes'],
                        value: _draft.hasChildren,
                        onChanged: (v) =>
                            setState(() => _draft = _draft.copyWith(
                                  hasChildren: v,
                                  clearHasChildren: v == null,
                                )),
                      ),
                      const SizedBox(height: 20),

                      // TRUST CHECKS (Premium)
                      _SectionLabel(key: _verifiedKey, label: 'TRUST CHECKS'),
                      const SizedBox(height: 8),
                      _SubscriberGate(
                        child: _RadioGroup<String?>(
                          options: const [
                            null,
                            'photo',
                            'guardian',
                          ],
                          labels: const [
                            'Any trust level',
                            'Photo verified',
                            'Guardian connected',
                          ],
                          value: _draft.trustFilter,
                          onChanged: (value) => setState(() {
                            _draft = _draft.copyWith(
                              trustFilter: value,
                              clearTrustFilter: value == null,
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (_singleCountryLaunch) ...[
                        _SectionLabel(
                          key: _allIndiaKey,
                          label: context.uiCopy('DISCOVERY SCOPE'),
                        ),
                        const SizedBox(height: 8),
                        _SubscriberGate(
                          child: _AllIndiaScopeTile(
                            selected: _draft.distanceLabel == 'All India' ||
                                _draft.distanceLabel == 'Anywhere in India',
                            onTap: () => setState(() {
                              final alreadySelected = _draft.distanceLabel ==
                                      'All India' ||
                                  _draft.distanceLabel == 'Anywhere in India';
                              _draft = _draft.copyWith(
                                distanceLabel:
                                    alreadySelected ? null : 'All India',
                                clearDistanceLabel: alreadySelected,
                                clearMaxDistance: true,
                                clearState: true,
                                clearCity: true,
                                diasporaMode: false,
                                clearDiasporaCountries: true,
                                clearBrowseCountries: true,
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // DISTANCE (Premium)
                      _SectionLabel(key: _distanceKey, label: 'DISTANCE'),
                      const SizedBox(height: 8),
                      _SubscriberGate(
                        child: _MultiChipGroup(
                          options: _singleCountryLaunch
                              ? const [
                                  'Same City',
                                  'Same State / Region',
                                  '25km',
                                  '50km',
                                  '100km',
                                  '250km',
                                ]
                              : const [
                                  'Anywhere',
                                  'Same City',
                                  'Same State / Region',
                                  '25km',
                                  '50km',
                                  '100km',
                                  '250km',
                                  'Same Country',
                                ],
                          selected: _draft.distanceLabel,
                          onChanged: (v) {
                            final radius = RegExp(r'^(\d+)km$')
                                .firstMatch(v ?? '')
                                ?.group(1);
                            setState(() => _draft = _draft.copyWith(
                                  distanceLabel: v,
                                  maxDistanceKm: int.tryParse(radius ?? ''),
                                  clearDistanceLabel: v == null,
                                  clearMaxDistance: radius == null,
                                  clearState: v != null,
                                  clearCity: v != null,
                                  diasporaMode: false,
                                  clearDiasporaCountries: true,
                                  clearBrowseCountries: true,
                                ));
                          },
                        ),
                      ),
                      if (_draft.effectiveMaxDistanceKm case final km?) ...[
                        const SizedBox(height: 8),
                        UiText(
                          context.uiCopyWith('Within {km} km', {'km': km}),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.champagneGold,
                          ),
                        ),
                        Slider(
                          value: km.clamp(10, 500).toDouble(),
                          min: 10,
                          max: 500,
                          divisions: 49,
                          activeColor: AppColors.champagneGold,
                          inactiveColor: AppColors.surfaceGlassHover,
                          onChanged: (value) => setState(() {
                            final radius = value.round();
                            _draft = _draft.copyWith(
                              maxDistanceKm: radius,
                              distanceLabel: '${radius}km',
                              clearState: true,
                              clearCity: true,
                            );
                          }),
                        ),
                      ],
                      const SizedBox(height: 20),

                      if (_singleCountryLaunch) ...[
                        _SectionLabel(
                          key: _locationKey,
                          label: 'LOCATION IN INDIA',
                        ),
                        const SizedBox(height: 8),
                        _SubscriberGate(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UiText(
                                'Choose a state, then optionally a city. This searches where members live and does not change your own profile.',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.slateMist,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              RegionSearchField(
                                key: ValueKey(
                                  'filter-state-${_draft.stateName}-$_locationInputRevision',
                                ),
                                countryCode: 'IN',
                                initialValue: _draft.stateName,
                                hint: 'Search any Indian state or UT',
                                onSelected: _selectState,
                                onCleared: () => setState(() {
                                  _draft = _draft.copyWith(
                                    clearState: true,
                                    clearCity: true,
                                  );
                                  _locationInputRevision++;
                                }),
                              ),
                              const SizedBox(height: 10),
                              CitySearchField(
                                key: ValueKey(
                                  'filter-city-${_draft.cityId}-${_draft.stateName}-$_locationInputRevision',
                                ),
                                countryCode: 'IN',
                                regionName: _draft.stateName,
                                initialValue: _draft.cityName,
                                hint: _draft.stateName == null
                                    ? 'Search any Indian city'
                                    : context.uiCopyWith(
                                        'Search a city in {region}',
                                        {'region': _draft.stateName!}),
                                enabled: !_cityResolving,
                                onSelected: _selectCity,
                                onCleared: () => setState(() {
                                  _draft = _draft.copyWith(clearCity: true);
                                }),
                              ),
                              if (_cityResolving) ...[
                                const SizedBox(height: 8),
                                UiText(
                                  'Verifying city…',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.champagneGold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      if (!_singleCountryLaunch) ...[
                        // GLOBAL COUNTRY CONTROLS (Premium)
                        const _SectionLabel(label: 'BROWSE COUNTRIES'),
                        const SizedBox(height: 8),
                        _SubscriberGate(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UiText(
                                context.uiCopy(
                                    'Explore members currently living in selected countries.'),
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.slateMist,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ...(_draft.browseCountries ?? []).map((code) {
                                    final country = kAllCountries.firstWhere(
                                      (c) => c.iso2 == code,
                                      orElse: () => CountryInfo(
                                        iso2: code,
                                        dialCode: '',
                                        name: code,
                                      ),
                                    );
                                    return Chip(
                                      backgroundColor: AppColors.champagneGold
                                          .withValues(alpha: 0.12),
                                      side: BorderSide(
                                        color: AppColors.goldBorder,
                                      ),
                                      label: UiText(
                                        '${country.flag} ${country.name}',
                                        style: AppTypography.chipLabel.copyWith(
                                          color: AppColors.champagneGold,
                                        ),
                                      ),
                                      onDeleted: () {
                                        setState(() {
                                          final current = List<String>.from(
                                            _draft.browseCountries ?? [],
                                          )..remove(code);
                                          _draft = _draft.copyWith(
                                            browseCountries: current,
                                            clearBrowseCountries:
                                                current.isEmpty,
                                          );
                                        });
                                      },
                                      deleteIconColor: AppColors.champagneGold,
                                    );
                                  }),
                                  ActionChip(
                                    backgroundColor: AppColors.surfaceGlass,
                                    side: BorderSide(
                                      color: AppColors.cardBorder,
                                    ),
                                    avatar: Icon(
                                      Icons.public_rounded,
                                      color: AppColors.slateMist,
                                      size: 16,
                                    ),
                                    label: UiText(
                                      (_draft.browseCountries ?? []).isEmpty
                                          ? 'Choose countries'
                                          : 'Change countries',
                                      style: AppTypography.chipLabel,
                                    ),
                                    onPressed: () =>
                                        _showCountrySelector(diaspora: false),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        _SectionLabel(
                            key: _diasporaKey, label: 'DIASPORA MODE'),
                        const SizedBox(height: 8),
                        _SubscriberGate(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ToggleRow(
                                label: 'Enable Diaspora Mode',
                                value: _draft.diasporaMode,
                                onChanged: (v) {
                                  setState(() {
                                    _draft = _draft.copyWith(
                                      diasporaMode: v,
                                      clearDiasporaCountries: !v,
                                      clearBrowseCountries: v,
                                      clearDistanceLabel: v,
                                      clearMaxDistance: v,
                                    );
                                  });
                                },
                              ),
                              if (_draft.diasporaMode) ...[
                                const SizedBox(height: 12),
                                UiText(
                                  context.uiCopy('Target Home Countries'),
                                  style: AppTypography.caption,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ...(_draft.diasporaCountries ?? [])
                                        .map((code) {
                                      final country = kAllCountries.firstWhere(
                                        (c) => c.iso2 == code,
                                        orElse: () => CountryInfo(
                                            iso2: code,
                                            dialCode: '',
                                            name: code),
                                      );
                                      return Chip(
                                        backgroundColor: AppColors.champagneGold
                                            .withValues(alpha: 0.12),
                                        side: BorderSide(
                                            color: AppColors.goldBorder),
                                        label: UiText(
                                          '${country.flag} ${country.name}',
                                          style: AppTypography.chipLabel
                                              .copyWith(
                                                  color:
                                                      AppColors.champagneGold),
                                        ),
                                        onDeleted: () {
                                          setState(() {
                                            final current = List<String>.from(
                                                _draft.diasporaCountries ?? []);
                                            current.remove(code);
                                            _draft = _draft.copyWith(
                                              diasporaCountries: current,
                                              clearDiasporaCountries:
                                                  current.isEmpty,
                                            );
                                          });
                                        },
                                        deleteIconColor:
                                            AppColors.champagneGold,
                                      );
                                    }),
                                    ActionChip(
                                      backgroundColor: AppColors.surfaceGlass,
                                      side: BorderSide(
                                          color: AppColors.cardBorder),
                                      avatar: Icon(Icons.add,
                                          color: AppColors.slateMist, size: 16),
                                      label: UiText(
                                          context.uiCopy('Add Country'),
                                          style: AppTypography.chipLabel),
                                      onPressed: () =>
                                          _showCountrySelector(diaspora: true),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // MOTHER TONGUE (Premium)
                      _SectionLabel(
                        key: _tongueKey,
                        label: 'MOTHER TONGUE',
                        premium: true,
                      ),
                      const SizedBox(height: 8),
                      _SubscriberGate(
                        child: _DropdownRow(
                          value: _draft.motherTongue ?? 'Any',
                          options: tongueOptions,
                          onChanged: (v) =>
                              setState(() => _draft = _draft.copyWith(
                                    motherTongue: v == 'Any' ? null : v,
                                    clearMotherTongue: v == 'Any',
                                  )),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // COMMUNITY / BIRADARI (Premium)
                      _SectionLabel(
                        key: _communityKey,
                        label: 'COMMUNITY / BIRADARI',
                        premium: true,
                      ),
                      const SizedBox(height: 8),
                      _SubscriberGate(
                        child: _DropdownRow(
                          value: _draft.community ?? 'Any',
                          options: communityOptions,
                          onChanged: (v) =>
                              setState(() => _draft = _draft.copyWith(
                                    community: v == 'Any' ? null : v,
                                    clearCommunity: v == 'Any',
                                  )),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // LIVING EXPECTATION (Premium)
                      _SectionLabel(
                          key: _livingKey, label: 'POST-MARRIAGE LIVING'),
                      const SizedBox(height: 8),
                      _SubscriberGate(
                        child: _MultiChipGroup(
                          options: livingOptions,
                          optionLabels: _optionLabels(livingOptions),
                          selected: _draft.livingExpectation,
                          onChanged: (v) =>
                              setState(() => _draft = _draft.copyWith(
                                    livingExpectation: v,
                                    clearLivingExpectation: v == null,
                                  )),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ];
                    return ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      itemCount: sections.length,
                      itemBuilder: (context, index) => sections[index],
                    );
                  },
                ),
              ),

              // Bottom buttons
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + bottomPad),
                child: Row(
                  children: [
                    Expanded(
                      child: SilarahPressable(
                        onTap: _clearAll,
                        haptic: true,
                        child: Container(
                          height: AppDimensions.buttonHeight,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGlass,
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusButton),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: UiText(context.uiCopy('Clear All'),
                              style: AppTypography.body),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SilarahPressable(
                        onTap: _apply,
                        haptic: true,
                        child: Container(
                          height: AppDimensions.buttonHeight,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.champagneGold,
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusButton),
                          ),
                          child: AnimatedSwitcher(
                            duration: AppDimensions.durationTransition,
                            child: UiText(
                              _draft.activeCount == 0
                                  ? 'Show all profiles'
                                  : context.uiCopyWith('Apply {count} filters',
                                      {'count': _draft.activeCount}),
                              key: ValueKey(_draft.activeCount),
                              style: AppTypography.button,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCountrySelector({required bool diaspora}) {
    final searchCtrl = TextEditingController();
    final tempSelected = List<String>.from(
      diaspora
          ? (_draft.diasporaCountries ?? [])
          : (_draft.browseCountries ?? []),
    );

    showSilarahBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final query = searchCtrl.text.toLowerCase().trim();
            final filtered = kAllCountries.where((c) {
              return c.name.toLowerCase().contains(query) ||
                  c.iso2.toLowerCase().contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      UiText(
                        diaspora ? 'Select Home Countries' : 'Choose Countries',
                        style: AppTypography.screenTitle.copyWith(fontSize: 18),
                      ),
                      IconButton(
                        tooltip: context.uiCopy('Close'),
                        icon: Icon(Icons.close, color: AppColors.slateMist),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    style: AppTypography.body,
                    decoration: InputDecoration(
                      hintText: context.uiCopy('Search countries...'),
                      hintStyle: AppTypography.bodyMuted,
                      prefixIcon:
                          Icon(Icons.search, color: AppColors.slateMist),
                      fillColor: AppColors.surfaceGlass,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.champagneGold),
                      ),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final country = filtered[index];
                        final isSel = tempSelected.contains(country.iso2);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: UiText(
                            country.flag,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: UiText(
                            country.name,
                            style: AppTypography.body.copyWith(
                              color: isSel
                                  ? AppColors.champagneGold
                                  : AppColors.pearlWhite,
                              fontWeight:
                                  isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: isSel
                              ? Icon(Icons.check_circle,
                                  color: AppColors.champagneGold)
                              : Icon(Icons.circle_outlined,
                                  color: AppColors.slateMist),
                          onTap: () {
                            setSheetState(() {
                              if (isSel) {
                                tempSelected.remove(country.iso2);
                              } else if (tempSelected.length < 20) {
                                tempSelected.add(country.iso2);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
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
                      onPressed: () {
                        setState(() {
                          if (diaspora) {
                            _draft = _draft.copyWith(
                              diasporaCountries: tempSelected,
                              clearDiasporaCountries: tempSelected.isEmpty,
                              clearBrowseCountries: true,
                              clearDistanceLabel: true,
                              clearMaxDistance: true,
                            );
                          } else {
                            _draft = _draft.copyWith(
                              browseCountries: tempSelected,
                              clearBrowseCountries: tempSelected.isEmpty,
                              diasporaMode: false,
                              clearDiasporaCountries: true,
                              clearDistanceLabel: true,
                              clearMaxDistance: true,
                            );
                          }
                        });
                        Navigator.pop(sheetCtx);
                      },
                      child: UiText(
                        context.uiCopyWith(
                            'Apply ({count})', {'count': tempSelected.length}),
                        style: AppTypography.button,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Sub-widgets
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({super.key, required this.label, this.premium = false});
  final String label;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final text = UiText(
      label,
      style: AppTypography.sectionLabel.copyWith(
        color: AppColors.slateMist,
        letterSpacing: 1.1,
      ),
    );
    if (!premium) return text;
    return Row(
      children: [
        Flexible(child: text),
        const SizedBox(width: 8),
        const _PremiumPill(),
      ],
    );
  }
}

class _PremiumPill extends StatelessWidget {
  const _PremiumPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.premiumGold.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: UiText(
        context.uiCopy('PREMIUM'),
        style: AppTypography.badge.copyWith(
          color: AppColors.premiumGold,
          fontWeight: FontWeight.w700,
          letterSpacing: .7,
        ),
      ),
    );
  }
}

class _RadioGroup<T> extends StatelessWidget {
  const _RadioGroup({
    required this.options,
    required this.labels,
    required this.value,
    required this.onChanged,
  });
  final List<T> options;
  final List<String> labels;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.space8,
      runSpacing: AppDimensions.space8,
      children: List.generate(options.length, (i) {
        final opt = options[i];
        final isSelected = opt == value;
        return SilarahPressable(
          haptic: true,
          onTap: () => onChanged(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space14,
                vertical: AppDimensions.space8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.champagneGold.withValues(alpha: 0.15)
                  : AppColors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? AppColors.champagneGold
                    : AppColors.cardBorder.withValues(alpha: 0.72),
                width: 1.5,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 19,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: isSelected ? 1 : 0,
                  child: Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.champagneGold,
                  ),
                ),
              ),
              UiText(labels[i],
                  style: AppTypography.chipLabel.copyWith(
                    color: isSelected
                        ? AppColors.champagneGold
                        : AppColors.slateMist,
                  )),
            ]),
          ),
        );
      }),
    );
  }
}

class _MultiChipGroup extends StatelessWidget {
  const _MultiChipGroup({
    required this.options,
    this.optionLabels,
    required this.selected,
    required this.onChanged,
  });
  final List<String> options;
  final List<String>? optionLabels;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.space8,
      runSpacing: AppDimensions.space8,
      children: List.generate(options.length, (i) {
        final val = options[i];
        final label = optionLabels?[i] ?? val;
        final isAny = val == 'Any';
        final isSelected = isAny ? selected == null : selected == val;
        return SilarahPressable(
          haptic: true,
          onTap: () => onChanged(isAny ? null : (selected == val ? null : val)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space14,
                vertical: AppDimensions.space8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.champagneGold.withValues(alpha: 0.15)
                  : AppColors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? AppColors.champagneGold
                    : AppColors.cardBorder.withValues(alpha: 0.72),
                width: 1.5,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 19,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: isSelected ? 1 : 0,
                  child: Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.champagneGold,
                  ),
                ),
              ),
              UiText(label,
                  style: AppTypography.chipLabel.copyWith(
                    color: isSelected
                        ? AppColors.champagneGold
                        : AppColors.slateMist,
                  )),
            ]),
          ),
        );
      }),
    );
  }
}

class _AgeRangeField extends StatefulWidget {
  const _AgeRangeField({
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final double min;
  final double max;
  final void Function(double, double) onChanged;

  @override
  State<_AgeRangeField> createState() => _AgeRangeFieldState();
}

class _AgeRangeFieldState extends State<_AgeRangeField> {
  late RangeValues _values;

  @override
  void initState() {
    super.initState();
    _values = RangeValues(widget.min, widget.max);
  }

  @override
  void didUpdateWidget(covariant _AgeRangeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.min != widget.min || oldWidget.max != widget.max) {
      _values = RangeValues(widget.min, widget.max);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _AgeLabel(age: _values.start.round()),
            _AgeLabel(age: _values.end.round()),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.champagneGold,
            inactiveTrackColor: AppColors.surfaceGlassHover,
            thumbColor: AppColors.champagneGold,
            overlayColor: AppColors.champagneGold.withValues(alpha: 0.12),
            rangeThumbShape:
                const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
            trackHeight: 3,
          ),
          child: RangeSlider(
            values: _values,
            min: 18,
            max: 65,
            divisions: 47,
            labels: RangeLabels(
              '${_values.start.round()}',
              '${_values.end.round()}',
            ),
            onChanged: (values) => setState(() => _values = values),
            onChangeEnd: (values) => widget.onChanged(values.start, values.end),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            UiText('18', style: AppTypography.caption),
            UiText('65', style: AppTypography.caption),
          ],
        ),
      ],
    );
  }
}

class _AgeLabel extends StatelessWidget {
  const _AgeLabel({required this.age});
  final int age;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16, vertical: AppDimensions.space8),
      decoration: BoxDecoration(
        color: AppColors.champagneGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: UiText(context.uiAgeYears(age),
          style: AppTypography.bodyMedium
              .copyWith(color: AppColors.champagneGold)),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safe = options.contains(value) ? value : options.first;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16, vertical: AppDimensions.space4),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: safe,
        style: AppTypography.inputText,
        dropdownColor: AppColors.surfaceElevated,
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
        icon: Icon(Icons.expand_more_rounded, color: AppColors.slateMist),
        items: options
            .map((o) => DropdownMenuItem(
                  value: o,
                  child: UiText(o, style: AppTypography.body),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

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
    return SilarahPressable(
      onTap: () => onChanged(!value),
      haptic: true,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16, vertical: AppDimensions.space10),
        decoration: BoxDecoration(
          color: value ? AppColors.goldGlow : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
              color: value ? AppColors.goldBorder : AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(child: UiText(label, style: AppTypography.body)),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.obsidianNight,
              activeTrackColor: AppColors.champagneGold,
              inactiveThumbColor: AppColors.slateMist,
              inactiveTrackColor: AppColors.surfaceGlassHover,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.cardBorder),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        style: AppTypography.body,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.bodyMuted,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          filled: false,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space12, vertical: 0),
        ),
      ),
    );
  }
}

// Subscriber Gate
// Shows a lock overlay on premium filter sections (Distance)
// for non-subscribers. Tapping navigates to SubscriptionScreen.

class _SubscriberGate extends StatelessWidget {
  const _SubscriberGate({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final subState = context.watch<SubscriptionCubit>().state;
    if (subState.isActive) return child;

    return SilarahPressable(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const SubscriptionScreen(),
          ),
        );
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space14,
          vertical: AppDimensions.space12,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.goldGlow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.lock_outline_rounded,
                  color: AppColors.champagneGold, size: 18),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText(context.uiCopy('Premium preference'),
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.pearlWhite)),
                  const SizedBox(height: 2),
                  UiText(context.uiCopy('Upgrade to refine this criterion'),
                      style: AppTypography.caption),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.champagneGold,
                size: AppDimensions.iconSizeMedium),
          ],
        ),
      ),
    );
  }
}

class _AllIndiaScopeTile extends StatelessWidget {
  const _AllIndiaScopeTile({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: context.uiCopy('View all profiles from India'),
      child: SilarahPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppDimensions.space14),
          decoration: BoxDecoration(
            color: selected ? AppColors.goldGlow : AppColors.surfaceGlassHover,
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            border: Border.all(
              color: selected ? AppColors.champagneGold : AppColors.cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.champagneGold
                      : AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.travel_explore_rounded,
                  color: selected
                      ? AppColors.readableOn(AppColors.champagneGold)
                      : AppColors.champagneGold,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppDimensions.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: UiText(
                            context.uiCopy('All India'),
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.pearlWhite,
                            ),
                          ),
                        ),
                        const _PremiumPill(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    UiText(
                      context.uiCopy(
                        'Browse eligible profiles across every Indian state and Union Territory. Safety, gender, block and visibility rules still apply.',
                      ),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.slateMist,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.champagneGold : AppColors.slateMist,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
