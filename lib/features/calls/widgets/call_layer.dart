// The call screen as a layer above the whole app, the way WhatsApp and
// Telegram show calls (docs/voice_calling_spec.md 12.1): a ring, a call being
// placed or a live call is shown at once over whatever is underneath,
// including start-up, and the app's own navigation is never touched. The
// call screen has its own navigator for its dialogs and sheets, and takes the
// system Back from the app's router only while it is showing.
import 'package:flutter/material.dart';

import '../call_controller.dart';
import '../screens/call_screen.dart';

class CallLayer extends StatefulWidget {
  const CallLayer({
    super.key,
    required this.child,
    this.backButtonDispatcher,
    this.controller,
    this.screen,
  });

  /// The app.
  final Widget child;

  /// The app router's Back dispatcher: the call screen takes priority over it
  /// while it is showing.
  final BackButtonDispatcher? backButtonDispatcher;

  final CallController? controller;

  /// The call screen (tests swap it).
  final Widget? screen;

  @override
  State<CallLayer> createState() => _CallLayerState();
}

class _CallLayerState extends State<CallLayer> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  ChildBackButtonDispatcher? _back;

  CallController get _call => widget.controller ?? CallController.instance;

  bool get _showing => _call.callScreenVisible;

  @override
  void initState() {
    super.initState();
    _call.addListener(_changed);
    _takeBack();
  }

  @override
  void didUpdateWidget(CallLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? CallController.instance).removeListener(_changed);
      _call.addListener(_changed);
    }
    if (oldWidget.backButtonDispatcher != widget.backButtonDispatcher) {
      _releaseBack(oldWidget.backButtonDispatcher);
      _takeBack();
    }
  }

  @override
  void dispose() {
    _call.removeListener(_changed);
    _releaseBack(widget.backButtonDispatcher);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    _showing ? _takeBack() : _releaseBack(widget.backButtonDispatcher);
    setState(() {});
  }

  /// While the call screen shows, Back is the call screen's, not the page
  /// underneath it.
  void _takeBack() {
    final parent = widget.backButtonDispatcher;
    if (parent == null || _back != null || !_showing) return;
    _back = parent.createChildBackButtonDispatcher()
      ..addCallback(_onBack)
      ..takePriority();
  }

  void _releaseBack(BackButtonDispatcher? parent) {
    final back = _back;
    if (back == null) return;
    back.removeCallback(_onBack);
    parent?.forget(back);
    _back = null;
  }

  /// A dialog or sheet of the call screen closes first; then the call screen
  /// itself decides (a ring waits, a locked phone steps back, otherwise the
  /// app shows with the return bar).
  Future<bool> _onBack() async {
    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return true;
    }
    await _call.leaveCallScreen();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final showing = _showing;
    return Stack(
      children: [
        // Under the call screen the app keeps its place, but screen readers
        // and touches reach only the call.
        ExcludeSemantics(
          excluding: showing,
          child: IgnorePointer(ignoring: showing, child: widget.child),
        ),
        if (showing)
          Positioned.fill(
            child: HeroControllerScope.none(
              child: Navigator(
                key: _navigatorKey,
                pages: [
                  MaterialPage<void>(
                    key: const ValueKey('call-screen'),
                    child: widget.screen ?? CallScreen(controller: _call),
                  ),
                ],
                onDidRemovePage: (_) {},
              ),
            ),
          ),
      ],
    );
  }
}
