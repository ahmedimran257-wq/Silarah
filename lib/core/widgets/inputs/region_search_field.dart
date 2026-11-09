// SILARAH - Region Search Field
//
// Async country-scoped region/state search backed by Supabase `regions`.
// This is an optional narrowing step before city search; it never fabricates
// a region, so unsupported countries still continue via verified city search.
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

class RegionSearchField extends StatefulWidget {
  const RegionSearchField({
    super.key,
    required this.countryCode,
    required this.onSelected,
    this.onCleared,
    this.initialValue,
    this.hint,
    this.enabled = true,
  });

  final String? countryCode;
  final ValueChanged<RegionResult> onSelected;
  final VoidCallback? onCleared;
  final String? initialValue;
  final String? hint;
  final bool enabled;

  @override
  State<RegionSearchField> createState() => _RegionSearchFieldState();
}

class _RegionSearchFieldState extends State<RegionSearchField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _service = CountryContextService.instance;
  final _layerLink = LayerLink();

  Timer? _debounce;
  OverlayEntry? _overlayEntry;
  List<RegionResult> _results = [];
  bool _loading = false;
  bool _showDropdown = false;
  String? _selectedDisplay;
  int _searchVersion = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue?.trim();
    if (initial != null && initial.isNotEmpty) {
      _ctrl.text = initial;
      _selectedDisplay = initial;
    }
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant RegionSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countryCode != widget.countryCode) {
      _clearSelection(notifyParent: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCleared?.call();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _hideOverlay();
    _ctrl.dispose();
    _focus.dispose();
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
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (!mounted || _focus.hasFocus) return;
      setState(() {
        _showDropdown = false;
        _hideOverlay();
      });
    });
  }

  void _onChanged(String value) {
    if (!widget.enabled) return;
    if (value == _selectedDisplay) return;

    // A typed edit is not a verified region selection. Invalidate the parent
    // selection immediately so its city and coordinates cannot remain stale.
    if (_selectedDisplay != null) {
      setState(() => _selectedDisplay = null);
      widget.onCleared?.call();
    }

    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _results = [];
        _loading = false;
        _showDropdown = false;
        _hideOverlay();
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      final countryCode = widget.countryCode;
      if (countryCode == null || countryCode.trim().isEmpty) return;
      final version = ++_searchVersion;
      setState(() {
        _loading = true;
        _showDropdown = true;
        _showOverlay();
      });

      final results = await _service.searchRegions(
        query,
        countryCode: countryCode,
      );

      if (!mounted || version != _searchVersion) return;
      setState(() {
        _results = results;
        _loading = false;
        if (_showDropdown) _showOverlay();
      });
    });
  }

  void _select(RegionResult result) {
    setState(() {
      _selectedDisplay = result.name;
      _results = [];
      _showDropdown = false;
      _hideOverlay();
    });
    _ctrl.value = TextEditingValue(
      text: result.name,
      selection: TextSelection.collapsed(offset: result.name.length),
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
      builder: (_) {
        final renderBox = context.findRenderObject() as RenderBox?;
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
    return CompositedTransformTarget(
      link: _layerLink,
      child: SilarahFieldFrame(
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
            hintText: context.uiCopy(widget.hint ?? 'Search state or region'),
            hintStyle: AppTypography.inputLabel,
            prefixIcon: Icon(
              Icons.map_outlined,
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
      ),
    );
  }

  Widget _buildDropdown() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
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
                  context.uiCopy('Searching regions...'),
                  style: AppTypography.bodyMuted,
                ),
              )
            : _results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: UiText(
                      context.uiCopy(
                          'No matching region found. You can search city or area below.'),
                      style: AppTypography.bodyMuted,
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: AppColors.cardBorder,
                    ),
                    itemBuilder: (_, index) {
                      final region = _results[index];
                      return InkWell(
                        onTap: () => _select(region),
                        splashColor: AppColors.goldGlow,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.champagneGold
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.map_rounded,
                                  color: AppColors.champagneGold,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: UiText(
                                  region.name,
                                  style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
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
