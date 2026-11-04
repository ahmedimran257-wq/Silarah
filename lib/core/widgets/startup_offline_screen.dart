import 'package:silarah/l10n/ui_copy.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_curves.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import '../services/connectivity_service.dart';
import '../../l10n/generated/app_localizations.dart';
import 'animations/silarah_motion.dart';
import 'animations/silarah_ornament.dart';
import 'buttons/silarah_pressable.dart';
import 'loaders/silarah_shimmer.dart';

/// Full-screen startup state shown before authentication when Silarah's
/// backend cannot be reached. It intentionally keeps the router hidden so a
/// network failure can never masquerade as a signed-out session.
///
/// The tone is calm rather than alarming: a brand medallion with slow
/// concentric ripples, reassuring copy and one clear retry. Reconnection
/// itself stays automatic and is owned by the root bootstrap.
class StartupOfflineScreen extends StatefulWidget {
  const StartupOfflineScreen({
    super.key,
    required this.onRetry,
    this.quality = BackendConnectionQuality.offline,
  });

  final Future<bool> Function() onRetry;
  final BackendConnectionQuality quality;

  @override
  State<StartupOfflineScreen> createState() => _StartupOfflineScreenState();
}

class _StartupOfflineScreenState extends State<StartupOfflineScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ripple;
  late final AnimationController _entrance;
  bool _retrying = false;
  bool _retryFailed = false;

  @override
  void initState() {
    super.initState();
    _ripple = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    );
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _entrance.value = 1;
      _ripple
        ..stop()
        ..value = 0.35;
    } else {
      if (_entrance.isDismissed) _entrance.forward();
      if (!_ripple.isAnimating) _ripple.repeat();
    }
  }

  @override
  void dispose() {
    _ripple.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _retryFailed = false;
    });
    final online = await widget.onRetry();
    if (!mounted) return;
    if (!online) {
      setState(() {
        _retrying = false;
        _retryFailed = true;
      });
    }
  }

  BackendConnectionQuality get _visualQuality {
    if (_retryFailed) return BackendConnectionQuality.offline;
    if (_retrying &&
        (widget.quality == BackendConnectionQuality.good ||
            widget.quality == BackendConnectionQuality.poor)) {
      return widget.quality;
    }
    if (_retrying) return BackendConnectionQuality.unknown;
    return BackendConnectionQuality.offline;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.24),
            radius: 1.0,
            colors: [
              AppColors.surfaceGlass,
              AppColors.obsidianNight,
              AppColors.obsidianDeep,
            ],
            stops: const [0, 0.62, 1],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.space24,
                AppDimensions.space20,
                AppDimensions.space24,
                AppDimensions.space24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(
                    0,
                    constraints.maxHeight -
                        AppDimensions.space20 -
                        AppDimensions.space24,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SilarahEntrance(child: _OfflineWordmark()),
                      const Spacer(flex: 2),
                      Semantics(
                        image: true,
                        label: l10n.startup_connectivity_offline_body,
                        child: Center(
                          child: RepaintBoundary(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(end: _retrying ? 1 : 0),
                              duration: AppDimensions.durationTactile,
                              curve: AppCurves.transition,
                              builder: (context, checking, _) =>
                                  AnimatedBuilder(
                                animation:
                                    Listenable.merge([_ripple, _entrance]),
                                builder: (context, _) => CustomPaint(
                                  size: const Size.square(216),
                                  painter: QuietSignalPainter(
                                    progress: _ripple.value,
                                    entrance: _entrance.value,
                                    checking: checking,
                                    signal: _connectionColor(_visualQuality),
                                    accent: AppColors.champagneGold,
                                    ornament: AppColors.inkTeal,
                                    glow: AppColors.goldGlow,
                                    surface: AppColors.surfaceElevated,
                                    hairline: AppColors.cardBorder,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space32),
                      SilarahEntrance(
                        delay: const Duration(milliseconds: 260),
                        duration: const Duration(milliseconds: 620),
                        child: UiText(
                          l10n.startup_connectivity_offline_title,
                          textAlign: TextAlign.center,
                          style: AppTypography.screenTitle.copyWith(
                            fontSize: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space12),
                      SilarahEntrance(
                        delay: const Duration(milliseconds: 340),
                        duration: const Duration(milliseconds: 620),
                        child: UiText(
                          l10n.startup_connectivity_offline_body,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMuted.copyWith(height: 1.6),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space24),
                      SilarahEntrance(
                        delay: const Duration(milliseconds: 420),
                        duration: const Duration(milliseconds: 620),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: AppDimensions.durationTactile,
                            switchInCurve: AppCurves.reveal,
                            switchOutCurve: AppCurves.dismiss,
                            child: _ConnectionStatus(
                              key: ValueKey(
                                (_retrying, _retryFailed, _visualQuality),
                              ),
                              retrying: _retrying,
                              retryFailed: _retryFailed,
                              quality: _visualQuality,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(flex: 3),
                      const SizedBox(height: AppDimensions.space24),
                      SilarahEntrance(
                        delay: const Duration(milliseconds: 500),
                        duration: const Duration(milliseconds: 620),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.wifi_rounded,
                              size: AppDimensions.iconSizeSmall,
                              color: AppColors.slateMist,
                            ),
                            const SizedBox(width: AppDimensions.space8),
                            Flexible(
                              child: UiText(
                                l10n.startup_connectivity_tip,
                                textAlign: TextAlign.center,
                                style: AppTypography.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space16),
                      SilarahEntrance(
                        delay: const Duration(milliseconds: 560),
                        duration: const Duration(milliseconds: 620),
                        child: _RetryButton(
                          retrying: _retrying,
                          onTap: _retry,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space14),
                      SilarahEntrance(
                        delay: const Duration(milliseconds: 620),
                        duration: const Duration(milliseconds: 620),
                        child: UiText(
                          l10n.startup_connectivity_auto,
                          textAlign: TextAlign.center,
                          style: AppTypography.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineWordmark extends StatelessWidget {
  const _OfflineWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 24, child: Divider(color: AppColors.goldBorder)),
        const SizedBox(width: AppDimensions.space12),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: UiText('SILARAH', style: AppTypography.wordmark),
          ),
        ),
        const SizedBox(width: AppDimensions.space12),
        SizedBox(width: 24, child: Divider(color: AppColors.goldBorder)),
      ],
    );
  }
}

/// Filled retry action. While a check runs, the label and icon cross-fade
/// to a spinner and "Checking…" so the tap is acknowledged immediately.
class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.retrying, required this.onTap});

  final bool retrying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = retrying
        ? l10n.startup_connectivity_checking
        : l10n.startup_connectivity_check;
    final onAccent = AppColors.obsidianNight;
    return SilarahPressable(
      semanticLabel: label,
      // Stays at full strength while busy (a disabled button would fade to
      // half opacity); the retry itself is single-flight.
      haptic: !retrying,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTactile,
        curve: AppCurves.transition,
        height: AppDimensions.buttonHeight,
        decoration: BoxDecoration(
          color: AppColors.champagneGold,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          boxShadow: [
            BoxShadow(
              color: AppColors.champagneGold.withValues(
                alpha: retrying ? .06 : .16,
              ),
              blurRadius: 20,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: AppDimensions.durationTactile,
          switchInCurve: AppCurves.reveal,
          switchOutCurve: AppCurves.dismiss,
          child: Row(
            key: ValueKey(retrying),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (retrying)
                SilarahActivityIndicator(size: 18, color: onAccent)
              else
                Icon(
                  Icons.refresh_rounded,
                  size: AppDimensions.iconSizeMedium,
                  color: onAccent,
                ),
              const SizedBox(width: AppDimensions.space10),
              Flexible(
                child: UiText(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.button.copyWith(color: onAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({
    super.key,
    required this.retrying,
    required this.retryFailed,
    required this.quality,
  });

  final bool retrying;
  final bool retryFailed;
  final BackendConnectionQuality quality;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = retrying
        ? l10n.startup_connectivity_verifying
        : retryFailed
            ? l10n.startup_connectivity_still_waiting
            : l10n.startup_connectivity_waiting;
    final signalColor = _connectionColor(quality);
    return Semantics(
      liveRegion: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space14,
          vertical: AppDimensions.space8,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: signalColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: signalColor.withValues(alpha: .38),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.space8),
            Flexible(
              child: UiText(label, style: AppTypography.sectionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Offline is a waiting state, not an error, so it uses the brand accent;
/// a degraded link reads as amber and a restored one as green.
Color _connectionColor(BackendConnectionQuality quality) => switch (quality) {
      BackendConnectionQuality.good => AppColors.onlineGreen,
      BackendConnectionQuality.poor ||
      BackendConnectionQuality.unknown =>
        AppColors.expiryAmber,
      BackendConnectionQuality.offline => AppColors.champagneGold,
    };

/// A brand medallion (mihrab arch around a khatam star) with concentric
/// ripples that slowly widen and fade. While a check runs, a thin arc
/// orbits the medallion so the illustration itself shows the work.
class QuietSignalPainter extends CustomPainter {
  const QuietSignalPainter({
    required this.progress,
    required this.entrance,
    required this.checking,
    required this.signal,
    required this.accent,
    required this.ornament,
    required this.glow,
    required this.surface,
    required this.hairline,
  });

  final double progress;
  final double entrance;
  final double checking;
  final Color signal;
  final Color accent;
  final Color ornament;
  final Color glow;
  final Color surface;
  final Color hairline;

  static const double _medallion = 44;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final appear = AppCurves.reveal.transform(entrance.clamp(0.0, 1.0));
    final breathe = (math.sin(progress * math.pi * 2) + 1) / 2;

    // Soft halo.
    final haloRadius = size.width / 2;
    canvas.drawCircle(
      center,
      haloRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glow.withValues(alpha: glow.a * appear * (.8 + breathe * .2)),
            glow.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: haloRadius)),
    );

    // Three ripples, evenly staggered, widening from the medallion edge.
    final ripple = Paint()..style = PaintingStyle.stroke;
    const reach = 58.0;
    for (var i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1;
      final eased = Curves.easeOut.transform(t);
      final fade = math.pow(1 - t, 1.6).toDouble();
      ripple
        ..strokeWidth = 1.4 - t * .6
        ..color = signal.withValues(alpha: .34 * fade * appear);
      canvas.drawCircle(center, _medallion + 6 + eased * reach, ripple);
    }

    // Medallion.
    final scale = .9 + .1 * appear;
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(scale)
      ..translate(-center.dx, -center.dy);
    canvas.drawCircle(
      center,
      _medallion,
      Paint()..color = surface.withValues(alpha: appear),
    );
    canvas.drawCircle(
      center,
      _medallion,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = hairline.withValues(alpha: appear),
    );
    canvas.drawCircle(
      center,
      _medallion - 5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = accent.withValues(alpha: .18 * appear),
    );

    final arch = Rect.fromCenter(
      center: center.translate(0, 2),
      width: 34,
      height: 46,
    );
    canvas.drawPath(
      SilarahOrnament.mihrab(arch),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = accent.withValues(alpha: appear),
    );
    final star = SilarahOrnament.khatam(
      center.translate(0, 8),
      8.5,
      rotation: math.sin(progress * math.pi * 2) * .06,
    );
    canvas
      ..drawPath(
        star,
        Paint()..color = ornament.withValues(alpha: (.18 + breathe * .1) * appear),
      )
      ..drawPath(
        star,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeJoin = StrokeJoin.round
          ..color = ornament.withValues(alpha: appear),
      );
    canvas.restore();

    // Orbiting arc while a connection check is in flight.
    if (checking > 0) {
      final orbit = Rect.fromCircle(center: center, radius: _medallion + 8);
      final start = progress * math.pi * 2 * 3 - math.pi / 2;
      canvas.drawArc(
        orbit,
        start,
        math.pi * .55,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = signal.withValues(alpha: checking),
      );
    }
  }

  @override
  bool shouldRepaint(covariant QuietSignalPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.entrance != entrance ||
      oldDelegate.checking != checking ||
      oldDelegate.signal != signal ||
      oldDelegate.accent != accent ||
      oldDelegate.surface != surface;
}
