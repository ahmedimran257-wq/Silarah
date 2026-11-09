import 'package:silarah/l10n/ui_copy.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_curves.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';
import '../cards/profile_card_box.dart';

/// Silarah's quiet loading signature: a fixed seal with a shallow breathing
/// motion. It communicates activity without the visual churn of a spinner.
class SilarahActivityIndicator extends StatefulWidget {
  const SilarahActivityIndicator({
    super.key,
    this.size = 24,
    this.color,
    this.label = 'Loading',
  });

  final double size;
  final Color? color;
  final String label;

  @override
  State<SilarahActivityIndicator> createState() =>
      _SilarahActivityIndicatorState();
}

class _SilarahActivityIndicatorState extends State<SilarahActivityIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      value: .5,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion &&
        (_controller.isAnimating || reduceMotion)) {
      return;
    }
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _controller
        ..stop()
        ..value = .5;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.champagneGold;
    return Semantics(
      label: context.uiCopy(widget.label),
      liveRegion: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final pulse = _reduceMotion
                  ? .5
                  : AppCurves.breathe.transform(_controller.value);
              return CustomPaint(
                painter: _SilarahActivityPainter(
                  color: color,
                  pulse: pulse,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SilarahActivityPainter extends CustomPainter {
  const _SilarahActivityPainter({required this.color, required this.pulse});

  final Color color;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerSide = size.shortestSide * (.64 + pulse * .06);
    final innerSide = size.shortestSide * (.18 + pulse * .025);
    final stroke = math.max(1.0, size.shortestSide * .055);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);
    final outerRect = Rect.fromCenter(
      center: Offset.zero,
      width: outerSide,
      height: outerSide,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        outerRect,
        Radius.circular(size.shortestSide * .1),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: .2 + pulse * .26),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: innerSide,
          height: innerSide,
        ),
        Radius.circular(size.shortestSide * .045),
      ),
      Paint()..color = color.withValues(alpha: .72 + pulse * .28),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SilarahActivityPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pulse != pulse;
}

/// Determinate progress drawn as an open precision arc. The open lower edge
/// keeps it visually distinct from an indeterminate spinner.
class SilarahProgressRing extends StatelessWidget {
  const SilarahProgressRing({
    super.key,
    required this.value,
    this.size = 42,
    this.strokeWidth = 3,
    this.color,
    this.trackColor,
    this.semanticLabel,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0.0, 1.0).toDouble();
    return Semantics(
      label: semanticLabel == null ? null : context.uiCopy(semanticLabel!),
      value: '${(progress * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _SilarahProgressRingPainter(
              value: progress,
              strokeWidth: strokeWidth,
              color: color ?? AppColors.champagneGold,
              trackColor: trackColor ?? AppColors.progressBarBase,
            ),
          ),
        ),
      ),
    );
  }
}

