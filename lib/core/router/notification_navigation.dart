import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'home_tab.dart';

/// The Home tab a screen opened from a notification sits on, so Back lands
/// somewhere sensible.
String notificationHomeFallback(String path) {
  final route = Uri.parse(path).path;
  if (route.startsWith('/chat')) return HomeTab.chats.path;
  if (route.startsWith('/profile/')) return HomeTab.interests.path;
  if (route == '/notifications') return HomeTab.discover.path;
  return HomeTab.profile.path;
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
    if (shown == '/home') {
      router.push(path);
    } else {
      debugPrint('[navigation] "$path" not opened: start-up went to "$shown"');
    }
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

/// Android Back on the Home tabs.
///
/// Bottom-navigation tabs are not navigator pages. Allowing the platform Back
/// action to pop the root while Messages, Interests, or Profile is selected can
/// expose the activity's launch surface on some Android builds, so Back first
/// returns to Discover. On Discover the first Back only shows "Press back again
/// to exit" ([onExitArmed]); a second Back within [exitWindow] leaves the app,
/// so a stray press never closes it (closed-test feedback, 25 Nov 2026).
class HomeTabBackScope extends StatefulWidget {
  const HomeTabBackScope({
    super.key,
    required this.currentTab,
    required this.onReturnToPrimaryTab,
    required this.child,
    this.onExitArmed,
    this.exitWindow = const Duration(seconds: 2),
  });

  final HomeTab currentTab;
  final VoidCallback onReturnToPrimaryTab;
  final Widget child;

  /// Tell the member a second Back leaves (a short snack bar).
  final VoidCallback? onExitArmed;
  final Duration exitWindow;

  @override
  State<HomeTabBackScope> createState() => _HomeTabBackScopeState();
}

class _HomeTabBackScopeState extends State<HomeTabBackScope> {
  Timer? _exitWindow;

  bool get _exitArmed => _exitWindow?.isActive ?? false;

  @override
  void didUpdateWidget(HomeTabBackScope old) {
    super.didUpdateWidget(old);
    // Leaving Discover disarms: the next Back there asks again.
    if (old.currentTab != widget.currentTab) _disarm();
  }

  void _disarm() {
    _exitWindow?.cancel();
    _exitWindow = null;
  }

  @override
  void dispose() {
    _exitWindow?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onDiscover = widget.currentTab == HomeTab.discover;
    return PopScope(
      canPop: onDiscover && _exitArmed,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!onDiscover) {
          widget.onReturnToPrimaryTab();
          return;
        }
        setState(() {
          _exitWindow = Timer(widget.exitWindow, () {
            if (mounted) setState(_disarm);
          });
        });
        widget.onExitArmed?.call();
      },
      child: widget.child,
    );
  }
}
