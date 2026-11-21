import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/system_bars.dart';

/// Owns the active visual identity and persists it locally. Theme selection is
/// deliberately device-scoped: it applies before authentication and never
/// causes a profile write or network request.
class ThemeSelectionState {
  const ThemeSelectionState({
    required this.activeMode,
    this.followSystem = false,
  });

  final SilarahThemeMode activeMode;

  /// True when the member chose Automatic: the identity tracks the phone's
  /// light or dark setting (Ivory & Emerald by day, Pure OLED by night).
  final bool followSystem;

  SilarahThemeMode get selectedMode => activeMode;
}

class ThemeCubit extends Cubit<ThemeSelectionState> {
  ThemeCubit({SilarahThemeMode? initialMode, bool followSystem = false})
      : super(ThemeSelectionState(
          activeMode: followSystem
              ? systemMode()
              : initialMode ?? SilarahThemeMode.ivoryEmerald,
          followSystem: followSystem,
        )) {
    _applySystemIdentity(state.activeMode);
    if (followSystem) _watchPlatformBrightness();
    _ready =
        initialMode == null && !followSystem ? _load() : Future<void>.value();
  }

  static const preferenceKey = 'silarah_theme_mode';

  /// Stored instead of a mode when the member picks Automatic.
  static const automaticStorageValue = 'automatic';

  late final Future<void> _ready;
  _PlatformBrightnessObserver? _brightnessObserver;

  Future<void> get ready => _ready;

  /// The identity Automatic resolves to for the phone's current setting.
  static SilarahThemeMode systemMode() =>
      (_binding?.platformDispatcher ?? PlatformDispatcher.instance)
                  .platformBrightness ==
              Brightness.dark
          ? SilarahThemeMode.oled
          : SilarahThemeMode.ivoryEmerald;

  static WidgetsBinding? get _binding {
    try {
      return WidgetsBinding.instance;
    } catch (_) {
      // Plain unit tests run without a binding.
      return null;
    }
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(preferenceKey);
    if (stored == automaticStorageValue) {
      if (isClosed) return;
      _watchPlatformBrightness();
      final mode = systemMode();
      _applySystemIdentity(mode);
      emit(ThemeSelectionState(activeMode: mode, followSystem: true));
      return;
    }
    final mode = SilarahThemeMode.fromStorage(stored);
    if (stored != mode.storageValue) {
      await preferences.setString(preferenceKey, mode.storageValue);
    }
    if (isClosed) return;
    _applySystemIdentity(mode);
    emit(ThemeSelectionState(activeMode: mode));
  }

  /// Applies and persists a complete identity in the current frame.
  Future<void> applyMode(SilarahThemeMode mode) async {
    await _ready;
    if (isClosed || (!state.followSystem && mode == state.activeMode)) return;
    _stopWatchingPlatformBrightness();
    _applySystemIdentity(mode);
    emit(ThemeSelectionState(activeMode: mode));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(preferenceKey, mode.storageValue);
  }

  /// Follows the phone's light or dark setting from now on, live.
  Future<void> applyAutomatic() async {
    await _ready;
    if (isClosed || state.followSystem) return;
    _watchPlatformBrightness();
    final mode = systemMode();
    _applySystemIdentity(mode);
    emit(ThemeSelectionState(activeMode: mode, followSystem: true));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(preferenceKey, automaticStorageValue);
  }

  void _onPlatformBrightnessChanged() {
    if (isClosed || !state.followSystem) return;
    final mode = systemMode();
    if (mode == state.activeMode) return;
    _applySystemIdentity(mode);
    emit(ThemeSelectionState(activeMode: mode, followSystem: true));
  }

  // Observers stack with other listeners, unlike assigning
  // PlatformDispatcher.onPlatformBrightnessChanged, which the framework owns.
  void _watchPlatformBrightness() {
    if (_brightnessObserver != null) return;
    final binding = _binding;
    if (binding == null) return;
    final observer = _PlatformBrightnessObserver(_onPlatformBrightnessChanged);
    binding.addObserver(observer);
    _brightnessObserver = observer;
  }

  void _stopWatchingPlatformBrightness() {
    final observer = _brightnessObserver;
    if (observer == null) return;
    WidgetsBinding.instance.removeObserver(observer);
    _brightnessObserver = null;
  }

  @override
  Future<void> close() {
    _stopWatchingPlatformBrightness();
    return super.close();
  }

  static void _applySystemIdentity(SilarahThemeMode mode) {
    AppColors.activate(mode);
    SystemChrome.setSystemUIOverlayStyle(
      SilarahSystemBars.forDarkTheme(mode.isDark),
    );
  }

}

class _PlatformBrightnessObserver with WidgetsBindingObserver {
  _PlatformBrightnessObserver(this.onChanged);

  final VoidCallback onChanged;

  @override
  void didChangePlatformBrightness() => onChanged();
}
