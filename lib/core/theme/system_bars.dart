import 'package:flutter/services.dart';

/// System bar styling for Silarah's edge-to-edge window.
///
/// Android's MainActivity draws the app behind transparent status and
/// navigation bars, so this style only picks icon brightness. It never sets a
/// bar colour: Android 15 deprecated the Window bar-colour setters and ignores
/// them, and leaving every colour null keeps Flutter from calling them on
/// older Android versions. Screens keep their content clear of the bars with
/// SafeArea or MediaQuery padding instead.
abstract final class SilarahSystemBars {
  /// Dark icons on the light themes, light icons on the dark theme.
  static SystemUiOverlayStyle forDarkTheme(bool isDark) {
    final icons = isDark ? Brightness.light : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarIconBrightness: icons,
      // iOS reads the status bar background brightness, not the icon colour.
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness: icons,
      // Without this, Android 10+ paints a translucent scrim behind
      // three-button navigation and covers the app's own bottom bar.
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );
  }

  /// The white launch canvas shown before the saved theme loads.
  static final SystemUiOverlayStyle launch = forDarkTheme(false);
}
