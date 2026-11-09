// SILARAH — GoRouter Configuration
// Auth-gated routing:
//   • Unauthenticated → /splash
//   • Authenticated, onboarding incomplete → /onboarding/:step
//   • Authenticated, onboarding complete   → /home
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubits/auth/auth_cubit.dart';
import '../cubits/auth/auth_state.dart';
import '../cubits/onboarding/onboarding_cubit.dart';
import '../onboarding/onboarding_flow.dart';
import '../theme/app_colors.dart';
import 'notification_navigation.dart';

import '../../features/onboarding/screens/splash_brand_screen.dart';
import '../../features/onboarding/screens/language_selection_screen.dart';
import '../../features/onboarding/screens/legal_gate_screen.dart';
import '../../features/onboarding/screens/email_verification_screen.dart';
import '../../features/onboarding/screens/profile_for_whom_screen.dart';
import '../../features/onboarding/screens/quick_location_screen.dart';
import '../../features/onboarding/screens/basic_identity_screen.dart';
import '../../features/onboarding/screens/islamic_identity_screen.dart';
import '../../features/onboarding/screens/photo_upload_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/screens/edit_profile_screen.dart';
import '../../features/home/screens/profile_views_screen.dart';
import '../../features/home/screens/notifications_screen.dart';
import '../../features/home/screens/delete_account_screen.dart';
import '../../features/home/screens/block_list_screen.dart';
import '../../features/home/screens/subscription_screen.dart';
import '../../features/home/screens/guardian_dashboard_screen.dart';
import '../../features/home/screens/guardian_connect_screen.dart';
import '../../features/home/screens/chat_screen.dart';
import '../../features/home/screens/referral_screen.dart';
import '../../features/home/screens/help_support_screen.dart';
import '../../features/home/screens/photo_access_requests_screen.dart';
import '../../features/home/screens/profile_route_screen.dart';
import '../../features/home/screens/shortlist_screen.dart';
import '../../features/verification/screens/badge_verification_screen.dart';
import '../widgets/loaders/silarah_shimmer.dart';

// Route names
abstract final class AppRoutes {
  static const boot = '/boot';
  static const authCallback = '/auth/callback';
  static const splash = '/';
  static const languageSelect = '/language';
  static const legal = '/legal';
  static const email = '/email';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const editProfile = '/edit-profile';
  static const profileViews = '/profile-views';
  static const notifications = '/notifications';
  static const deleteAccount = '/delete-account';
  static const blockList = '/block-list';
  static const subscription = '/subscription';
  static const guardianDashboard = '/guardian-dashboard';
  static const guardianConnect = '/guardian-connect';
  static const referral = '/referral';
  static const verify = '/verify';
  static const badgeVerification = '/badge-verification';
  static const helpSupport = '/help-support';
  static const photoRequests = '/photo-requests';
  static const shortlist = '/shortlist';
}

// Screen index → route path mapping
String onboardingPathForStep(int step) {
  return '${AppRoutes.onboarding}/$step';
}

int _safeOnboardingStep(AuthAuthenticated state) {
  final completeAt = OnboardingFlow.completeAt(state.isGuardianPath);
  return state.onboardingStep.clamp(0, completeAt - 1).toInt();
}

