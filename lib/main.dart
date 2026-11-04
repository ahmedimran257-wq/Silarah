// Silarah — Entry Point
// "Begin with bismillah"
// Step 4: GoRouter + MultiBlocProvider wired up.
//         Auth-gated routing with Supabase email OTP.
import 'core/utils/perf_log.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/app_config.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_dimensions.dart';
import 'core/services/supabase_service.dart';
import 'core/services/my_account_snapshot.dart';
import 'core/services/operational_telemetry_service.dart';
import 'core/utils/expected_error.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/subscription_service.dart';
import 'core/services/wali_mode_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/presence_service.dart';
import 'core/services/bookmark_service.dart';
import 'core/services/compatibility_service.dart';
import 'core/services/incognito_service.dart';
import 'core/services/shortlist_service.dart';
import 'core/services/filter_preset_service.dart';
import 'core/services/legal_consent_service.dart';
import 'core/services/auth_callback_service.dart';
import 'core/services/referral_service.dart';
import 'core/cubits/auth/auth_cubit.dart';
import 'core/cubits/auth/auth_state.dart';
import 'core/cubits/onboarding/onboarding_cubit.dart';
import 'core/cubits/interests/interests_cubit.dart';
import 'core/cubits/discovery/discovery_feed_cubit.dart';
import 'core/cubits/chat/chat_cubit.dart';
import 'core/cubits/subscription/subscription_cubit.dart';
import 'core/cubits/subscription/subscription_state.dart';
import 'core/cubits/notification_prefs/notification_prefs_cubit.dart';
import 'core/cubits/block_report/block_report_cubit.dart';
import 'core/cubits/notifications/notifications_cubit.dart';
import 'core/cubits/locale/locale_cubit.dart';
import 'core/cubits/theme/theme_cubit.dart';
import 'core/theme/app_colors.dart';
import 'core/cubits/account_standing/account_standing_cubit.dart';
import 'core/router/app_router.dart';
import 'core/router/notification_navigation.dart';
import 'core/widgets/in_app_notification_banner.dart';
import 'core/widgets/startup_offline_screen.dart';
import 'core/widgets/silarah_launch_sequence.dart';
import 'l10n/generated/app_localizations.dart';

const _rtlLocales = {'ar', 'ur'};

enum _StartupNetworkState { checking, offline, ready }

enum _BootstrapStage { loading, ready, failed }

final ValueNotifier<_BootstrapStage> _bootstrapStage =
    ValueNotifier(_BootstrapStage.loading);
String _bootstrapInitialLocation = AppRoutes.boot;
SilarahThemeMode _bootstrapInitialTheme = SilarahThemeMode.ivoryEmerald;
bool _bootstrapFollowSystemTheme = false;

/// Firebase launches this callback in a separate Dart isolate for background
/// data messages. Android renders notification payloads itself, so the handler
/// intentionally performs no UI work and cannot create duplicate banners.
@pragma('vm:entry-point')
Future<void> silarahFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp();
}

Future<void> _activateFirebaseAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
      appleProvider:
          kReleaseMode ? AppleProvider.appAttest : AppleProvider.debug,
    );
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  } catch (error, stack) {
    // App Check is intentionally monitor-only until genuine Play/App Store
    // release traffic has been verified. A provider-registration outage must
    // not brick an otherwise correctly configured native application. Once
    // enforcement is enabled, protected backends still fail closed.
    debugPrint('[main] App Check activation deferred: $error\n$stack');
  }
}

/// Installs crash reporting the moment Firebase is ready, before Supabase and
/// the auth callback start, so failures in the rest of startup still reach
/// Crashlytics. Debug sessions keep collection off so the release dashboard
/// only shows real device crashes.
Future<void> _installCrashReporting() async {
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);

  // Catch Flutter framework errors → forward to Crashlytics
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    final exceptionText = details.exceptionAsString();
    debugPrint('Flutter Error: $exceptionText');
    final expected = expectedErrorCode(details.exception);
    if (expected != null) {
      OperationalTelemetryService.record('uncaught', expected);
      return;
    }
    final isLayoutOverflow = exceptionText.contains('RenderFlex overflowed');
    FirebaseCrashlytics.instance.recordFlutterError(
      details,
      fatal: !isLayoutOverflow,
    );
  };

  // Catch async errors not caught by Flutter framework → forward to Crashlytics.
  // Offline moments and ended logins are expected and recovered from, so they
  // are recorded as rate-limited non-fatal codes, not crashes.
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Async Error: $error\n$stack');
    final expected = expectedErrorCode(error);
    if (expected != null) {
      OperationalTelemetryService.record('uncaught', expected);
    } else {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true; // Prevent app crash
  };
}

