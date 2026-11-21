// SILARAH Design DNA — ThemeData
// Complete palette identities. Zero Material widgets allowed to
// show through — every component uses SILARAH's design language.
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';
import 'system_bars.dart';

abstract final class AppTheme {
  // Identity builder
  static ThemeData forMode(SilarahThemeMode mode) {
    AppColors.activate(mode);
    final brightness = mode.isDark ? Brightness.dark : Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,

      // Color Scheme
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.champagneGold,
        onPrimary: AppColors.obsidianNight,
        secondary: AppColors.verifiedTeal,
        onSecondary: AppColors.obsidianNight,
        error: AppColors.softCoral,
        onError: Colors.white,
        surface: AppColors.surfaceGlass,
        onSurface: AppColors.pearlWhite,
        surfaceContainerHighest: AppColors.surfaceGlassHover,
        outline: AppColors.cardBorder,
        tertiary: AppColors.inkTeal,
        onTertiary: AppColors.pearlWhite,
      ),

      // Scaffold
      scaffoldBackgroundColor: AppColors.obsidianNight,

      // Typography
      textTheme: AppTypography.textTheme,
      fontFamily: 'Inter',

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.obsidianNight,
        foregroundColor: AppColors.pearlWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.wordmark,
        iconTheme: IconThemeData(
          color: AppColors.pearlWhite,
          size: AppDimensions.iconSizeLarge,
        ),
        systemOverlayStyle: SilarahSystemBars.forDarkTheme(mode.isDark),
      ),

      // Eliminate ALL Material ripple/ink effects
      // SILARAH uses scale-based press animations instead.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: AppColors.goldGlow,

      // Icon Theme
      iconTheme: IconThemeData(
        color: AppColors.pearlWhite,
        size: AppDimensions.iconSizeLarge,
      ),

      // ── Elevated Button Theme (for default button overrides)
      // NOTE: Use SilarahPrimaryButton widget directly.
      // This theme is a fallback so any accidentally placed
      // ElevatedButton still looks correct.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.champagneGold,
          foregroundColor: AppColors.obsidianNight,
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          overlayColor: Colors.transparent,
          textStyle: AppTypography.button,
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.champagneGold,
          overlayColor: Colors.transparent,
          textStyle: AppTypography.buttonSecondary,
        ),
      ),

      // Input Decoration Theme
      // Premium: near-transparent fill + crisp outline border.
      // The fill is barely there — just enough to define the field
      // against the background. Borders provide the real definition.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputSurface,
        hintStyle: AppTypography.inputLabel,
        labelStyle: AppTypography.inputLabel,
        floatingLabelStyle: AppTypography.inputLabel.copyWith(
          color: AppColors.champagneGold,
          fontSize: 12,
        ),
        // Rounded outline border — premium, not underline
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          borderSide: BorderSide(
            color: AppColors.cardBorder,
            width: AppDimensions.borderThin,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          borderSide: BorderSide(
            color: AppColors.cardBorder,
            width: AppDimensions.borderThin,
          ),
        ),
        // Focus: refined gold border
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          borderSide: BorderSide(
            color: AppColors.champagneGold,
            width: AppDimensions.borderThin,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          borderSide: BorderSide(
            color: AppColors.softCoral,
            width: AppDimensions.borderThin,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          borderSide: BorderSide(
            color: AppColors.softCoral,
            width: AppDimensions.borderThin,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space16,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.surfaceGlass,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: BorderSide(
            color: AppColors.cardBorder,
            width: AppDimensions.borderThin,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceGlass,
        selectedColor: AppColors.goldGlow,
        labelStyle: AppTypography.chipLabel,
        side: BorderSide(
          color: AppColors.cardBorder,
          width: AppDimensions.borderThin,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space12,
          vertical: AppDimensions.space6,
        ),
        showCheckmark: false,
      ),

      // Navigation Bar Theme (bottom nav)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.obsidianNight,
        indicatorColor: AppColors.goldGlow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.caption.copyWith(
            color: selected ? AppColors.champagneGold : AppColors.slateMist,
            fontSize: 10,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.champagneGold : AppColors.slateMist,
            size: AppDimensions.iconSizeLarge,
          );
        }),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: AppColors.divider,
        thickness: AppDimensions.borderThin,
        space: 0,
      ),

      // Progress Indicator
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.champagneGold,
        linearTrackColor: AppColors.progressBarBase,
      ),

      // Snack Bar — replaced by bottom sheets in SILARAH
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.snackbarSurface,
        contentTextStyle: AppTypography.body.copyWith(
          color: AppColors.onSnackbar,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        ),
        behavior: SnackBarBehavior.floating,
        // Floating messages only avoid Scaffold's own bottom bar. Onboarding
        // Continue buttons and sticky action bars are custom, so lift every
        // message clear of them app-wide instead of per call site.
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceElevated,
        modalBackgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        modalBarrierColor: AppColors.overlayBlack55,
        shadowColor: Colors.black.withValues(alpha: mode.isDark ? .42 : .16),
        showDragHandle: false,
        dragHandleColor: AppColors.slateMist.withValues(alpha: .42),
        dragHandleSize: const Size(38, 4),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusCard),
          ),
          side: BorderSide(color: AppColors.cardBorder),
        ),
      ),

      // Compact confirmations remain visually related to sheet surfaces.
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: mode.isDark ? .46 : .18),
        barrierColor: AppColors.overlayBlack55,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        titleTextStyle: AppTypography.userName,
        contentTextStyle: AppTypography.body,
      ),

      // Page Transitions
      // GoRouter and imperative routes share the same opaque, gesture-aware
      // transition. Never cross-fade complete screens over each other.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SilarahPageTransition(),
          TargetPlatform.iOS: SilarahPageTransition(),
        },
      ),
    );
  }
}

class SilarahPageTransition extends CupertinoPageTransitionsBuilder {
  const SilarahPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;

    return super.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