// Router factory
GoRouter buildAppRouter(
  AuthCubit authCubit, {
  String initialLocation = AppRoutes.splash,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    // FCM notification intents can launch Android with an empty platform
    // route. go_router attempts to match that empty URI again when auth emits
    // during session recovery, which raises a RangeError before redirect can
    // normalize it. App Links are consumed by AuthCallbackService, so the
    // router should always start from this validated internal location.
    overridePlatformDefaultLocation: true,
    refreshListenable: _AuthStateListenable(authCubit),
    redirect: (context, state) {
      final authState = authCubit.state;
      final location = state.matchedLocation;

      // AuthCallbackService consumes callback credentials outside the widget
      // tree. Route only to this credential-free internal gate so a token can
      // never appear in an error page or accessibility snapshot.
      if (location == AppRoutes.authCallback) return AppRoutes.boot;

      // Loading can be either app boot session hydration or an in-place
      // pre-auth action such as sending an email OTP. Keep the user on the
      // current pre-auth screen during that request; only unknown protected
      // locations should fall back to the boot gate.
      if (authState is AuthInitial || authState is AuthLoading) {
        if (location == AppRoutes.languageSelect ||
            location == AppRoutes.splash ||
            location == AppRoutes.legal ||
            location == AppRoutes.email ||
            location == AppRoutes.guardianConnect ||
            location == AppRoutes.boot) {
          return null;
        }
        return AppRoutes.boot;
      }

      if (authState is AuthError) {
        return null;
      }

      // Unauthenticated: always go to splash
      if (authState is AuthUnauthenticated || authState is AuthOtpSent) {
        if (location == AppRoutes.languageSelect ||
            location == AppRoutes.splash ||
            location == AppRoutes.legal ||
            location == AppRoutes.email ||
            location == AppRoutes.guardianConnect) {
          return null; // allow these pages
        }
        return AppRoutes.splash;
      }

      // Authenticated
      if (authState is AuthAuthenticated) {
        if (authState.guardianInvitationPending && !authState.isGuardianOnly) {
          if (location == AppRoutes.guardianConnect) return null;
          return AppRoutes.guardianConnect;
        }

        if (authState.isGuardianOnly) {
          if (location == AppRoutes.guardianDashboard ||
              location == AppRoutes.guardianConnect ||
              location == AppRoutes.deleteAccount ||
              location == AppRoutes.helpSupport) {
            return null;
          }
          return AppRoutes.guardianDashboard;
        }

        if (authState.isOnboardingComplete) {
          // Fully onboarded — go to home unless already there or on sub-routes
          if (location.startsWith(AppRoutes.home) ||
              location == AppRoutes.editProfile ||
              location == AppRoutes.profileViews ||
              location == AppRoutes.notifications ||
              location == AppRoutes.deleteAccount ||
              location == AppRoutes.blockList ||
              location == AppRoutes.subscription ||
              location == AppRoutes.guardianDashboard ||
              location == AppRoutes.guardianConnect ||
              location == AppRoutes.referral ||
              location == AppRoutes.verify ||
              location == AppRoutes.badgeVerification ||
              location == AppRoutes.helpSupport) {
            return null;
          }
          if (location == AppRoutes.photoRequests ||
              location == AppRoutes.shortlist ||
              location.startsWith('/profile/')) {
            return null;
          }
          if (location.startsWith('/chat/')) return null;
          return AppRoutes.home;
        } else {
          // Still onboarding — allow the language selection screen so
          // the first-install sequence isn't short-circuited.
          // Other pre-auth screens (splash, legal, email) should redirect
          // to the onboarding step once the user is authenticated.
          if (location == AppRoutes.languageSelect) {
            return null;
          }
          // Otherwise navigate to the current onboarding step.
          // goBack() already updates authState.onboardingStep to the
          // lower step, so the redirect naturally handles back-nav too.
          final targetPath = onboardingPathForStep(
            _safeOnboardingStep(authState),
          );
          if (location == targetPath) return null;
          return targetPath;
        }
      }

      return null;
    },
    routes: [
      // Pre-auth screens
      GoRoute(
        path: AppRoutes.boot,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const _BootGateScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.authCallback,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const _BootGateScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.languageSelect,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const LanguageSelectionScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const SplashBrandScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.legal,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const NotificationRouteBackScope(
            fallbackPath: AppRoutes.splash,
            child: LegalGateScreen(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.email,
        pageBuilder: (context, state) {
          final mode = state.uri.queryParameters['mode'] == 'signup'
              ? EmailAuthMode.signUp
              : EmailAuthMode.signIn;
          return _slidePage(
            key: state.pageKey,
            child: EmailVerificationScreen(mode: mode),
          );
        },
      ),

      // Onboarding steps 0–4
      GoRoute(
        path: '${AppRoutes.onboarding}/:step',
        pageBuilder: (context, state) {
          final step = int.tryParse(state.pathParameters['step'] ?? '0') ?? 0;
          return _slidePage(
            key: state.pageKey,
            child: _OnboardingRouteStepBinder(
              step: step,
              child: _screenForStep(step),
            ),
          );
        },
      ),

      // Home (post-onboarding)
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) {
          final tabIndexStr = state.uri.queryParameters['tab'];
          final initialTab =
              tabIndexStr != null ? int.tryParse(tabIndexStr) : null;
          return _slidePage(
            key: state.pageKey,
            child: HomeScreen(initialTab: initialTab),
          );
        },
      ),

      // Full-screen sub-screens
      GoRoute(
        path: AppRoutes.editProfile,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const EditProfileScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.profileViews,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const ProfileViewsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const NotificationsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.deleteAccount,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const DeleteAccountScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.blockList,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const BlockListScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.subscription,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const SubscriptionScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.shortlist,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const ShortlistScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.guardianDashboard,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const GuardianDashboardScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.guardianConnect,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const GuardianConnectScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.verify,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          // Backward-compatible route for old notification links.
          child: const BadgeVerificationScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.badgeVerification,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const BadgeVerificationScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.helpSupport,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const HelpSupportScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.photoRequests,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const PhotoAccessRequestsScreen(),
        ),
      ),
      GoRoute(
        path: '/profile/:id',
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: ProfileRouteScreen(
            profileIdentifier: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.referral,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const ReferralScreen(),
        ),
      ),
      GoRoute(
        path: '/chat/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _slidePage(
            key: state.pageKey,
            child: NotificationRouteBackScope(
              fallbackPath: '${AppRoutes.home}?tab=2',
              child: ChatScreen(conversationId: id),
            ),
          );
        },
      ),
    ],
  );
}

Widget _screenForStep(int step) {
  switch (step) {
    case OnboardingFlow.profileForWhomStep:
      return const ProfileForWhomScreen();
    case OnboardingFlow.quickLocationStepIndex:
      return const QuickLocationScreen();
    case OnboardingFlow.basicIdentityStep:
      return const BasicIdentityScreen();
    case OnboardingFlow.islamicIdentityStep:
      return const IslamicIdentityScreen();
    case OnboardingFlow.photoUploadStep:
      return const PhotoUploadScreen();
    default:
      return const ProfileForWhomScreen();
  }
}

// Custom page transition ("Unfold" — slides from right)
class _OnboardingRouteStepBinder extends StatefulWidget {
  const _OnboardingRouteStepBinder({
    required this.step,
    required this.child,
  });

  final int step;
  final Widget child;

  @override
  State<_OnboardingRouteStepBinder> createState() =>
      _OnboardingRouteStepBinderState();
}

class _OnboardingRouteStepBinderState
    extends State<_OnboardingRouteStepBinder> {
  @override
  void initState() {
    super.initState();
    _syncAfterFrame();
  }

  @override
  void didUpdateWidget(covariant _OnboardingRouteStepBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step) _syncAfterFrame();
  }

  void _syncAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OnboardingCubit>().syncRouteStep(widget.step);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

MaterialPage<void> _slidePage({
  required LocalKey key,
  required Widget child,
}) {
  return MaterialPage<void>(
    key: key,
    child: child,
  );
}

class _BootGateScreen extends StatelessWidget {
  const _BootGateScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: const Center(child: SilarahPulseLoader(size: 56)),
    );
  }
}

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(AuthCubit cubit) {
    _subscription = cubit.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
