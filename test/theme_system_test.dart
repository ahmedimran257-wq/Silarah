import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:silarah/core/cubits/theme/theme_cubit.dart';
import 'package:silarah/core/services/app_lifecycle_service.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/core/theme/app_theme.dart';
import 'package:silarah/core/theme/system_bars.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AppColors.activate(SilarahThemeMode.ivoryEmerald));

  test('theme modes have stable persistence identities', () {
    expect(
      SilarahThemeMode.values.map((mode) => mode.storageValue).toSet(),
      {'rose_marigold', 'oled', 'ivory_emerald'},
    );
    expect(
      SilarahThemeMode.fromStorage('prism_luxe'),
      SilarahThemeMode.oled,
      reason: 'The retired dark identity migrates without a bright flash.',
    );
    expect(
      SilarahThemeMode.fromStorage(null),
      SilarahThemeMode.ivoryEmerald,
      reason: 'A fresh install opens on the brand identity.',
    );
    expect(
      SilarahThemeMode.fromStorage('unknown'),
      SilarahThemeMode.ivoryEmerald,
    );
    expect(
      SilarahThemeMode.fromStorage('obsidian'),
      SilarahThemeMode.ivoryEmerald,
      reason: 'Removed identities migrate safely to the brand identity.',
    );
    expect(
      SilarahThemeMode.fromStorage('black_white'),
      SilarahThemeMode.ivoryEmerald,
      reason: 'Black & White was retired; its members land on Ivory.',
    );
    expect(
      SilarahThemeMode.fromStorage('rose_marigold'),
      SilarahThemeMode.roseMarigold,
    );
    expect(
      SilarahThemeMode.fromStorage('rose'),
      SilarahThemeMode.ivoryEmerald,
    );
    expect(
      SilarahThemeMode.fromStorage('floral_pink'),
      SilarahThemeMode.ivoryEmerald,
    );
    expect(
      SilarahThemeMode.fromStorage('porcelain'),
      SilarahThemeMode.ivoryEmerald,
    );
  });

  test('theme selection applies immediately and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final cubit = ThemeCubit();

    await cubit.applyMode(SilarahThemeMode.ivoryEmerald);
    expect(cubit.state.activeMode, SilarahThemeMode.ivoryEmerald);
    expect(cubit.state.selectedMode, SilarahThemeMode.ivoryEmerald);
    expect(AppColors.active.mode, SilarahThemeMode.ivoryEmerald);
    expect(
      (await SharedPreferences.getInstance())
          .getString(ThemeCubit.preferenceKey),
      'ivory_emerald',
    );
    await cubit.close();

    final restored = ThemeCubit();
    await restored.ready;
    expect(restored.state.activeMode, SilarahThemeMode.ivoryEmerald);
    expect(AppColors.active.mode, SilarahThemeMode.ivoryEmerald);
    await restored.close();
  });

  test('removed saved identities are normalized during load', () async {
    SharedPreferences.setMockInitialValues({
      ThemeCubit.preferenceKey: 'porcelain',
    });
    final cubit = ThemeCubit();
    await cubit.ready;
    expect(cubit.state.activeMode, SilarahThemeMode.ivoryEmerald);
    expect(
      (await SharedPreferences.getInstance())
          .getString(ThemeCubit.preferenceKey),
      'ivory_emerald',
    );
    await cubit.close();
  });

  test('Automatic follows the phone and is saved as its own choice', () async {
    SharedPreferences.setMockInitialValues({});
    final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
    addTearDown(dispatcher.clearPlatformBrightnessTestValue);
    dispatcher.platformBrightnessTestValue = Brightness.light;

    final cubit = ThemeCubit();
    await cubit.applyAutomatic();
    expect(cubit.state.followSystem, isTrue);
    expect(cubit.state.activeMode, SilarahThemeMode.ivoryEmerald);
    expect(
      (await SharedPreferences.getInstance())
          .getString(ThemeCubit.preferenceKey),
      ThemeCubit.automaticStorageValue,
    );

    dispatcher.platformBrightnessTestValue = Brightness.dark;
    expect(cubit.state.activeMode, SilarahThemeMode.oled);
    expect(AppColors.active.mode, SilarahThemeMode.oled);

    await cubit.applyMode(SilarahThemeMode.oled);
    expect(cubit.state.followSystem, isFalse,
        reason: 'Picking a theme by hand stops following the phone.');
    dispatcher.platformBrightnessTestValue = Brightness.light;
    expect(cubit.state.activeMode, SilarahThemeMode.oled);
    await cubit.close();

    SharedPreferences.setMockInitialValues({
      ThemeCubit.preferenceKey: ThemeCubit.automaticStorageValue,
    });
    final restored = ThemeCubit();
    await restored.ready;
    expect(restored.state.followSystem, isTrue);
    expect(restored.state.activeMode, SilarahThemeMode.ivoryEmerald);
    expect(
      (await SharedPreferences.getInstance())
          .getString(ThemeCubit.preferenceKey),
      ThemeCubit.automaticStorageValue,
      reason: 'Loading must not overwrite Automatic with a resolved mode.',
    );
    await restored.close();
  });

  test('preloaded startup theme applies atomically before first frame',
      () async {
    final cubit = ThemeCubit(initialMode: SilarahThemeMode.oled);
    await cubit.ready;
    expect(cubit.state.activeMode, SilarahThemeMode.oled);
    expect(AppColors.active.mode, SilarahThemeMode.oled);
    await cubit.close();
  });

  test('each identity produces the correct Material brightness and canvas', () {
    for (final mode in SilarahThemeMode.values) {
      final palette = SilarahPalette.forMode(mode);
      final theme = AppTheme.forMode(mode);
      expect(
          theme.brightness, mode.isDark ? Brightness.dark : Brightness.light);
      expect(theme.scaffoldBackgroundColor, palette.background);
      expect(theme.colorScheme.primary, palette.accent);
    }
    expect(SilarahThemeMode.roseMarigold.isDark, isFalse);
    expect(
      SilarahPalette.roseMarigold.spectrum.toSet(),
      hasLength(6),
      reason: 'Rose & Marigold keeps six distinct semantic accents.',
    );
    expect(
      SilarahPalette.oled.background,
      const Color(0xFF000000),
      reason: 'Pure OLED must use a literal black canvas.',
    );
    expect(
      SilarahPalette.oled.navBar,
      const Color(0xFF000000),
      reason: 'Pure OLED navigation pixels must also switch off.',
    );
    expect(
      SilarahPalette.ivoryEmerald.background,
      const Color(0xFFF7F3EA),
      reason: 'Ivory & Emerald uses a deliberately warm paper canvas.',
    );
    expect(SilarahThemeMode.ivoryEmerald.isDark, isFalse);
    expect(SilarahThemeMode.ivoryEmerald.isChromatic, isFalse);
    expect(
      SilarahPalette.ivoryEmerald.spectrum.toSet(),
      hasLength(6),
      reason: 'Semantic accents remain distinct without becoming rainbow UI.',
    );
  });

  test('core text and accents meet WCAG AA contrast in every palette', () {
    for (final mode in SilarahThemeMode.values) {
      final palette = SilarahPalette.forMode(mode);
      expect(
        _contrast(palette.contentPrimary, palette.background),
        greaterThanOrEqualTo(4.5),
        reason: '${mode.label} primary content contrast',
      );
      expect(
        _contrast(palette.contentSecondary, palette.background),
        greaterThanOrEqualTo(4.5),
        reason: '${mode.label} secondary content contrast',
      );
      expect(
        _contrast(palette.accent, palette.background),
        greaterThanOrEqualTo(4.5),
        reason: '${mode.label} accent contrast',
      );
      AppColors.activate(mode);
      expect(
        _contrast(AppColors.onSnackbar, palette.snackbar),
        greaterThanOrEqualTo(4.5),
        reason: '${mode.label} snackbar content contrast',
      );
    }
  });

  test('every semantic feedback surface selects WCAG-readable content', () {
    for (final mode in SilarahThemeMode.values) {
      final palette = SilarahPalette.forMode(mode);
      final feedbackSurfaces = <String, Color>{
        'standard snackbar': palette.snackbar,
        'error snackbar': palette.danger,
        'success snackbar': palette.success,
        'interactive snackbar': palette.surfaceInteractive,
        'elevated snackbar': palette.surfaceElevated,
      };

      for (final entry in feedbackSurfaces.entries) {
        final foreground = AppColors.readableOn(entry.value);
        expect(
          foreground,
          anyOf(const Color(0xFF000000), const Color(0xFFFFFFFF)),
          reason: '${mode.label} ${entry.key} uses an absolute neutral',
        );
        expect(
          _contrast(foreground, entry.value),
          greaterThanOrEqualTo(4.5),
          reason: '${mode.label} ${entry.key} content contrast',
        );
      }
    }
  });

  test('photo safety feedback uses its semantic foreground token', () {
    final source = File(
      'lib/features/onboarding/screens/photo_upload_screen.dart',
    ).readAsStringSync();
    expect(
      source,
      contains('AppColors.readableOn(AppColors.softCoral)'),
      reason: 'Photo moderation errors must never inherit page text colour.',
    );
    expect(
      source,
      contains('AppColors.readableOn(AppColors.surfaceGlassHover)'),
      reason: 'Photo status feedback must adapt in light and dark themes.',
    );
  });

  test('Android system chrome never adds a contrast divider artifact', () {
    for (final mode in SilarahThemeMode.values) {
      final overlay = AppTheme.forMode(mode).appBarTheme.systemOverlayStyle;
      expect(overlay?.systemNavigationBarContrastEnforced, isFalse);
      expect(overlay?.systemStatusBarContrastEnforced, isFalse);
    }
    final androidStyles = File(
      'android/app/src/main/res/values/styles.xml',
    ).readAsStringSync();
    expect(androidStyles, contains('android:navigationBarDividerColor'));
    expect(androidStyles, contains('android:enforceNavigationBarContrast'));
  });

  test('system bars are edge-to-edge and transparent', () {
    final styles = [
      SilarahSystemBars.launch,
      for (final mode in SilarahThemeMode.values) ...[
        AppTheme.forMode(mode).appBarTheme.systemOverlayStyle!,
        SilarahSystemBars.forDarkTheme(mode.isDark),
      ],
    ];
    for (final style in styles) {
      // Only the navigation bar gets a colour, and only a transparent one:
      // MaterialApp otherwise leaves it opaque black on Android 8-14.
      expect(style.statusBarColor, isNull);
      expect(style.systemNavigationBarColor, const Color(0x00000000));
      expect(style.systemNavigationBarDividerColor, isNull);
    }
    final mainSource = File('lib/main.dart').readAsStringSync();
    expect(
      'AnnotatedRegion<SystemUiOverlayStyle>'.allMatches(mainSource).length,
      2,
      reason: 'Launch and app roots must override MaterialApp bar defaults.',
    );
    for (final mode in SilarahThemeMode.values) {
      final style = AppTheme.forMode(mode).appBarTheme.systemOverlayStyle!;
      final icons = mode.isDark ? Brightness.light : Brightness.dark;
      expect(style.statusBarIconBrightness, icons, reason: mode.name);
      expect(style.systemNavigationBarIconBrightness, icons, reason: mode.name);
    }
    expect(SilarahSystemBars.launch.statusBarIconBrightness, Brightness.dark);

    final activity = File(
      'android/app/src/main/kotlin/com/silarah/app/MainActivity.kt',
    ).readAsStringSync();
    expect(activity, contains('WindowCompat.enableEdgeToEdge(window)'));
    for (final deprecated in [
      'setStatusBarColor',
      'setNavigationBarColor',
      'setNavigationBarDividerColor',
      'statusBarColor =',
      'navigationBarColor =',
    ]) {
      expect(activity, isNot(contains(deprecated)), reason: deprecated);
    }
    for (final dir in ['values', 'values-night']) {
      final xml =
          File('android/app/src/main/res/$dir/styles.xml').readAsStringSync();
      final normalTheme = xml.substring(xml.indexOf('name="NormalTheme"'));
      expect(normalTheme, isNot(contains('android:statusBarColor')));
      expect(normalTheme, isNot(contains('android:navigationBarColor')));
    }
  });

  test('launch sequence is white-first and uses one complete wordmark', () {
    final revealSource = File(
      'lib/core/widgets/silarah_launch_sequence.dart',
    ).readAsStringSync();
    expect(
      Directory('android/app/src/main/res')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('silarah_splash_mark.png')),
      isEmpty,
      reason: 'No separate legacy splash artwork may return.',
    );
    expect(revealSource, contains('Duration(milliseconds: 1250)'));
    expect(revealSource, contains('_wordTracking'));
    expect(revealSource, contains("'Silarah'"));
    expect(revealSource, contains("'السلام عليكم'"));
    expect(revealSource, contains('alpha: .58'));
    expect(
      revealSource,
      contains('WidgetsBinding.instance.addPostFrameCallback'),
      reason: 'Brand motion must start after the native launch hand-off.',
    );
    expect(revealSource, contains('final bool play'));
    expect(revealSource, contains('if (!widget.play'));
    expect(revealSource, isNot(contains('_departureOpacity')));
    expect(revealSource, contains('_BrandBloomPainter'));
    expect(revealSource, isNot(contains('silarah_liquid_mark.png')));
    expect(revealSource, isNot(contains("Text(\n          'ilarah'")));
    expect(revealSource, contains('AppColors.obsidianNight'));
    expect(revealSource, isNot(contains('SvgPicture')));
    expect(revealSource, isNot(contains('VideoPlayerController')));
    expect(revealSource, isNot(contains('Timer(')));
    expect(revealSource, isNot(contains('_exitOpacity')));
    expect(revealSource.toLowerCase(), isNot(contains('sparkle')));
    expect(
      File('lib/core/widgets/startup_brand_reveal.dart').existsSync(),
      isFalse,
    );

    final mainSource = File('lib/main.dart').readAsStringSync();
    expect(mainSource, contains('SilarahLaunchSequence'));
    final mainEntryPoint = mainSource.indexOf('void main()');
    expect(
      mainSource.indexOf('runApp('),
      lessThan(mainSource.indexOf('Firebase.initializeApp(', mainEntryPoint)),
      reason: 'Core SDK startup must not hold Android\'s static splash.',
    );
    expect(mainSource, isNot(contains('precacheImage(')));
    expect(
      mainSource,
      isNot(contains('deferFirstFrame')),
      reason: 'Flutter must replace the native surface without a dead frame.',
    );
    expect(mainSource, isNot(contains('endOfFrame')));
    expect(mainSource, isNot(contains('allowFirstFrame')));
    expect(mainSource, isNot(contains('_launchMayAnimate')));
    expect(mainSource, isNot(contains('firstPresentedFrame')));

    for (final stylePath in [
      'android/app/src/main/res/values/styles.xml',
      'android/app/src/main/res/values-night/styles.xml',
    ]) {
      final source = File(stylePath).readAsStringSync();
      expect(source, isNot(contains('?android:colorBackground')));
      expect(source, contains('@color/launch_background'));
      expect(source, contains('@drawable/launch_background'));
      expect(source, contains('#FFFFFF'));
    }
    for (final launchPath in [
      'android/app/src/main/res/drawable/launch_background.xml',
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ]) {
      expect(
        File(launchPath).readAsStringSync(),
        contains('@drawable/ic_launcher_foreground'),
        reason:
            'Cold engine startup must show the static brand, not blank white.',
      );
    }
    for (final stylePath in [
      'android/app/src/main/res/values-v31/styles.xml',
      'android/app/src/main/res/values-night-v31/styles.xml',
    ]) {
      final source = File(stylePath).readAsStringSync();
      expect(
        source,
        contains('android:windowSplashScreenAnimationDuration">0'),
        reason: 'Android must not insert a second native icon fade.',
      );
      expect(
        source,
        contains(
          'android:windowSplashScreenAnimatedIcon">'
          '@drawable/ic_launcher_foreground',
        ),
      );
    }
    final iosLaunch = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();
    expect(iosLaunch, contains('red="1" green="1" blue="1"'));
    expect(iosLaunch, isNot(contains('green="0.1803921569"')));
    expect(iosLaunch, isNot(contains('LaunchImage')));
    expect(
      Directory('ios/Runner/Assets.xcassets/LaunchImage.imageset').existsSync(),
      isFalse,
    );

    final routerSource =
        File('lib/core/router/app_router.dart').readAsStringSync();
    expect(routerSource, isNot(contains('AssalamAnimationScreen')));
    expect(
      File('lib/features/onboarding/screens/assalam_animation_screen.dart')
          .existsSync(),
      isFalse,
    );
  });

  test('adaptive launcher foreground is high-resolution and transparent',
      () async {
    final masterBytes =
        File('assets/icon/app_icon_foreground.png').readAsBytesSync();
    final masterCodec = await ui.instantiateImageCodec(masterBytes);
    final masterFrame = await masterCodec.getNextFrame();
    final master = masterFrame.image;
    expect(master.width, 1024);
    expect(master.height, 1024);
    final rgba = await master.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(rgba, isNotNull);
    expect(
      rgba!.getUint8(3),
      0,
      reason: 'The adaptive foreground must have a transparent corner.',
    );
    master.dispose();
    masterCodec.dispose();
  });

  test('website-matched launcher uses a dedicated adaptive foreground',
      () async {
    final launcher = File('assets/icon/app_icon.png');
    expect(launcher.existsSync(), isTrue);
    expect(File('assets/icon/app_icon_foreground.png').existsSync(), isTrue);

    final codec = await ui.instantiateImageCodec(launcher.readAsBytesSync());
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 1024);
    expect(frame.image.height, 1024);
    frame.image.dispose();
    codec.dispose();

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      RegExp(
        r'adaptive_icon_foreground:\s*"assets/icon/app_icon_foreground\.png"',
      ).hasMatch(pubspec),
      isTrue,
    );
    expect(pubspec, contains('adaptive_icon_background: "#FFFFFF"'));
  });

  test('native restart bridge remains available but appearance is live',
      () async {
    const channel = MethodChannel('com.silarah.app/app_lifecycle');
    final methods = <String>[];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return true;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    expect(AppLifecycleService.supportsInPlaceRestart, isTrue);
    expect(await AppLifecycleService.restartNow(), isTrue);
    expect(methods, ['restartApp']);

    final settings = File(
      'lib/features/home/screens/settings_screen.dart',
    ).readAsStringSync();
    final nativeHost = File(
      'android/app/src/main/kotlin/com/silarah/app/MainActivity.kt',
    ).readAsStringSync();
    expect(settings, isNot(contains("Text('Restart now')")));
    expect(settings, contains('applyMode(mode)'));
    expect(settings, contains('settings_theme_applied'));
    expect(
      File('lib/l10n/app_en.arb').readAsStringSync(),
      contains('Applied instantly'),
    );
    expect(nativeHost, contains('Intent.FLAG_ACTIVITY_CLEAR_TASK'));
    expect(nativeHost, contains('finishAffinity()'));
    expect(nativeHost, contains('setOnExitAnimationListener'));
    expect(nativeHost, contains('splashView.remove()'));
  });
}

double _contrast(Color foreground, Color background) {
  final light = _luminance(foreground);
  final dark = _luminance(background);
  final lighter = light > dark ? light : dark;
  final darker = light > dark ? dark : light;
  return (lighter + .05) / (darker + .05);
}

double _luminance(Color color) {
  double channel(double value) => value <= .04045
      ? value / 12.92
      : math.pow((value + .055) / 1.055, 2.4).toDouble();
  return .2126 * channel(color.r) +
      .7152 * channel(color.g) +
      .0722 * channel(color.b);
}
