import 'package:silarah/l10n/ui_copy.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import 'buttons/silarah_pressable.dart';

/// Purpose-built motion scenes used by empty states.
///
/// These are intentionally semantic rather than decorative: every scene
/// describes the content that will eventually occupy the screen.
enum SilarahEmptyVisual {
  discovery,
  interests,
  sentInterests,
  conversations,
  savedProfiles,
  connection,
  neutral,
}

class SilarahEmptyState extends StatefulWidget {
  const SilarahEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.visual = SilarahEmptyVisual.neutral,
    this.icon,
    this.ctaLabel,
    this.onCta,
  });

  final String title;
  final String subtitle;
  final SilarahEmptyVisual visual;

  /// Only used by [SilarahEmptyVisual.neutral] for secondary screens that do
  /// not yet have a dedicated narrative scene.
  final IconData? icon;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  State<SilarahEmptyState> createState() => _SilarahEmptyStateState();
}

class _SilarahEmptyStateState extends State<SilarahEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion && _motion.isAnimating) {
      _motion
        ..stop()
        ..value = 0.38;
    } else if (!reduceMotion && !_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space32,
          vertical: AppDimensions.space24,
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 620),
          curve: Curves.easeOutCubic,
          builder: (context, reveal, child) => Opacity(
            opacity: reveal,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - reveal)),
              child: child,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                image: true,
                label: context.uiCopy(widget.title),
                child: RepaintBoundary(
                  child: SizedBox(
                    width: 176,
                    height: 112,
                    child: AnimatedBuilder(
                      animation: _motion,
                      builder: (context, _) => CustomPaint(
                        painter: _EmptyScenePainter(
                          visual: widget.visual,
                          progress: _motion.value,
                          fallbackIcon: widget.icon,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.space16),
              UiText(
                widget.title,
                style: AppTypography.screenTitle.copyWith(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.space10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: UiText(
                  widget.subtitle,
                  style: AppTypography.bodyMuted.copyWith(height: 1.55),
                  textAlign: TextAlign.center,
                ),
              ),
              if (widget.ctaLabel != null && widget.onCta != null) ...[
                const SizedBox(height: AppDimensions.space20),
                SilarahPressable(
                  semanticLabel: widget.ctaLabel,
                  onTap: widget.onCta,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space24,
                      vertical: AppDimensions.space12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGlass,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusButton),
                      border: Border.all(color: AppColors.goldBorder),
                    ),
                    child: UiText(
                      widget.ctaLabel!,
                      style: AppTypography.buttonSecondary.copyWith(
                        color: AppColors.champagneLight,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyScenePainter extends CustomPainter {
  const _EmptyScenePainter({
    required this.visual,
    required this.progress,
    this.fallbackIcon,
  });

  final SilarahEmptyVisual visual;
  final double progress;
  final IconData? fallbackIcon;

  Color get _gold => AppColors.champagneGold;
  Color get _light => AppColors.champagneLight;

  Paint _line(double alpha, [double width = 1.4]) => Paint()
    ..color = _gold.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _fill(double alpha) => Paint()
    ..color = _gold.withValues(alpha: alpha)
    ..style = PaintingStyle.fill;

  double _wave([double offset = 0]) =>
      (math.sin((progress + offset) * math.pi * 2) + 1) / 2;

  @override
  void paint(Canvas canvas, Size size) {
    const designSize = Size(208, 132);
    canvas.save();
    canvas.scale(
      size.width / designSize.width,
      size.height / designSize.height,
    );
    _paintAtmosphere(canvas, designSize);
    switch (visual) {
      case SilarahEmptyVisual.discovery:
        _paintDiscovery(canvas, designSize);
      case SilarahEmptyVisual.interests:
        _paintInterests(canvas, designSize, sent: false);
      case SilarahEmptyVisual.sentInterests:
        _paintInterests(canvas, designSize, sent: true);
      case SilarahEmptyVisual.conversations:
        _paintConversation(canvas, designSize);
      case SilarahEmptyVisual.savedProfiles:
        _paintSavedProfiles(canvas, designSize);
      case SilarahEmptyVisual.connection:
        _paintConnection(canvas, designSize);
      case SilarahEmptyVisual.neutral:
        _paintNeutral(canvas, designSize);
    }
    canvas.restore();
  }

  void _paintAtmosphere(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.52);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 184, height: 92),
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.champagneGold.withValues(alpha: 0.055),
            AppColors.inkTeal.withValues(alpha: 0.022),
            AppColors.transparent,
          ],
        ).createShader(
          Rect.fromCenter(center: center, width: 184, height: 92),
        ),
    );
  }

  void _paintDiscovery(Canvas canvas, Size size) {
    const horizonY = 108.0;
    final scanTravel = (1 - math.cos(progress * math.pi * 2)) / 2;
    final scanX = 28 + (152 * scanTravel);

    canvas.drawLine(
      const Offset(18, horizonY),
      Offset(size.width - 18, horizonY),
      _line(0.18),
    );

    const frames = [
      Rect.fromLTWH(26, 50, 42, 58),
      Rect.fromLTWH(83, 28, 42, 80),
      Rect.fromLTWH(140, 50, 42, 58),
    ];
    for (var i = 0; i < frames.length; i++) {
      final frame = frames[i].translate(0, -1.5 * _wave(i * 0.18));
      final active = (scanX - frame.center.dx).abs() < 32;
      canvas.drawRRect(
        RRect.fromRectAndRadius(frame, const Radius.circular(11)),
        _line(active ? 0.68 : 0.22, active ? 1.8 : 1.15),
      );
      canvas.drawCircle(
        Offset(frame.center.dx, frame.top + frame.height * 0.36),
        7,
        _line(active ? 0.58 : 0.18, 1.2),
      );
      final shoulder = Path()
        ..moveTo(frame.center.dx - 12, frame.bottom - 13)
        ..quadraticBezierTo(
          frame.center.dx,
          frame.bottom - 27,
          frame.center.dx + 12,
          frame.bottom - 13,
        );
      canvas.drawPath(shoulder, _line(active ? 0.58 : 0.18, 1.2));
    }

    canvas.drawLine(
      Offset(scanX, 22),
      Offset(scanX, horizonY + 2),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.transparent,
            _light.withValues(alpha: 0.56),
            _light.withValues(alpha: 0.04),
          ],
        ).createShader(Rect.fromLTWH(scanX - 1, 22, 2, horizonY - 20))
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(Offset(scanX, horizonY), 2.7, _fill(0.82));
  }

  void _paintInterests(Canvas canvas, Size size, {required bool sent}) {
    final left = Offset(sent ? 42 : 48, 66);
    final right = Offset(sent ? 166 : 160, 66);
    final center = Offset(size.width / 2, 66);

    final upper = Path()
      ..moveTo(left.dx + 17, left.dy)
      ..cubicTo(82, 25, 126, 25, right.dx - 17, right.dy);
    final lower = Path()
      ..moveTo(left.dx + 17, left.dy + 3)
      ..cubicTo(82, 106, 126, 106, right.dx - 17, right.dy + 3);
    canvas.drawPath(upper, _line(0.22));
    canvas.drawPath(lower, _line(0.13));

    _paintIdentityNode(canvas, left, active: !sent);
    _paintIdentityNode(canvas, right, active: sent);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-7, -7, 14, 14),
        const Radius.circular(3),
      ),
      _fill(0.72),
    );
    canvas.restore();

    final metric = (sent ? upper : lower).computeMetrics().first;
    final tangent = metric.getTangentForOffset(metric.length * progress);
    if (tangent != null) {
      final travelOpacity = math.sin(progress * math.pi);
      canvas.drawCircle(tangent.position, 7, _fill(0.07 * travelOpacity));
      canvas.drawCircle(tangent.position, 2.8, _fill(0.9 * travelOpacity));
    }
  }

  void _paintIdentityNode(Canvas canvas, Offset center,
      {required bool active}) {
    canvas.drawCircle(center, 20, _line(active ? 0.66 : 0.24, 1.4));
    canvas.drawCircle(center.translate(0, -5), 5, _line(0.44, 1.15));
    final shoulders = Path()
      ..moveTo(center.dx - 9, center.dy + 10)
      ..quadraticBezierTo(
        center.dx,
        center.dy,
        center.dx + 9,
        center.dy + 10,
      );
    canvas.drawPath(shoulders, _line(0.44, 1.15));
    if (active) {
      canvas.drawCircle(center, 25 + (_wave() * 2), _line(0.09));
    }
  }

  void _paintConversation(Canvas canvas, Size size) {
    final drift = 2.5 * _wave();
    final left = RRect.fromRectAndRadius(
      Rect.fromLTWH(28, 26 + drift, 98, 60),
      const Radius.circular(16),
    );
    final right = RRect.fromRectAndRadius(
      Rect.fromLTWH(82, 60 - drift, 98, 52),
      const Radius.circular(16),
    );
    canvas.drawRRect(left, _line(0.27, 1.3));
    canvas.drawRRect(right, _line(0.64, 1.6));

    final leftTail = Path()
      ..moveTo(45, 84 + drift)
      ..lineTo(38, 98 + drift)
      ..lineTo(61, 86 + drift);
    final rightTail = Path()
      ..moveTo(163, 108 - drift)
      ..lineTo(176, 119 - drift)
      ..lineTo(171, 99 - drift);
    canvas.drawPath(leftTail, _line(0.27, 1.3));
    canvas.drawPath(rightTail, _line(0.64, 1.6));

    for (var i = 0; i < 3; i++) {
      final phase = _wave(i * 0.13);
      canvas.drawCircle(
        Offset(111 + (i * 17), 86 - drift - (phase * 3)),
        3,
        _fill(0.28 + phase * 0.5),
      );
    }
    canvas.drawLine(const Offset(48, 52), const Offset(92, 52), _line(0.2));
    canvas.drawLine(const Offset(48, 64), const Offset(78, 64), _line(0.13));
  }

  void _paintSavedProfiles(Canvas canvas, Size size) {
    final parallax = _wave() * 2;
    final back = RRect.fromRectAndRadius(
      Rect.fromLTWH(38 - parallax, 34, 74, 82),
      const Radius.circular(13),
    );
    final middle = RRect.fromRectAndRadius(
      Rect.fromLTWH(67, 24 + parallax, 74, 88),
      const Radius.circular(13),
    );
    final frontRect = Rect.fromLTWH(96 + parallax, 14, 74, 94);
    final front = RRect.fromRectAndRadius(frontRect, const Radius.circular(13));
    canvas.drawRRect(back, _line(0.12));
    canvas.drawRRect(middle, _line(0.24));
    canvas.drawRRect(front, _line(0.68, 1.6));

    canvas.drawCircle(Offset(frontRect.center.dx, 43), 9, _line(0.42, 1.2));
    final shoulders = Path()
      ..moveTo(frontRect.center.dx - 15, 70)
      ..quadraticBezierTo(
          frontRect.center.dx, 53, frontRect.center.dx + 15, 70);
    canvas.drawPath(shoulders, _line(0.42, 1.2));

    final bookmark = Path()
      ..moveTo(145, 15)
      ..lineTo(158, 15)
      ..lineTo(158, 36)
      ..lineTo(151.5, 31)
      ..lineTo(145, 36)
      ..close();
    canvas.drawPath(bookmark, _fill(0.82));
    canvas.drawLine(
      const Offset(45, 122),
      Offset(164 + parallax, 122),
      _line(0.13),
    );
  }

  void _paintConnection(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(26, 84)
      ..cubicTo(60, 24, 91, 24, 104, 68)
      ..cubicTo(116, 111, 151, 110, 182, 50);
    canvas.drawPath(path, _line(0.22, 1.4));
    final metric = path.computeMetrics().first;
    final tangent = metric.getTangentForOffset(metric.length * progress);
    if (tangent != null) {
      canvas.drawCircle(
        tangent.position,
        3,
        _fill(0.82 * math.sin(progress * math.pi)),
      );
    }
    for (final point in const [
      Offset(26, 84),
      Offset(104, 68),
      Offset(182, 50)
    ]) {
      canvas.drawCircle(point, 9, _line(0.5, 1.4));
      canvas.drawCircle(point, 2.4, _fill(0.7));
    }
  }

  void _paintNeutral(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(const Offset(30, 66), const Offset(178, 66), _line(0.16));
    canvas.drawCircle(center, 28 + _wave() * 2, _line(0.26, 1.2));
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-11, -11, 22, 22),
        const Radius.circular(5),
      ),
      _line(0.72, 1.5),
    );
    canvas.restore();

    if (fallbackIcon != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(fallbackIcon!.codePoint),
          style: TextStyle(
            fontSize: 18,
            fontFamily: fallbackIcon!.fontFamily,
            package: fallbackIcon!.fontPackage,
            color: _light.withValues(alpha: 0.75),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EmptyScenePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.visual != visual ||
      oldDelegate.fallbackIcon != fallbackIcon;
}
