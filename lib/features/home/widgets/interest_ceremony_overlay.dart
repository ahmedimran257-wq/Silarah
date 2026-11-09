import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:silarah/l10n/ui_copy.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_curves.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// Confirms an interest with a brief, restrained acknowledgement.
///
/// The public name is retained for call-site compatibility. The previous
/// decorative ceremony has been replaced by a single precision seal so the
/// member can continue without waiting through a celebration sequence.
Future<void> showInterestCeremony(
  BuildContext context, {
  required String firstName,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: context.uiCopy('Interest Sent'),
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, __) =>
        _InterestAcknowledgement(firstName: firstName),
  );
}

class _InterestAcknowledgement extends StatefulWidget {
  const _InterestAcknowledgement({required this.firstName});

  final String firstName;

  @override
  State<_InterestAcknowledgement> createState() =>
      _InterestAcknowledgementState();
}

class _InterestAcknowledgementState extends State<_InterestAcknowledgement>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _reveal;
  bool _started = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDimensions.durationAcknowledgement,
      reverseDuration: AppDimensions.durationDialogExit,
    );
    _reveal = CurvedAnimation(
      parent: _controller,
      curve: AppCurves.reveal,
      reverseCurve: AppCurves.dismiss,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _controller.value = 1;
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (!mounted) return;
    if (!_reduceMotion) await _controller.forward();
    await Future<void>.delayed(AppDimensions.acknowledgementHold);
    if (!mounted) return;
    if (!_reduceMotion) await _controller.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _reveal,
      builder: (context, _) {
        final value = _reduceMotion ? 1.0 : _reveal.value;
        final textValue =
            const Interval(.28, 1, curve: AppCurves.reveal).transform(value);
        final checkValue =
            const Interval(.08, .68, curve: AppCurves.reveal).transform(value);

        return Opacity(
          opacity: value,
          child: ColoredBox(
            color: AppColors.overlayBlack55,
            child: Center(
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - value)),
                child: Transform.scale(
                  scale: .985 + value * .015,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space24,
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusCard,
                      ),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: AppColors.active.mode.isDark ? .42 : .16,
                          ),
                          blurRadius: 34,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: AppColors.goldGlow,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.goldBorder),
                          ),
                          child: CustomPaint(
                            painter: _AcknowledgementPainter(
                              progress: checkValue,
                              color: AppColors.champagneGold,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space20),
                        Opacity(
                          opacity: textValue,
                          child: Transform.translate(
                            offset: Offset(0, 5 * (1 - textValue)),
                            child: Column(
                              children: [
                                UiText(
                                  context.uiCopy('Interest Sent'),
                                  style: AppTypography.screenTitle.copyWith(
                                    fontSize: 23,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(
                                  height: AppDimensions.space6,
                                ),
                                UiText(
                                  context.uiCopyWith(
                                      'to {name}', {'name': widget.firstName}),
                                  style: AppTypography.bodyMuted,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AcknowledgementPainter extends CustomPainter {
  const _AcknowledgementPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.2, size.shortestSide * .085)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final start = Offset(size.width * .16, size.height * .52);
    final middle = Offset(size.width * .41, size.height * .73);
    final end = Offset(size.width * .84, size.height * .28);
    final firstLength = (middle - start).distance;
    final secondLength = (end - middle).distance;
    final distance = (firstLength + secondLength) * progress;
    final path = Path()..moveTo(start.dx, start.dy);

    if (distance <= firstLength) {
      final point = Offset.lerp(start, middle, distance / firstLength)!;
      path.lineTo(point.dx, point.dy);
    } else {
      path.lineTo(middle.dx, middle.dy);
      final point = Offset.lerp(
        middle,
        end,
        ((distance - firstLength) / secondLength).clamp(0.0, 1.0),
      )!;
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_AcknowledgementPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
