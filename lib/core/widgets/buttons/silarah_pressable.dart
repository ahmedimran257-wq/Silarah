import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:silarah/l10n/ui_copy.dart';
import '../../theme/app_curves.dart';
import '../../theme/app_dimensions.dart';

class SilarahPressable extends StatefulWidget {
  const SilarahPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.haptic = true,
    this.pressedScale = 0.985,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool haptic;
  final double pressedScale;
  final String? semanticLabel;

  @override
  State<SilarahPressable> createState() => _SilarahPressableState();
}

class _SilarahPressableState extends State<SilarahPressable> {
  bool _pressed = false;
  bool _hovered = false;

  void _handleTapDown(TapDownDetails _) {
    if (!widget.enabled) return;
    setState(() => _pressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (!widget.enabled) return;
    setState(() => _pressed = false);
  }

  void _handleTapCancel() {
    if (!widget.enabled) return;
    setState(() => _pressed = false);
  }

  void _handleTap() {
    if (!widget.enabled) return;
    if (widget.haptic) HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel == null
          ? null
          : context.uiCopy(widget.semanticLabel!),
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: widget.enabled ? _handleTapDown : null,
          onTapUp: widget.enabled ? _handleTapUp : null,
          onTapCancel: widget.enabled ? _handleTapCancel : null,
          onTap: widget.enabled ? _handleTap : null,
          onLongPress: widget.enabled ? widget.onLongPress : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            scale: _pressed ? widget.pressedScale : 1,
            duration: reduceMotion
                ? Duration.zero
                : _pressed
                    ? AppDimensions.durationButtonPress
                    : AppDimensions.durationTransition,
            curve: _pressed ? AppCurves.buttonPress : AppCurves.reveal,
            child: AnimatedSlide(
              duration: reduceMotion
                  ? Duration.zero
                  : AppDimensions.durationTransition,
              curve: AppCurves.reveal,
              offset: Offset(0, _hovered && widget.enabled ? -0.015 : 0),
              child: AnimatedOpacity(
                duration: reduceMotion
                    ? Duration.zero
                    : AppDimensions.durationButtonPress,
                opacity: !widget.enabled ? 0.5 : (_pressed ? 0.9 : 1),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
