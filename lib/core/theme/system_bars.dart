import 'package:flutter/services.dart';

/// System bar styling for Silarah's edge-to-edge window.
///
/// Android's MainActivity draws the app behind transparent status and
/// navigation bars, so this style mainly picks icon brightness. Screens keep
/// their content clear of the bars with SafeArea or MediaQuery padding.
///
/// The one colour it sets is a transparent navigation bar. Flutter's
/// MaterialApp pushes `SystemUiOverlayStyle.dark` whenever it builds its
/// theme, and that preset paints the navigation bar opaque black on Android
/// 8-14 (three-button navigation shows it as a black strip). Android 15+
/// ignores bar colours. Status bar and divider colours stay null.
///
/// Apply it through [AnnotatedRegion] at the app root, not only through
/// [SystemChrome]: region styles are re-applied after every frame, so they
/// win over MaterialApp's direct call.
abstract final class SilarahSystemBars {
  /// Dark icons on the light themes, light icons on the dark theme.
  static SystemUiOverlayStyle forDarkTheme(bool isDark) {
    final icons = isDark ? Brightness.light : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarIconBrightness: icons,
      // iOS reads the status bar background brightness, not the icon colour.
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness: icons,
      systemNavigationBarColor: const Color(0x00000000),
      // Without this, Android 10+ paints a translucent scrim behind
      // three-button navigation and covers the app's own bottom bar.
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );
  }

  /// The white launch canvas shown before the saved theme loads.
  static final SystemUiOverlayStyle launch = forDarkTheme(false);
}
