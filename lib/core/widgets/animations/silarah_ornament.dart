import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Shared geometry for Silarah's brand ornaments: the pointed Mughal arch
/// (mihrab) and the eight-point khatam star used in the store artwork.
///
/// Coordinates are normalised from `release/play-store/feature-graphic.html`
/// so the in-app illustrations and the store graphics share one silhouette.
abstract final class SilarahOrnament {
  /// Closed arch silhouette filling [bounds], open edge along the bottom.
  static Path mihrab(Rect bounds) {
    final p = _mapper(bounds);
    return Path()
      ..moveTo(p(0, 1).dx, p(0, 1).dy)
      ..lineTo(p(0, .3987).dx, p(0, .3987).dy)
      .._cubic(p(0, .2405), p(.2031, .1392), p(.375, .0844))
      .._cubic(p(.43125, .0654), p(.475, .038), p(.5, 0))
      .._cubic(p(.525, .038), p(.56875, .0654), p(.625, .0844))
      .._cubic(p(.7969, .1392), p(1, .2405), p(1, .3987))
      ..lineTo(p(1, 1).dx, p(1, 1).dy)
      ..close();
  }

  /// The arch outline as two strokes that both start at the apex, so a
  /// progressive draw grows symmetrically down each side.
  static List<Path> mihrabHalves(Rect bounds) {
    final p = _mapper(bounds);
    final apex = p(.5, 0);
    final left = Path()
      ..moveTo(apex.dx, apex.dy)
      .._cubic(p(.475, .038), p(.43125, .0654), p(.375, .0844))
      .._cubic(p(.2031, .1392), p(0, .2405), p(0, .3987))
      ..lineTo(p(0, 1).dx, p(0, 1).dy);
    final right = Path()
      ..moveTo(apex.dx, apex.dy)
      .._cubic(p(.525, .038), p(.56875, .0654), p(.625, .0844))
      .._cubic(p(.7969, .1392), p(1, .2405), p(1, .3987))
      ..lineTo(p(1, 1).dx, p(1, 1).dy);
    return [left, right];
  }

  /// Eight-point star ({8/2} octagram) centred on [center].
  static Path khatam(Offset center, double radius, {double rotation = 0}) {
    // Ratio of the inner vertices for two overlapping squares.
    final inner = radius * math.cos(math.pi / 4) / math.cos(math.pi / 8);
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final r = i.isEven ? radius : inner;
      final angle = rotation - math.pi / 2 + i * math.pi / 8;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  /// Returns the first [fraction] of every contour in [path].
  static Path trim(Path path, double fraction) {
    final out = Path();
    if (fraction <= 0) return out;
    for (final metric in path.computeMetrics()) {
      out.addPath(
        metric.extractPath(0, metric.length * fraction.clamp(0.0, 1.0)),
        Offset.zero,
      );
    }
    return out;
  }

  static Offset Function(double, double) _mapper(Rect bounds) =>
      (x, y) => Offset(
            bounds.left + x * bounds.width,
            bounds.top + y * bounds.height,
          );
}

extension on Path {
  void _cubic(Offset c1, Offset c2, Offset end) =>
      cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
}