class _SilarahProgressRingPainter extends CustomPainter {
  const _SilarahProgressRingPainter({
    required this.value,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(strokeWidth, strokeWidth) &
        Size(size.width - strokeWidth * 2, size.height - strokeWidth * 2);
    const start = math.pi * .75;
    const totalSweep = math.pi * 1.5;
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
        rect, start, totalSweep, false, basePaint..color = trackColor);
    if (value <= 0) return;
    final sweep = totalSweep * value;
    canvas.drawArc(rect, start, sweep, false, basePaint..color = color);
    final radius = rect.width / 2;
    final angle = start + sweep;
    final center = rect.center;
    canvas.drawCircle(
      Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      ),
      strokeWidth * .62,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SilarahProgressRingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

/// Rounded progress track used for determinate progress and quiet background
/// activity. Indeterminate motion is a short travelling accent, not a sweep
/// across the full screen.
class SilarahLinearProgress extends StatefulWidget {
  const SilarahLinearProgress({
    super.key,
    this.value,
    this.height = 4,
    this.color,
    this.trackColor,
    this.semanticLabel,
  });

  final double? value;
  final double height;
  final Color? color;
  final Color? trackColor;
  final String? semanticLabel;

  @override
  State<SilarahLinearProgress> createState() => _SilarahLinearProgressState();
}

class _SilarahLinearProgressState extends State<SilarahLinearProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      value: .5,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion &&
        (_controller.isAnimating || reduceMotion || widget.value != null)) {
      return;
    }
    _reduceMotion = reduceMotion;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant SilarahLinearProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _syncAnimation();
  }

  void _syncAnimation() {
    if (_reduceMotion || widget.value != null) {
      _controller
        ..stop()
        ..value = .5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.champagneGold;
    final track = widget.trackColor ?? AppColors.progressBarBase;
    final progress = widget.value?.clamp(0.0, 1.0).toDouble();
    final semanticsValue =
        progress == null ? null : '${(progress * 100).round()}%';

    return Semantics(
      label: widget.semanticLabel == null
          ? null
          : context.uiCopy(widget.semanticLabel!),
      value: semanticsValue,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.height),
          child: SizedBox(
            height: widget.height,
            child: ColoredBox(
              color: track,
              child: progress != null
                  ? Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        heightFactor: 1,
                        child: ColoredBox(color: color),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) => AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          final position = _reduceMotion
                              ? 0.0
                              : -1.35 +
                                  AppCurves.transition
                                          .transform(_controller.value) *
                                      2.7;
                          return Align(
                            alignment: Alignment(position, 0),
                            child: SizedBox(
                              width: constraints.maxWidth * .28,
                              height: widget.height,
                              child: ColoredBox(color: color),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class SilarahPulseLoader extends StatelessWidget {
  const SilarahPulseLoader({
    super.key,
    this.label,
    this.size = 54,
    this.accentColor,
    this.highlightColor,
    this.markColor,
    this.coreGradientColors,
  });

  final String? label;
  final double size;
  final Color? accentColor;
  final Color? highlightColor;
  final Color? markColor;
  final List<Color>? coreGradientColors;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SilarahActivityIndicator(
          size: size,
          color: accentColor,
          label: label ?? 'Loading',
        ),
        if (label != null) ...[
          const SizedBox(height: AppDimensions.space12),
          UiText(
            label!,
            style: AppTypography.caption.copyWith(
              color: AppColors.slateMist,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

// Base Shimmer Widget
class SilarahShimmer extends StatefulWidget {
  const SilarahShimmer({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<SilarahShimmer> createState() => _SilarahShimmerState();
}

class _SilarahShimmerState extends State<SilarahShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDimensions.durationShimmer,
      value: .5,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion &&
        (_controller.isAnimating || reduceMotion)) {
      return;
    }
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _controller
        ..stop()
        ..value = .5;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    if (_reduceMotion) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            // Shimmer sweep: moves from -1.0 to 2.0 (ensures full coverage)
            final t = _controller.value * 3 - 1;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.surfaceGlass,
                AppColors.slateMist, // The bright sweep point
                AppColors.surfaceGlassHover,
                AppColors.surfaceGlass,
              ],
              stops: [
                (t - 0.3).clamp(0.0, 1.0),
                t.clamp(0.0, 1.0),
                (t + 0.1).clamp(0.0, 1.0),
                (t + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// Shimmer Box (building block)
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius,
  });

  final double width;
  final double height;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceGlassHover,
        borderRadius: BorderRadius.circular(
          radius ?? AppDimensions.radiusTiny,
        ),
      ),
    );
  }
}

// Profile Card Shimmer
/// A restrained discovery placeholder.
///
/// Profile cards occupy most of the viewport, so the generic full-surface
/// shimmer becomes a high-contrast vertical band on tall phones. This loader
/// keeps the card geometry stable and animates only a quiet focal mark and
/// small information placeholders.
class SilarahProfileCardShimmer extends StatefulWidget {
  const SilarahProfileCardShimmer({super.key});

  @override
  State<SilarahProfileCardShimmer> createState() =>
      _SilarahProfileCardShimmerState();
}

class _SilarahProfileCardShimmerState extends State<SilarahProfileCardShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      value: .34,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion &&
        (_controller.isAnimating || reduceMotion)) {
      return;
    }
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _controller
        ..stop()
        ..value = .5;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.uiCopy('Preparing profile recommendations'),
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final pulse = _reduceMotion
                ? .5
                : Curves.easeInOutCubic.transform(_controller.value);
            final tonalSurface = Color.lerp(
              AppColors.surfaceDark,
              AppColors.surfaceGlassHover,
              .16 + pulse * .12,
            )!;

            return ProfileCardBox(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.surfaceMid,
                        tonalSurface,
                        AppColors.surfaceDark,
                      ],
                      stops: const [0, .58, 1],
                    ),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusCard),
                    border: Border.all(
                      color: AppColors.cardBorder,
                      width: AppDimensions.borderThin,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        top: -64,
                        right: -58,
                        child: Container(
                          width: 210,
                          height: 210,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.champagneGold.withValues(
                              alpha: .025 + pulse * .018,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Transform.scale(
                          scale: .96 + pulse * .05,
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surfaceElevated
                                  .withValues(alpha: .88),
                              border: Border.all(
                                color: AppColors.cardBorder,
                              ),
                            ),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.champagneGold.withValues(
                                  alpha: .56 + pulse * .34,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.champagneGold.withValues(
                                      alpha: .08 + pulse * .09,
                                    ),
                                    blurRadius: 12,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: AppDimensions.space16,
                        right: AppDimensions.space16,
                        bottom: AppDimensions.space16,
                        child: Container(
                          padding: const EdgeInsets.all(AppDimensions.space16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated
                                .withValues(alpha: .90),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusButton,
                            ),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ProfileLoaderLine(
                                widthFactor: .28,
                                height: 9,
                                opacity: .34 + pulse * .08,
                              ),
                              const SizedBox(height: AppDimensions.space10),
                              _ProfileLoaderLine(
                                widthFactor: .58,
                                height: 16,
                                opacity: .46 + pulse * .08,
                              ),
                              const SizedBox(height: AppDimensions.space14),
                              Row(
                                children: [
                                  _ProfileLoaderPill(
                                    width: 68,
                                    opacity: .32 + pulse * .07,
                                  ),
                                  const SizedBox(width: AppDimensions.space8),
                                  _ProfileLoaderPill(
                                    width: 88,
                                    opacity: .28 + pulse * .07,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileLoaderLine extends StatelessWidget {
  const _ProfileLoaderLine({
    required this.widthFactor,
    required this.height,
    required this.opacity,
  });

  final double widthFactor;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.slateMist.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      );
}

class _ProfileLoaderPill extends StatelessWidget {
  const _ProfileLoaderPill({
    required this.width,
    required this.opacity,
  });

  final double width;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.slateMist.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        ),
      );
}

// Conversation List Item Shimmer
class SilarahConversationShimmer extends StatelessWidget {
  const SilarahConversationShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const SilarahShimmer(
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: AppDimensions.horizontalMargin,
          vertical: AppDimensions.space12,
        ),
        child: Row(
          children: [
            // Avatar
            ShimmerBox(width: 52, height: 52, radius: 26),
            SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(
                      width: 120, height: 14, radius: AppDimensions.radiusTiny),
                  SizedBox(height: AppDimensions.space8),
                  ShimmerBox(
                    width: double.infinity,
                    height: 12,
                    radius: AppDimensions.radiusTiny,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Interest Card Shimmer
class SilarahInterestShimmer extends StatelessWidget {
  const SilarahInterestShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SilarahShimmer(
      child: Container(
        margin: const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.horizontalMargin,
          0,
          AppDimensions.horizontalMargin,
          AppDimensions.space12,
        ),
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Row(
          children: [
            ShimmerBox(
                width: 56, height: 56, radius: AppDimensions.radiusButton),
            SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(
                      width: 140, height: 16, radius: AppDimensions.radiusTiny),
                  SizedBox(height: AppDimensions.space8),
                  ShimmerBox(
                      width: 100, height: 12, radius: AppDimensions.radiusTiny),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
