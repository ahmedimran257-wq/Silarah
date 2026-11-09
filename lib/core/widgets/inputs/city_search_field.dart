// SILARAH — City Search Field
//
// Uses the Supabase city cache with Photon as the global fallback.
// Shows: city name, state, country, postal code (pincode).
//
// Requires a verified result so matching always has coordinates.
//
// Usage:
//   CitySearchField(
//     countryCode: 'IN',
//     initialValue: data.city,
//     onSelected: (result) {
//       setState(() {
//         city       = result.city;
//         postalCode = result.postalCode;
//         lat        = result.lat;
//         lng        = result.lng;
//       });
//     },
//   )
import 'package:silarah/l10n/ui_copy.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/country_context_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';
import '../loaders/silarah_shimmer.dart';
import 'silarah_field_frame.dart';

class CitySearchField extends StatefulWidget {
  const CitySearchField({
    super.key,
    this.countryCode,
    this.regionName,
    required this.onSelected,
    this.onCleared,
    this.initialValue,
    this.label,
    this.hint,
    this.enabled = true,
  });

  final String? countryCode;
  final String? regionName;
  final ValueChanged<CityResult> onSelected;
  final VoidCallback? onCleared;
  final String? initialValue;
  final String? label;
  final String? hint;
  final bool enabled;

  @override
  State<CitySearchField> createState() => _CitySearchFieldState();
}

