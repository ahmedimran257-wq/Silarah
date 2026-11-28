// SILARAH - Continue with Google button
// Google's sign-in branding for Android, dark theme: #131314 fill, #8E918F
// border, #E3E3E3 label, the standard four-colour "G" unchanged.
import 'package:flutter/material.dart';
import 'package:silarah/l10n/ui_copy.dart';

import '../../theme/app_dimensions.dart';
import '../loaders/silarah_shimmer.dart';
import 'silarah_pressable.dart';

class ContinueWithGoogleButton extends StatelessWidget {
  const ContinueWithGoogleButton({
    super.key,
    required this.onTap,
    this.isLoading = false,
  });

  static const label = 'Continue with Google';

  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !isLoading;
    return SilarahPressable(
      onTap: onTap,
      enabled: enabled,
      semanticLabel: context.uiCopy(label),
      child: AnimatedOpacity(
        duration: AppDimensions.durationTransition,
        opacity: enabled || isLoading ? 1 : .55,
        child: Container(
          height: AppDimensions.buttonHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF131314),
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            border: Border.all(color: const Color(0xFF8E918F)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SilarahPulseLoader(size: 22)
              else
                const SizedBox.square(
                  dimension: 20,
                  child: CustomPaint(painter: GoogleGPainter()),
                ),
              const SizedBox(width: 12),
              const Flexible(
                child: UiText(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFE3E3E3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The standard Google "G" (48 x 48 artboard), drawn from its path data.
class GoogleGPainter extends CustomPainter {
  const GoogleGPainter();

  static const _parts = <(int, String)>[
    (
      0xFFEA4335,
      'M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 '
          '14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z',
    ),
    (
      0xFF4285F4,
      'M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 '
          '5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z',
    ),
    (
      0xFFFBBC05,
      'M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19'
          'C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z',
    ),
    (
      0xFF34A853,
      'M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 '
          '2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z',
    ),
  ];

  static final List<(Color, Path)> _paths = [
    for (final (color, data) in _parts) (Color(color), parseSvgPath(data)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    for (final (color, path) in _paths) {
      canvas.drawPath(path, Paint()..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GoogleGPainter oldDelegate) => false;
}

/// The subset of SVG path syntax the logo uses: M, L, H, V, C, S and Z, in
/// absolute and relative form, with implicit repeats.
@visibleForTesting
Path parseSvgPath(String data) {
  final tokens = RegExp(r'[MmLlHhVvCcSsZz]|-?(?:\d+\.?\d*|\.\d+)')
      .allMatches(data)
      .map((m) => m.group(0)!)
      .toList();
  final path = Path();
  var i = 0;
  var command = '';
  var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;
  var lastControlX = 0.0, lastControlY = 0.0;
  var lastWasCurve = false;

  bool isCommand(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double next() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    if (isCommand(tokens[i])) command = tokens[i++];
    final relative = command == command.toLowerCase();
    final dx = relative ? x : 0.0;
    final dy = relative ? y : 0.0;
    switch (command.toUpperCase()) {
      case 'M':
        x = next() + dx;
        y = next() + dy;
        path.moveTo(x, y);
        startX = x;
        startY = y;
        // Further pairs after a move are lines.
        command = relative ? 'l' : 'L';
        lastWasCurve = false;
      case 'L':
        x = next() + dx;
        y = next() + dy;
        path.lineTo(x, y);
        lastWasCurve = false;
      case 'H':
        x = next() + (relative ? x : 0.0);
        path.lineTo(x, y);
        lastWasCurve = false;
      case 'V':
        y = next() + (relative ? y : 0.0);
        path.lineTo(x, y);
        lastWasCurve = false;
      case 'C':
        final x1 = next() + dx, y1 = next() + dy;
        final x2 = next() + dx, y2 = next() + dy;
        x = next() + dx;
        y = next() + dy;
        path.cubicTo(x1, y1, x2, y2, x, y);
        lastControlX = x2;
        lastControlY = y2;
        lastWasCurve = true;
      case 'S':
        final x1 = lastWasCurve ? 2 * x - lastControlX : x;
        final y1 = lastWasCurve ? 2 * y - lastControlY : y;
        final x2 = next() + dx, y2 = next() + dy;
        x = next() + dx;
        y = next() + dy;
        path.cubicTo(x1, y1, x2, y2, x, y);
        lastControlX = x2;
        lastControlY = y2;
        lastWasCurve = true;
      case 'Z':
        path.close();
        x = startX;
        y = startY;
        lastWasCurve = false;
      default:
        throw FormatException('Unsupported path command $command');
    }
  }
  return path;
}