void main() async {
  perfStart();
  WidgetsFlutterBinding.ensureInitialized();
  // Flutter Inspector paint toggles can persist for the lifetime of a debug
  // process and draw colored text baselines over otherwise-correct UI. Always
  // start every flavor from a clean render surface; release builds keep these
  // disabled as an additional distribution safeguard.
  debugPaintSizeEnabled = false;
  debugPaintBaselinesEnabled = false;
  debugPaintPointersEnabled = false;
  debugPaintLayerBordersEnabled = false;
  debugRepaintRainbowEnabled = false;
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    FirebaseMessaging.onBackgroundMessage(
      silarahFirebaseMessagingBackgroundHandler,
    );
  }
  final startupStartedAt = DateTime.now();

  // Give Flutter ownership of the screen immediately. The launch sequence
  // schedules its motion after this first frame, while preferences, Firebase
  // and Supabase initialize behind the continuous brand surface.
  runApp(
    _SilarahBootstrap(
      startupStartedAt: startupStartedAt,
    ),
  );

  // Firebase Initialization
  try {
    final startupDependencies = await Future.wait<Object>([
      SharedPreferences.getInstance(),
      // Android and iOS load their reviewed Firebase configuration from the
      // native files bundled into the signed app. The release build scripts
      // verify those files against config/prod.local.json before compilation.
      Firebase.initializeApp(),
    ]);
    perfMark('startup: prefs and firebase');
    final prefs = startupDependencies.first as SharedPreferences;
    await _installCrashReporting();
    await _activateFirebaseAppCheck();
    final introCompleted = prefs.getBool('silarah_intro_completed') ?? false;
    _bootstrapInitialLocation =
        introCompleted ? AppRoutes.boot : AppRoutes.languageSelect;
    final storedTheme = prefs.getString(ThemeCubit.preferenceKey);
    _bootstrapFollowSystemTheme =
        storedTheme == ThemeCubit.automaticStorageValue;
    _bootstrapInitialTheme = _bootstrapFollowSystemTheme
        ? ThemeCubit.systemMode()
        : SilarahThemeMode.fromStorage(storedTheme);
    if (!_bootstrapFollowSystemTheme &&
        storedTheme != _bootstrapInitialTheme.storageValue) {
      await prefs.setString(
        ThemeCubit.preferenceKey,
        _bootstrapInitialTheme.storageValue,
      );
    }

    // Supabase Initialization
    // Initialize Supabase client
    perfMark('startup: crash reporting, app check, theme');
    await SupabaseService.initialize();
    perfMark('startup: supabase');
    await AuthCallbackService.instance.initialize();
  } catch (error, stack) {
    debugPrint('[main] Critical startup configuration error: $error\n$stack');
    _bootstrapStage.value = _BootstrapStage.failed;
    return;
  }

  // Replace the ugly red error screen with a styled fallback
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 160 || constraints.maxWidth < 160;
        if (compact) {
          return const ColoredBox(
            color: Color(0xFFFFFFFF),
            child: Center(
              child: Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFB32645),
                size: 20,
              ),
            ),
          );
        }

        return const Material(
          color: Color(0xFFFFFFFF),
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: Color(0xFFB32645), size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: TextStyle(
                      color: Color(0xFF21151A),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This screen update was interrupted. Go back once and reopen it.',
                    style: TextStyle(
                      color: Color(0xFF665A60),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  };

  // Status bar: transparent, dark icons on the signature white canvas.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFFFFFFFF),
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));

  unawaited(SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]));

  _bootstrapStage.value = _BootstrapStage.ready;
}

class _SilarahBootstrap extends StatefulWidget {
  const _SilarahBootstrap({
    required this.startupStartedAt,
  });

  final DateTime startupStartedAt;

