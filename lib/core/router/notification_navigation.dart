import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The Home tab a screen opened from a notification sits on, so Back lands
/// somewhere sensible.
String notificationHomeFallback(String path) {
  final route = Uri.parse(path).path;
  if (route.startsWith('/chat')) return '/home?tab=2';
  if (route.startsWith('/profile/')) return '/home?tab=1';
  if (route == '/notifications') return '/home?tab=0';
  return '/home?tab=3';
}

/// Opens an external push destination above a real Home tab.
///
/// A terminated Android app can be launched with an empty platform route, so
/// the launch route is first replaced with Home. The destination is then
/// pushed on top: opened alone it had nothing beneath it, and its Back
/// button left a blank screen while a swipe closed the app.
void navigateFromPushNotification(GoRouter router, String path) {
  if (!path.startsWith('/')) {
    throw ArgumentError.value(path, 'path', 'Must be an absolute app path');
  }
  if (Uri.parse(path).path == '/home') {
    router.go(path);
    return;
  }
  final home = notificationHomeFallback(path);
  final delegate = router.routerDelegate;
  if (delegate.currentConfiguration.uri.toString() == home) {
    router.push(path);
    return;
  }
  // Push only once Home is really in place; pushed earlier, the destination
  // is replaced when Home arrives. The start-up gate may show first on a cold
  // start, so wait through it. Sign-in or onboarding instead drops the stale
  // destination.
  void pushOnHome() {
    final shown = delegate.currentConfiguration.uri.path;
    if (shown == '/boot') return;
    delegate.removeListener(pushOnHome);
    if (shown == '/home') router.push(path);
  }

  delegate.addListener(pushOnHome);
  router.go(home);
}

/// Returns from a full-screen route without ever exposing an empty navigator.
///
/// External notification routes intentionally become the router root. Such a
/// route has nothing to pop, so a raw Navigator.pop() leaves a blank platform
/// surface. Ordinary in-app pushes still pop normally; notification roots
/// return to their stable home tab.
void popOrGoToFallback(GoRouter router, String fallbackPath) {
  if (!fallbackPath.startsWith('/')) {
    throw ArgumentError.value(
      fallbackPath,
      'fallbackPath',
      'Must be an absolute app path',
    );
  }
  if (router.canPop()) {
    router.pop();
  } else {
    router.go(fallbackPath);
  }
}

/// Gives a route opened as an external-notification root a safe system Back
/// destination while preserving ordinary in-app push/pop behavior.
class NotificationRouteBackScope extends StatelessWidget {
  const NotificationRouteBackScope({
    super.key,
    required this.fallbackPath,
    required this.child,
  });

  final String fallbackPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    return PopScope(
      canPop: router.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) popOrGoToFallback(router, fallbackPath);
      },
      child: child,
    );
  }
}

/// Keeps Android Back predictable when a notification opens a secondary home
/// tab as the app's root destination.
///
/// Bottom-navigation tabs are not navigator pages. Allowing the platform Back
/// action to pop the root while Messages, Interests, or Profile is selected can
/// expose the activity's launch surface on some Android builds. Return to
/// Discover first; a second Back from Discover retains the normal Android exit
/// behavior.
class HomeTabBackScope extends StatelessWidget {
  const HomeTabBackScope({
    super.key,
    required this.currentTab,
    required this.onReturnToPrimaryTab,
    required this.child,
  });

  final int currentTab;
  final VoidCallback onReturnToPrimaryTab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: currentTab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && currentTab != 0) onReturnToPrimaryTab();
      },
      child: child,
    );
  }
}