class _CitySearchFieldState extends State<CitySearchField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _service = CountryContextService.instance;

  List<CityResult> _results = [];
  bool _loading = false;
  bool _showDropdown = false;
  Timer? _debounce;
  String? _selectedDisplay;
  int _searchVersion = 0;

  OverlayEntry? _overlayEntry;
  final _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _ctrl.text = widget.initialValue!;
      _selectedDisplay = widget.initialValue;
    }
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(CitySearchField old) {
    super.didUpdateWidget(old);
    // Cascading location fix: a country or region change invalidates the
    // selected city. Clear locally and tell the parent so stale city IDs cannot
    // be saved with a new country/region.
    if (old.countryCode != widget.countryCode ||
        old.regionName != widget.regionName) {
      _clearSelection(notifyParent: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCleared?.call();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    _hideOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (!widget.enabled) return;
    if (_focus.hasFocus) {
      if (_ctrl.text.trim().length >= 2 && !_showDropdown) {
        setState(() {
          _showDropdown = true;
          _showOverlay();
        });
      }
    } else {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && !_focus.hasFocus) {
          setState(() {
            _showDropdown = false;
            _hideOverlay();
          });
        }
      });
    }
  }

  void _onChanged(String value) {
    if (!widget.enabled) return;
    // If value matches selected, don't re-search
    if (value == _selectedDisplay) return;

    // Editing a verified value immediately invalidates its coordinates. The
    // parent must not be allowed to save the previous city while different
    // free text is visible in the field.
    if (_selectedDisplay != null) {
      setState(() => _selectedDisplay = null);
      widget.onCleared?.call();
    }

    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _showDropdown = false;
        _hideOverlay();
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      final version = ++_searchVersion;
      final countryCode = widget.countryCode;
      if (countryCode == null || countryCode.trim().isEmpty) {
        setState(() {
          _results = [];
          _loading = false;
          _showDropdown = false;
          _hideOverlay();
        });
        return;
      }
      setState(() {
        _loading = true;
        _showDropdown = true;
        _showOverlay();
      });

      final results = await _service.searchCities(
        value,
        countryCode: countryCode,
        regionName: widget.regionName,
      );

      if (!mounted || version != _searchVersion) return;
      setState(() {
        _results = results;
        _loading = false;
        if (_showDropdown) {
          _showOverlay();
        }
      });
    });
  }

  void _selectResult(CityResult result) {
    final display = _displayLocation(result);

    setState(() {
      _selectedDisplay = display;
      _showDropdown = false;
      _results = [];
      _hideOverlay();
    });
    _ctrl.value = TextEditingValue(
      text: display,
      selection: TextSelection.collapsed(offset: display.length),
    );
    _focus.unfocus();
    widget.onSelected(result);
  }

  void _clearSelection({bool notifyParent = true}) {
    _searchVersion++;
    _debounce?.cancel();
    _ctrl.clear();
    _selectedDisplay = null;
    _results = [];
    _loading = false;
    _showDropdown = false;
    _hideOverlay();
    if (notifyParent) widget.onCleared?.call();
  }

  void _showOverlay() {
    if (!mounted) return;
    _hideOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final renderBox = this.context.findRenderObject() as RenderBox?;
        final width = renderBox?.size.width ?? 300.0;
        return Positioned(
          width: width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 62),
            child: _buildDropdown(),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        if (widget.label != null) ...[
          UiText(widget.label!, style: AppTypography.sectionLabel),
          const SizedBox(height: 8),
        ],

        // Input field wrapped in composited transform target
        CompositedTransformTarget(
          link: _layerLink,
          child: _buildInput(),
        ),
      ],
    );
  }

  Widget _buildInput() {
    return SilarahFieldFrame(
      focused: _focus.hasFocus,
      enabled: widget.enabled,
      child: TextField(
        enabled: widget.enabled,
        controller: _ctrl,
        focusNode: _focus,
        onChanged: _onChanged,
        onTapOutside: (_) => _focus.unfocus(),
        style: AppTypography.inputText,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: context.uiCopy(widget.hint ?? 'Search city or area'),
          hintStyle: AppTypography.inputLabel,
          prefixIcon: Icon(
            Icons.location_on_outlined,
            color: AppColors.slateMist,
            size: 20,
          ),
          suffixIcon: _loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SilarahPulseLoader(size: 16),
                )
              : _selectedDisplay != null
                  ? GestureDetector(
                      onTap: () => setState(() => _clearSelection()),
                      child: Icon(
                        Icons.close_rounded,
                        color: AppColors.slateMist,
                        size: 18,
                      ),
                    )
                  : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.dropdownSurface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: _loading
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: UiText(
                  context.uiCopy('Searching cities...'),
                  style: AppTypography.bodyMuted,
                ),
              )
            : _results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: UiText(
                      context.uiCopy(
                          'No matching city or area found. Try a different spelling.'),
                      style: AppTypography.bodyMuted,
                    ),
                  )
                : ListView.separated(
                    // Without this the list inherits the status-bar inset
                    // inside the overlay and draws an empty band on top.
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: AppColors.cardBorder,
                    ),
                    itemBuilder: (context, i) {
                      final r = _results[i];
                      return _CityTile(
                        result: r,
                        onTap: () => _selectResult(r),
                      );
                    },
                  ),
      ),
    ).animate().fadeIn(duration: 180.ms).slideY(
          begin: -0.04,
          end: 0,
          duration: 220.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// City result tile
class _CityTile extends StatelessWidget {
  const _CityTile({required this.result, required this.onTap});

  final CityResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (result.state.isNotEmpty &&
          result.state.toLowerCase() != result.city.toLowerCase())
        result.state,
      if (result.postalCode.isNotEmpty) result.postalCode,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.goldGlow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.champagneGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.location_city_rounded,
                color: AppColors.champagneGold,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  UiText(
                    result.city.isNotEmpty ? result.city : result.fullAddress,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    UiText(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.slateMist,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (result.postalCode.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.champagneGold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.champagneGold.withValues(alpha: 0.2),
                  ),
                ),
                child: UiText(
                  result.postalCode,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.champagneGold,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _displayLocation(CityResult result) {
  final parts = <String>[
    if (result.city.isNotEmpty) result.city,
    if (result.state.isNotEmpty &&
        result.state.toLowerCase() != result.city.toLowerCase())
      result.state,
    if (result.city.isEmpty && result.fullAddress.isNotEmpty)
      result.fullAddress,
  ];
  return parts.isNotEmpty ? parts.join(', ') : result.fullAddress;
}
