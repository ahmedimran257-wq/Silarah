// SILARAH — Discovery Empty State
// Shown when the feed runs out or the active filters match nobody. A mihrab
// arch draws itself in, then rests with a slow breathing glow and an
// occasional light sweep. The copy points at the one filter most likely to
// be narrowing the circle, and the actions keep a clear primary.
import 'package:silarah/l10n/ui_copy.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/cubits/discovery/discovery_filter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_curves.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations/silarah_motion.dart';
import '../../../core/widgets/animations/silarah_ornament.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/buttons/silarah_primary_button.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The filter the empty state suggests widening first, with the filter-sheet
/// section it opens.
enum DiscoveryEmptyHint {
  trust('verified'),
  deen('deen'),
  family('family'),
  sect('sect'),
  distance('distance'),
  location('location'),
  age('age'),
  other(null);

  const DiscoveryEmptyHint(this.section);

  final String? section;

  /// Picks the active filter that usually removes the most people, so the
  /// suggestion is specific rather than "try expanding your filters".
  static DiscoveryEmptyHint? forFilter(DiscoveryFilter filter) {
    if (!filter.isActive) return null;
    if (filter.trustFilter != null) return trust;
    if (filter.deenLevel != null) return deen;
    if (filter.familyType != null) return family;
    if (filter.sect != null) return sect;
    if (filter.effectiveMaxDistanceKm != null) return distance;
    if (filter.cityId != null ||
        filter.stateName != null ||
        filter.distanceLabel == 'Same City' ||
        filter.distanceLabel == 'Same State' ||
        filter.distanceLabel == 'Same State / Region') {
      return location;
    }
    if (filter.ageMin != null || filter.ageMax != null) return age;
    return other;
  }

  String label(AppLocalizations l10n) => switch (this) {
        trust => l10n.discovery_empty_hint_trust,
        deen => l10n.discovery_empty_hint_deen,
        family => l10n.discovery_empty_hint_family,
        sect => l10n.discovery_empty_hint_sect,
        distance || location => l10n.discovery_empty_hint_location,
        age => l10n.discovery_empty_hint_age,
        other => l10n.discovery_empty_hint_other,
      };
}

class DiscoveryEmptyState extends StatefulWidget {
  const DiscoveryEmptyState({
    super.key,
    required this.filter,
    required this.onClearFilters,
    required this.onRefresh,
    required this.onAdjustFilters,
  });

  final DiscoveryFilter filter;
  final VoidCallback onClearFilters;
  final VoidCallback onRefresh;

  /// Opens the filter sheet, scrolled to [section] when one is given.
  final ValueChanged<String?> onAdjustFilters;

  @override
  State<DiscoveryEmptyState> createState() => _DiscoveryEmptyStateState();
}