  @override
  State<_SilarahBootstrap> createState() => _SilarahBootstrapState();
}

class _SilarahBootstrapState extends State<_SilarahBootstrap> {
  bool _brandRevealCompleted = false;
  bool _startupGateResolved = false;

  void _completeBrandReveal() {
    if (_brandRevealCompleted || !mounted) return;
    setState(() => _brandRevealCompleted = true);
  }

  void _resolveStartupGate() {
    if (_startupGateResolved || !mounted) return;
    setState(() => _startupGateResolved = true);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_BootstrapStage>(
      valueListenable: _bootstrapStage,
      builder: (context, stage, _) {
        final destinationReady = switch (stage) {
          _BootstrapStage.loading => false,
          _BootstrapStage.ready => _startupGateResolved,
          _BootstrapStage.failed => true,
        };
        final keepBrandLayer = !_brandRevealCompleted || !destinationReady;

        return ColoredBox(
          color: SilarahLaunchSequence.surface,
          child: Stack(
            textDirection: TextDirection.ltr,
            children: [
              Positioned.fill(
                child: switch (stage) {
                  _BootstrapStage.loading => ColoredBox(
                      color: SilarahLaunchSequence.surface,
                    ),
                  _BootstrapStage.ready => SilarahApp(
                      initialLocation: _bootstrapInitialLocation,
                      initialTheme: _bootstrapInitialTheme,
                      followSystemTheme: _bootstrapFollowSystemTheme,
                      startupStartedAt: widget.startupStartedAt,
                      onStartupGateResolved: _resolveStartupGate,
                    ),
                  _BootstrapStage.failed => const _StartupFailureApp(),
                },
              ),
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child: keepBrandLayer
                      ? MaterialApp(
                          key: const ValueKey('startup-brand-layer'),
                          color: SilarahLaunchSequence.surface,
                          debugShowCheckedModeBanner: false,
                          theme: AppTheme.forMode(_bootstrapInitialTheme),
                          home: SilarahLaunchSequence(
                            onCompleted: _completeBrandReveal,
                          ),
                        )
                      : const SizedBox.expand(
                          key: ValueKey('startup-destination-layer'),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFFFFFFFF),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.settings_rounded,
                    color: Color(0xFFAD285A),
                    size: 52,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Silarah could not start',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF21151A),
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'This build is missing required service configuration. '
                    'Please reinstall it using the approved build script.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _configureRevenueCat() async {
  // Test Store is deliberately restricted to debug builds. Release builds
  // always use the platform store key and can never grant test entitlements.
  final platformKey = Platform.isIOS
      ? AppConfig.revenueCatIosKey
      : AppConfig.revenueCatAndroidKey;
  final rcKey = kDebugMode && AppConfig.revenueCatTestKey.isNotEmpty
      ? AppConfig.revenueCatTestKey
      : platformKey;
  if (rcKey.isEmpty) return;
  try {
    if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(PurchasesConfiguration(rcKey));
  } catch (e) {
    debugPrint('[main] RevenueCat configure skipped: $e');
  }
}

class SilarahApp extends StatefulWidget {
  const SilarahApp({
    super.key,
    required this.initialLocation,
    this.startupStartedAt,
    this.initialTheme = SilarahThemeMode.ivoryEmerald,
    this.followSystemTheme = false,
    this.onStartupGateResolved,
  });

  final String initialLocation;
  final DateTime? startupStartedAt;
  final SilarahThemeMode initialTheme;
  final bool followSystemTheme;
  final VoidCallback? onStartupGateResolved;

  @override
  State<SilarahApp> createState() => _SilarahAppState();
}

class _SilarahAppState extends State<SilarahApp> with WidgetsBindingObserver {
  /// Guard: ensures onboarding cubit is initialized only once per auth session.
  /// Without this, every updateOnboardingStep() call re-triggers the
  /// BlocListener which calls initialize() and wipes all accumulated form data.
  bool _onboardingInitialized = false;
  String? _activeSessionUserId;
  String? _onboardingPublicationSyncedUserId;
  late final DateTime _startupStartedAt =
      widget.startupStartedAt ?? DateTime.now();

  // Create cubits at the top level so they outlive any individual screen.
  late final AuthCubit _authCubit;
  late final OnboardingCubit _onboardingCubit;
  late final InterestsCubit _interestsCubit;
  late final BlockReportCubit _blockReportCubit;
  late final DiscoveryFeedCubit _discoveryFeedCubit;
  late final ChatCubit _chatCubit;
  late final SubscriptionCubit _subscriptionCubit;
  late final NotificationPrefsCubit _notificationPrefsCubit;
  late final NotificationsCubit _notificationsCubit;
  late final LocaleCubit _localeCubit;
  late final ThemeCubit _themeCubit;
  late final AccountStandingCubit _accountStandingCubit;

  late final GoRouter _router;
  late final Future<void> _revenueCatReady;
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<NotificationItem>? _notificationRefreshSubscription;
  StreamSubscription<SubscriptionState>? _entitlementRefreshSubscription;
  ConnectivityService? _connectivityService;
  _StartupNetworkState _startupNetworkState = _StartupNetworkState.checking;
  BackendConnectionQuality _startupConnectionQuality =
      BackendConnectionQuality.unknown;
  Future<bool>? _startupRecoveryInFlight;
  bool _startupGateReported = false;

  void _reportStartupGateResolved() {
    if (_startupGateReported) return;
    _startupGateReported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onStartupGateResolved?.call();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authCubit = AuthCubit();
    _onboardingCubit = OnboardingCubit(authCubit: _authCubit);
    _interestsCubit = InterestsCubit();
    _blockReportCubit = BlockReportCubit();
    _discoveryFeedCubit = DiscoveryFeedCubit();
    _chatCubit = ChatCubit();
    _subscriptionCubit = SubscriptionCubit();
    _notificationPrefsCubit = NotificationPrefsCubit();
    _notificationsCubit = NotificationsCubit();
    _localeCubit = LocaleCubit();
    _themeCubit = ThemeCubit(
      initialMode: widget.initialTheme,
      followSystem: widget.followSystemTheme,
    );
    _accountStandingCubit = AccountStandingCubit();

    var entitlementFingerprint =
        _entitlementFingerprint(_subscriptionCubit.state);
    _entitlementRefreshSubscription = _subscriptionCubit.stream.listen((next) {
      final nextFingerprint = _entitlementFingerprint(next);
      if (nextFingerprint == entitlementFingerprint) return;
      entitlementFingerprint = nextFingerprint;
      if (_activeSessionUserId != null) {
        unawaited(_reconcileEntitlementDependents());
      }
    });

    _notificationRefreshSubscription =
        _notificationsCubit.inAppNotifications.listen((item) {
      if (item.type == 'new_message') {
        _chatCubit.scheduleInboxReconciliation();
      }
      if (item.type == 'interest_received' ||
          item.type == 'interest_accepted' ||
          item.type == 'match' ||
          item.type == 'match_accepted') {
        unawaited(_interestsCubit.refreshIfChanged(forceCheck: true));
      }
      if (item.type == 'match_ended') {
        unawaited(_chatCubit.refreshIfChanged(forceCheck: true));
        unawaited(_interestsCubit.refreshIfChanged(forceCheck: true));
        unawaited(_discoveryFeedCubit.refreshIfChanged(forceCheck: true));
      }
      if (item.type == 'new_compatible_profiles') {
        unawaited(_discoveryFeedCubit.refreshIfChanged(forceCheck: true));
      }
      if (item.type == 'referral_reward') {
        unawaited(_refreshPremiumEntitlement(refreshDiscovery: true));
      }
    });

    _router =
        buildAppRouter(_authCubit, initialLocation: widget.initialLocation);

    // Wire up FCM tap navigation callback
    FcmService.instance.onNotificationTap = (path) {
      if (_opensInterestInbox(path)) {
        unawaited(_interestsCubit.refreshIfChanged(forceCheck: true));
      }
      if (_opensChat(path)) {
        _chatCubit.scheduleInboxReconciliation();
      }
      navigateFromPushNotification(_router, path);
    };
    FcmService.instance.onForegroundMessage = (message) {
      final deepLink = message.data['deep_link']?.toString();
      // The open chat already shows the new message live; skip the banner.
      if (_chatCubit.isViewingConversationLink(deepLink)) {
        unawaited(_notificationsCubit.loadNotifications(force: true));
        return;
      }
      _notificationsCubit.reconcileForegroundPush(
        type: message.data['type']?.toString() ?? 'general',
        notificationId: message.data['notification_id']?.toString(),
        title: message.notification?.title,
        body: message.notification?.body,
        deepLink: message.data['deep_link']?.toString(),
      );
    };

    _revenueCatReady = _configureRevenueCat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPostFirstFrameWork();
    });
  }

  void _startPostFirstFrameWork() {
    final connectivity = ConnectivityService.initialize(
      checkInterval: const Duration(minutes: 5),
    );
    _connectivityService = connectivity;
    _connectivitySubscription = connectivity.connectivityStream.listen(
      _handleConnectivityChange,
    );
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      unawaited(_recoverStartupIdentity());
    } else {
      unawaited(_resolveStartupConnectivity());
    }
    unawaited(_revenueCatReady.then((_) => _subscriptionCubit.initialize()));
    // Widget tests run without a native Firebase app. Production still
    // initializes FCM here after Firebase.initializeApp() in main().
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      unawaited(FcmService.instance.initialize(requestPermission: false));
    }
  }

  bool _opensInterestInbox(String path) {
    final uri = Uri.tryParse(path);
    return uri?.path == AppRoutes.home && uri?.queryParameters['tab'] == '1';
  }

  bool _opensChat(String path) {
    final uri = Uri.tryParse(path);
    if (uri == null) return false;
    if (uri.path == AppRoutes.home && uri.queryParameters['tab'] == '2') {
      return true;
    }
    return uri.pathSegments.length == 2 && uri.pathSegments.first == 'chat';
  }

  Future<void> _resolveStartupConnectivity() async {
    final online = await _connectivityService!.checkNow();
    if (!mounted) return;
    if (online) {
      setState(() {
        _startupConnectionQuality = _connectivityService!.quality;
      });
      await _recoverStartupIdentity();
    } else if (_startupNetworkState != _StartupNetworkState.ready) {
      setState(() {
        _startupConnectionQuality = BackendConnectionQuality.offline;
        _startupNetworkState = _StartupNetworkState.offline;
      });
      _reportStartupGateResolved();
    }
  }

  void _handleConnectivityChange(bool online) {
    if (!mounted) return;
    if (_startupNetworkState == _StartupNetworkState.ready) {
      if (!online) {
        if (_connectivityService?.hasNetworkInterface == false) {
          _discoveryFeedCubit.markOffline();
          _accountStandingCubit.markOffline();
        }
        return;
      }
      if (SupabaseService.currentUserId != null) {
        unawaited(_accountStandingCubit.refresh());
        unawaited(_notificationsCubit.loadNotifications());
        unawaited(_refreshPremiumEntitlement(
          refreshDiscovery: false,
          allowRecent: true,
        ));
        unawaited(_discoveryFeedCubit.refreshIfChanged(forceCheck: true));
        unawaited(_interestsCubit.refreshIfChanged(forceCheck: true));
        unawaited(_chatCubit.refreshIfChanged(forceCheck: true));
      }
      return;
    }
    if (online) {
      setState(() {
        _startupConnectionQuality = _connectivityService!.quality;
      });
      unawaited(_recoverStartupIdentity());
    } else if (_startupNetworkState != _StartupNetworkState.offline) {
      setState(() {
        _startupConnectionQuality = BackendConnectionQuality.offline;
        _startupNetworkState = _StartupNetworkState.offline;
      });
      _reportStartupGateResolved();
    }
  }

  Future<bool> _recoverStartupIdentity() {
    final activeRecovery = _startupRecoveryInFlight;
    if (activeRecovery != null) return activeRecovery;
    final recovery = _performStartupIdentityRecovery();
    _startupRecoveryInFlight = recovery;
    return recovery.whenComplete(() {
      if (identical(_startupRecoveryInFlight, recovery)) {
        _startupRecoveryInFlight = null;
      }
    });
  }

  Future<bool> _performStartupIdentityRecovery() async {
    if (!mounted) return false;
    if (_startupNetworkState != _StartupNetworkState.checking) {
      setState(() => _startupNetworkState = _StartupNetworkState.checking);
    }

    final result = await _authCubit.checkSession();
    if (!mounted) return false;
    if (result == AuthSessionCheckResult.authenticated ||
        result == AuthSessionCheckResult.signedOut) {
      await _waitForBrandReveal();
      if (!mounted) return false;
      setState(() => _startupNetworkState = _StartupNetworkState.ready);
      _reportStartupGateResolved();
      return true;
    }
    // The device is online but session/profile hydration is not yet
    // authoritative. Keep protected routing covered and let retry perform the
    // complete transaction again instead of exposing sign-up/onboarding.
    setState(() {
      _startupConnectionQuality = BackendConnectionQuality.offline;
      _startupNetworkState = _StartupNetworkState.offline;
    });
    _reportStartupGateResolved();
    return false;
  }

  Future<void> _waitForBrandReveal() async {
    if (Platform.environment.containsKey('FLUTTER_TEST') ||
        ui.PlatformDispatcher.instance.accessibilityFeatures
            .disableAnimations) {
      return;
    }
    final elapsed = DateTime.now().difference(_startupStartedAt);
    final remaining = SilarahLaunchSequence.duration - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  Future<bool> _retryStartupConnectivity() async {
    final online = await _connectivityService!.checkNow();
    if (!online || !mounted) return false;
    setState(() {
      _startupConnectionQuality = _connectivityService!.quality;
    });
    // Give the offline tower one restrained confirmation pulse (green for a
    // healthy connection, amber for a slow one) before restoring the route.
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return false;
    return _recoverStartupIdentity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    PresenceService.instance.handleLifecycle(state);
    _chatCubit.setForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed &&
        SupabaseService.currentUserId != null) {
      unawaited(_accountStandingCubit.refresh());
      unawaited(_notificationsCubit.loadNotifications());
      final identity = _authCubit.state;
      if (identity is! AuthAuthenticated || identity.isGuardianOnly) return;
      unawaited(_refreshPremiumEntitlement(
        refreshDiscovery: false,
        allowRecent: true,
      ));
      unawaited(_discoveryFeedCubit.refreshIfChanged());
      // A lightweight revision RPC on resume closes the gap where Realtime or
      // FCM was suspended in the background. A full interests reload still
      // happens only when the server token changed.
      unawaited(_interestsCubit.refreshIfChanged(forceCheck: true));
      unawaited(_onboardingCubit.refreshProfileFromDb());
      unawaited(_chatCubit.refreshIfChanged());
    }
  }

  Future<void> _loginSubscriptionUser(String userId) async {
    await _revenueCatReady;
    if (!mounted || _activeSessionUserId != userId) return;
    await _subscriptionCubit.loginUser(userId);
  }

  Future<void> _refreshPremiumEntitlement({
    required bool refreshDiscovery,
    bool allowRecent = false,
  }) async {
    await _subscriptionCubit.refreshEntitlement(allowRecent: allowRecent);
    if (!mounted || !refreshDiscovery) return;
    await _discoveryFeedCubit.refreshIfChanged(forceCheck: true);
  }

  Future<void> _synchronizePublishedProfile(String userId) async {
    if (_activeSessionUserId != userId) return;
    await _accountStandingCubit.refresh();
    if (_activeSessionUserId != userId) return;
    await _discoveryFeedCubit.refreshAfterViewerPublication();
  }

  String _entitlementFingerprint(SubscriptionState value) =>
      '${value.status.name}|${value.source.name}|'
      '${value.expiresAt?.toUtc().millisecondsSinceEpoch ?? 0}';

  Future<void> _reconcileEntitlementDependents() async {
    await Future.wait<void>([
      _interestsCubit.refreshQuota(),
      _discoveryFeedCubit.refreshForEntitlementChange(),
      _chatCubit.refreshForEntitlementChange(),
    ]);
  }

  void _clearUserScopedState({
    String? departingUserId,
    bool logoutStoreIdentity = false,
  }) {
    MyAccountSnapshot.invalidate();
    BookmarkService.clearCache();
    CompatibilityService.instance.clearCache();
    IncognitoService.instance.clearCache();
    ShortlistService.instance.clearCache();
    ReferralService.instance.clearCache();
    _chatCubit.clear();
    _notificationsCubit.clear();
    _notificationPrefsCubit.clear();
    _discoveryFeedCubit.clear();
    _interestsCubit.clear();
    _blockReportCubit.clear();
    if (logoutStoreIdentity) {
      unawaited(_subscriptionCubit.logoutUser());
    } else {
      _subscriptionCubit.clear();
    }
    unawaited(_accountStandingCubit.stop());
    unawaited(OnboardingCubit.clearSensitiveDeviceState(
      userId: departingUserId,
    ));
    unawaited(DiscoveryFeedCubit.clearPersistedFilters(
      userId: departingUserId,
    ));
    unawaited(FilterPresetService.clearForUser(departingUserId));
    unawaited(LegalConsentService.instance.clearPendingTransaction());
  }

  void _openInAppNotification(NotificationItem item) {
    unawaited(_notificationsCubit.markRead(item.id));
    final path = notificationPathFor(item);
    if (path == null) return;
    if (_opensInterestInbox(path)) {
      unawaited(_interestsCubit.refreshIfChanged(forceCheck: true));
    }
    if (_opensChat(path)) {
      _chatCubit.scheduleInboxReconciliation();
    }
    _router.push(path);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_notificationRefreshSubscription?.cancel());
    unawaited(_entitlementRefreshSubscription?.cancel());
    PresenceService.instance.stop();
    // Dispose Cubits
    _authCubit.close();
    _onboardingCubit.close();
    _interestsCubit.close();
    _blockReportCubit.close();
    _discoveryFeedCubit.close();
    _chatCubit.close();
    _subscriptionCubit.close();
    _notificationPrefsCubit.close();
    _notificationsCubit.close();
    _localeCubit.close();
    _themeCubit.close();
    _accountStandingCubit.close();

    // Dispose Services
    _connectivityService?.dispose();
    SubscriptionService.instance.dispose();
    WaliModeService.instance.dispose();
    FcmService.instance.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: _authCubit),
        BlocProvider<OnboardingCubit>.value(value: _onboardingCubit),
        BlocProvider<InterestsCubit>.value(value: _interestsCubit),
        BlocProvider<DiscoveryFeedCubit>.value(value: _discoveryFeedCubit),
        BlocProvider<ChatCubit>.value(value: _chatCubit),
        BlocProvider<SubscriptionCubit>.value(value: _subscriptionCubit),
        BlocProvider<NotificationPrefsCubit>.value(
            value: _notificationPrefsCubit),
        BlocProvider<BlockReportCubit>.value(value: _blockReportCubit),
        BlocProvider<NotificationsCubit>.value(value: _notificationsCubit),
        BlocProvider<LocaleCubit>.value(value: _localeCubit),
        BlocProvider<ThemeCubit>.value(value: _themeCubit),
        BlocProvider<AccountStandingCubit>.value(
          value: _accountStandingCubit,
        ),
      ],
      child: Builder(
        builder: (context) {
          return BlocListener<AuthCubit, AuthState>(
            listener: (context, state) {
              // Reset the guard when user signs out so re-login triggers
              // a fresh initialization of the onboarding cubit.
              if (state is AuthUnauthenticated) {
                final departingUserId = _activeSessionUserId;
                _onboardingInitialized = false;
                _activeSessionUserId = null;
                _onboardingPublicationSyncedUserId = null;
                PresenceService.instance.stop();
                _clearUserScopedState(
                  departingUserId: departingUserId,
                  logoutStoreIdentity: true,
                );
              }
              if (state is AuthAuthenticated &&
                  _activeSessionUserId != null &&
                  _activeSessionUserId != state.userId) {
                _clearUserScopedState(
                  departingUserId: _activeSessionUserId,
                );
                _onboardingInitialized = false;
                _onboardingPublicationSyncedUserId = null;
              }
              final isNewAuthenticatedSession = state is AuthAuthenticated &&
                  _activeSessionUserId != state.userId;
              // Initialize the onboarding cubit ONCE when the user first
              // authenticates. Without the _onboardingInitialized guard,
              // every saveAndAdvance() → updateOnboardingStep() call
              // re-triggers this listener and wipes accumulated form data.
              if (state is AuthAuthenticated &&
                  !state.isGuardianOnly &&
                  !_onboardingInitialized) {
                _onboardingInitialized = true;
                _onboardingCubit.initialize(startStep: state.onboardingStep);
              }
              // Set the daily interest limit based on gender + subscription status.
              if (state is AuthAuthenticated) {
                _activeSessionUserId = state.userId;
                if (!state.isGuardianOnly) {
                  PresenceService.instance.start(state.userId);
                }
                if (isNewAuthenticatedSession) {
                  unawaited(_accountStandingCubit.start(state.userId));
                  if (!state.isGuardianOnly) {
                    unawaited(_loginSubscriptionUser(state.userId));
                  }
                  unawaited(FcmService.instance.onUserLogin());
                  unawaited(
                    _localeCubit.syncToServer(countryCode: state.countryCode),
                  );
                  unawaited(_notificationPrefsCubit.loadPrefs());
                  if (!state.isGuardianOnly) {
                    _chatCubit.loadConversations();
                    _interestsCubit.loadData();
                  }
                  _notificationsCubit.loadNotifications();
                }
                if (state.onboardingCompleted && !state.isGuardianOnly) {
                  if (isNewAuthenticatedSession) {
                    // Existing members are covered by the session-start read.
                    _onboardingPublicationSyncedUserId = state.userId;
                  } else if (_onboardingPublicationSyncedUserId !=
                      state.userId) {
                    // New signup completion is a one-time server publication
                    // boundary. Refresh account standing and invalidate only
                    // viewer readiness so Discovery never inherits the
                    // pre-profile "paused" snapshot.
                    _onboardingPublicationSyncedUserId = state.userId;
                    unawaited(_synchronizePublishedProfile(state.userId));
                  }
                }
              }
            },
            child: BlocBuilder<LocaleCubit, Locale>(
              builder: (context, locale) =>
                  BlocBuilder<ThemeCubit, ThemeSelectionState>(
                builder: (context, themeState) => MaterialApp.router(
                  title: 'Silarah',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.forMode(themeState.activeMode),
                  themeMode: ThemeMode.light,
                  themeAnimationDuration: const Duration(milliseconds: 420),
                  themeAnimationCurve: Curves.easeOutCubic,
                  locale: locale,

                  // Router
                  routerConfig: _router,

                  // Localizations
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  localeResolutionCallback: (deviceLocale, supportedLocales) {
                    for (final supported in supportedLocales) {
                      if (deviceLocale?.languageCode ==
                          supported.languageCode) {
                        return supported;
                      }
                    }
                    return const Locale('en');
                  },

                  // RTL-aware directionality
                  builder: (context, child) {
                    final loc = Localizations.localeOf(context);
                    final isRtl = _rtlLocales.contains(loc.languageCode);
                    final textDir =
                        isRtl ? TextDirection.rtl : TextDirection.ltr;

                    final routedApp = KeyedSubtree(
                      // Existing feature surfaces consume semantic color
                      // tokens directly. The identity key refreshes every
                      // route atomically while the long-lived router and
                      // cubits retain the member's navigation and session.
                      key: ValueKey(
                        'silarah-identity-${themeState.activeMode.storageValue}',
                      ),
                      child: Directionality(
                        textDirection: textDir,
                        child: InAppNotificationBannerHost(
                          notifications: _notificationsCubit.inAppNotifications,
                          onTap: _openInAppNotification,
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                    );
                    return AnimatedSwitcher(
                      duration: AppDimensions.durationReveal,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: switch (_startupNetworkState) {
                        // The root bootstrap owns the only visible brand
                        // sequence. Keeping this layer neutral prevents a
                        // second animation from flashing through at handoff.
                        _StartupNetworkState.checking => ColoredBox(
                            key: const ValueKey('startup-brand-underlay'),
                            color: SilarahLaunchSequence.surface,
                          ),
                        _StartupNetworkState.offline => StartupOfflineScreen(
                            key: const ValueKey('startup-connectivity-offline'),
                            onRetry: _retryStartupConnectivity,
                            quality: _startupConnectionQuality,
                          ),
                        _StartupNetworkState.ready => KeyedSubtree(
                            key: const ValueKey('startup-connectivity-ready'),
                            child: routedApp,
                          ),
                      },
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