class _DiscoveryEmptyStateState extends State<DiscoveryEmptyState>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _entrance.value = 1;
      // A resting frame between light sweeps: glow present, no motion.
      _idle
        ..stop()
        ..value = 0.62;
    } else {
      if (_entrance.isDismissed) _entrance.forward();
      if (!_idle.isAnimating) _idle.repeat();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = widget.filter.isActive;
    final hint = DiscoveryEmptyHint.forFilter(widget.filter);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space32,
          vertical: AppDimensions.space16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(
              0,
              constraints.maxHeight - AppDimensions.space32,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    image: true,
                    label: filtered
                        ? l10n.discovery_empty_filtered_title
                        : l10n.discovery_empty_title,
                    child: RepaintBoundary(
                      child: SizedBox(
                        width: 232,
                        height: 196,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_entrance, _idle]),
                          builder: (context, _) => CustomPaint(
                            painter: DiscoveryArchPainter(
                              entrance: _entrance.value,
                              idle: _idle.value,
                              accent: AppColors.champagneGold,
                              accentHighlight: AppColors.champagneLight,
                              ornament: AppColors.inkTeal,
                              glow: AppColors.goldGlow,
                              hairline: AppColors.cardBorder,
                              surface: AppColors.surfaceElevated,
                              background: AppColors.obsidianNight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space24),
                  SilarahEntrance(
                    delay: const Duration(milliseconds: 520),
                    duration: const Duration(milliseconds: 620),
                    child: UiText(
                      filtered
                          ? l10n.discovery_empty_filtered_eyebrow
                          : l10n.discovery_empty_eyebrow,
                      textAlign: TextAlign.center,
                      style: AppTypography.sectionLabel.copyWith(
                        color: AppColors.champagneGold,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space10),
                  SilarahEntrance(
                    delay: const Duration(milliseconds: 600),
                    duration: const Duration(milliseconds: 640),
                    child: UiText(
                      filtered
                          ? l10n.discovery_empty_filtered_title
                          : l10n.discovery_empty_title,
                      textAlign: TextAlign.center,
                      style: AppTypography.screenTitle.copyWith(fontSize: 24),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  SilarahEntrance(
                    delay: const Duration(milliseconds: 690),
                    duration: const Duration(milliseconds: 640),
                    child: UiText(
                      filtered
                          ? l10n.discovery_empty_filtered_subtitle
                          : l10n.discovery_empty_subtitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMuted.copyWith(height: 1.6),
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: AppDimensions.space20),
                    SilarahEntrance(
                      delay: const Duration(milliseconds: 780),
                      duration: const Duration(milliseconds: 640),
                      child: _FilterHint(
                        label: hint.label(l10n),
                        onTap: () => widget.onAdjustFilters(hint.section),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.space28),
                  SilarahEntrance(
                    delay: const Duration(milliseconds: 860),
                    duration: const Duration(milliseconds: 640),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: SilarahPrimaryButton(
                        label: filtered
                            ? l10n.discovery_empty_clear_filters
                            : l10n.discovery_empty_refresh,
                        icon: filtered
                            ? Icons.filter_alt_off_outlined
                            : Icons.refresh_rounded,
                        onTap: filtered
                            ? widget.onClearFilters
                            : widget.onRefresh,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space8),
                  SilarahEntrance(
                    delay: const Duration(milliseconds: 940),
                    duration: const Duration(milliseconds: 640),
                    child: _QuietAction(
                      label: l10n.discovery_empty_adjust_filters,
                      icon: Icons.tune_rounded,
                      onTap: () => widget.onAdjustFilters(null),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Specific, tappable suggestion: opens the sheet at the named filter.
class _FilterHint extends StatelessWidget {
  const _FilterHint({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      semanticLabel: label,
      onTap: onTap,
      pressedScale: 0.985,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space12,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size.square(16),
              painter: _StarGlyphPainter(AppColors.inkTeal),
            ),
            const SizedBox(width: AppDimensions.space10),
            Flexible(
              child: UiText(
                label,
                style: AppTypography.bodyMedium.copyWith(height: 1.35),
              ),
            ),
            const SizedBox(width: AppDimensions.space8),
            Icon(
              Icons.chevron_right_rounded,
              size: AppDimensions.iconSizeMedium,
              color: AppColors.slateMist,
            ),
          ],
        ),
      ),
    );
  }
}

/// Text-weight secondary action, so the primary button stays the only
/// strong call to action on the screen.
class _QuietAction extends StatelessWidget {
  const _QuietAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppDimensions.iconSizeSmall + 2,
              color: AppColors.champagneGold,
            ),
            const SizedBox(width: AppDimensions.space8),
            Flexible(
              child: UiText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.buttonSecondary.copyWith(fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarGlyphPainter extends CustomPainter {
  const _StarGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final star = SilarahOrnament.khatam(
      size.center(Offset.zero),
      size.shortestSide / 2,
    );
    canvas
      ..drawPath(star, Paint()..color = color.withValues(alpha: .16))
      ..drawPath(
        star,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(covariant _StarGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Mihrab arch with a faint khatam lattice, a gold star at its heart and a
/// soft glow. [entrance] runs once (0→1); [idle] loops for the resting
/// breathe and the occasional light sweep across the arch.
class DiscoveryArchPainter extends CustomPainter {
  const DiscoveryArchPainter({
    required this.entrance,
    required this.idle,
    required this.accent,
    required this.accentHighlight,
    required this.ornament,
    required this.glow,
    required this.hairline,
    required this.surface,
    required this.background,
  });

  final double entrance;
  final double idle;
  final Color accent;
  final Color accentHighlight;
  final Color ornament;
  final Color glow;
  final Color hairline;
  final Color surface;
  final Color background;

  static double _phase(double t, double begin, double end,
          [Curve curve = AppCurves.reveal]) =>
      curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final ground = size.height - 10;
    final arch = Rect.fromLTRB(cx - 62, 12, cx + 62, ground);
    final breathe = (math.sin(idle * math.pi * 2) + 1) / 2;

    final fade = _phase(entrance, 0, .55);
    final draw = _phase(entrance, .04, .7, AppCurves.transition);
    final lattice = _phase(entrance, .3, .85);
    final star = _phase(entrance, .45, .95);

    // Breathing glow behind the arch.
    final glowCenter = Offset(cx, arch.top + arch.height * .48);
    final glowRadius = 104 + breathe * 8;
    canvas.drawCircle(
      glowCenter,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glow.withValues(alpha: glow.a * fade * (.75 + breathe * .25)),
            glow.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: glowRadius)),
    );

    // Ground hairline, fading out at both ends.
    final groundRect = Rect.fromLTRB(cx - 104, ground, cx + 104, ground + 1);
    canvas.drawRect(
      groundRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            hairline.withValues(alpha: 0),
            hairline.withValues(alpha: fade),
            hairline.withValues(alpha: 0),
          ],
        ).createShader(groundRect),
    );

    // Outer echo arch.
    final outer = Rect.fromLTRB(
      arch.left - 9,
      arch.top - 9,
      arch.right + 9,
      ground,
    );
    canvas.drawPath(
      SilarahOrnament.mihrab(outer),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: .16 * fade),
    );

    final archPath = SilarahOrnament.mihrab(arch);

    // Paper-like fill fading into the canvas at the base.
    canvas.drawPath(
      archPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            surface.withValues(alpha: fade),
            Color.lerp(surface, background, .5)!.withValues(alpha: .7 * fade),
            background.withValues(alpha: 0),
          ],
          stops: const [0, .62, 1],
        ).createShader(arch),
    );

    canvas
      ..save()
      ..clipPath(archPath);

    // Khatam lattice, strongest under the apex and dissolving downward.
    if (lattice > 0) {
      const cell = 26.0;
      final latticePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8;
      for (var y = arch.top + cell / 2; y < ground; y += cell) {
        final depth = ((y - arch.top) / arch.height).clamp(0.0, 1.0);
        final alpha = (1 - depth) * (1 - depth) * .55 * lattice;
        if (alpha < .02) continue;
        latticePaint.color = hairline.withValues(alpha: alpha);
        for (var x = cx - cell * 3; x <= cx + cell * 3 + .1; x += cell) {
          canvas.drawPath(
            SilarahOrnament.khatam(Offset(x, y), cell * .36),
            latticePaint,
          );
        }
      }
    }

    // A slow diagonal light sweep, then a long rest.
    final sweep = (idle / .32).clamp(0.0, 1.0);
    if (sweep > 0 && sweep < 1 && entrance >= 1) {
      final x = arch.left - 60 + (arch.width + 120) * Curves.easeInOut.transform(sweep);
      final band = Rect.fromLTRB(x - 40, arch.top, x + 40, ground);
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: const Alignment(-1, -.35),
            end: const Alignment(1, .35),
            colors: [
              accentHighlight.withValues(alpha: 0),
              accentHighlight.withValues(alpha: .11),
              accentHighlight.withValues(alpha: 0),
            ],
          ).createShader(band),
      );
    }
    canvas.restore();

    // Arch outline, drawn from the apex down both sides.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = accent;
    for (final half in SilarahOrnament.mihrabHalves(arch)) {
      canvas.drawPath(SilarahOrnament.trim(half, draw), outline);
    }

    // Finial dot at the apex once the outline has started.
    if (draw > 0) {
      canvas.drawCircle(
        Offset(cx, arch.top - 6),
        2.2 * draw,
        Paint()..color = ornament.withValues(alpha: draw),
      );
    }

    // Gold khatam star at the heart of the arch, settling from a small turn.
    if (star > 0) {
      final center = Offset(cx, arch.top + arch.height * .5);
      final rotation =
          (1 - star) * -math.pi / 8 + math.sin(idle * math.pi * 2) * .035;
      final radius = 20 * (.82 + .18 * star);
      canvas.drawCircle(
        center,
        34,
        Paint()
          ..shader = RadialGradient(
            colors: [
              ornament.withValues(alpha: (.16 + breathe * .08) * star),
              ornament.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: 34)),
      );
      final starPath =
          SilarahOrnament.khatam(center, radius, rotation: rotation);
      canvas
        ..drawPath(
          starPath,
          Paint()..color = ornament.withValues(alpha: .14 * star),
        )
        ..drawPath(
          starPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeJoin = StrokeJoin.round
            ..color = ornament.withValues(alpha: star),
        )
        ..drawCircle(
          center,
          4.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = accent.withValues(alpha: star),
        );
    }
  }

  @override
  bool shouldRepaint(covariant DiscoveryArchPainter oldDelegate) =>
      oldDelegate.entrance != entrance ||
      oldDelegate.idle != idle ||
      oldDelegate.accent != accent ||
      oldDelegate.ornament != ornament ||
      oldDelegate.surface != surface ||
      oldDelegate.background != background;
}
