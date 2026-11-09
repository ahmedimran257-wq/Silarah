import 'package:silarah/l10n/ui_copy.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/referral_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_primary_button.dart';
import '../../../core/widgets/buttons/silarah_secondary_button.dart';
import '../../../core/widgets/silarah_launch_sequence.dart';
import '../../../core/widgets/silarah_product_guide.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Unauthenticated landing surface. The opening greeting belongs exclusively
/// to [SilarahLaunchSequence]; this screen communicates the product promise.
class SplashBrandScreen extends StatefulWidget {
  const SplashBrandScreen({super.key});

  @override
  State<SplashBrandScreen> createState() => _SplashBrandScreenState();
}

class _SplashBrandScreenState extends State<SplashBrandScreen>
    with TickerProviderStateMixin {
  late final AnimationController _orchestrator;
  late final AnimationController _ambient;
  late final Animation<double> _lockupOpacity;
  late final Animation<Offset> _lockupSlide;
  late final Animation<double> _heroOpacity;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _primaryOpacity;
  late final Animation<Offset> _primarySlide;
  late final Animation<double> _secondaryOpacity;
  late final Animation<Offset> _secondarySlide;
  late final Animation<double> _tertiaryOpacity;
  bool _motionPreferenceApplied = false;
  bool _orchestrationStarted = false;

  @override
  void initState() {
    super.initState();
    _orchestrator = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    _lockupOpacity = CurvedAnimation(
      parent: _orchestrator,
      curve: const Interval(0, .25, curve: Curves.easeOutCubic),
    );
    _lockupSlide = Tween<Offset>(
      begin: const Offset(0, .06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _orchestrator,
        curve: const Interval(0, .30, curve: Curves.easeOutCubic),
      ),
    );
    _heroOpacity = CurvedAnimation(
      parent: _orchestrator,
      curve: const Interval(.12, .48, curve: Curves.easeOutCubic),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, .045),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _orchestrator,
        curve: const Interval(.12, .52, curve: Curves.easeOutCubic),
      ),
    );
    _primaryOpacity = CurvedAnimation(
      parent: _orchestrator,
      curve: const Interval(.35, .60, curve: Curves.easeOutCubic),
    );
    _primarySlide = Tween<Offset>(
      begin: const Offset(0, .12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _orchestrator,
        curve: const Interval(.35, .65, curve: Curves.easeOutCubic),
      ),
    );
    _secondaryOpacity = CurvedAnimation(
      parent: _orchestrator,
      curve: const Interval(.45, .70, curve: Curves.easeOutCubic),
    );
    _secondarySlide = Tween<Offset>(
      begin: const Offset(0, .12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _orchestrator,
        curve: const Interval(.45, .75, curve: Curves.easeOutCubic),
      ),
    );
    _tertiaryOpacity = CurvedAnimation(
      parent: _orchestrator,
      curve: const Interval(.60, .85, curve: Curves.easeOutCubic),
    );
    SilarahLaunchSequence.revealCompleted.addListener(_handleLaunchReveal);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionPreferenceApplied) return;
    _motionPreferenceApplied = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _orchestrationStarted = true;
      _orchestrator.value = 1;
      _ambient.value = .32;
    } else {
      _handleLaunchReveal();
    }
  }

  void _handleLaunchReveal() {
    if (!mounted ||
        !_motionPreferenceApplied ||
        _orchestrationStarted ||
        !SilarahLaunchSequence.revealCompleted.value) {
      return;
    }
    _orchestrationStarted = true;
    _orchestrator.forward();
    _ambient.repeat();
  }

  @override
  void dispose() {
    SilarahLaunchSequence.revealCompleted.removeListener(_handleLaunchReveal);
    _orchestrator.dispose();
    _ambient.dispose();
    super.dispose();
  }

  void _lightTap(VoidCallback action) {
    HapticFeedback.lightImpact();
    action();
  }

  Future<void> _showReferralSheet(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final l10n = AppLocalizations.of(context);
    final codeController = TextEditingController();
    var isSaving = false;

    final saved = await showSilarahBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surfaceMid,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final bottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.space24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppDimensions.space8),
                  UiText(
                    l10n.splash_referral_title,
                    style: AppTypography.screenTitle.copyWith(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  UiText(
                    l10n.splash_referral_subtitle,
                    style: AppTypography.bodyMuted,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.space24),
                  TextField(
                    controller: codeController,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    style: AppTypography.inputText,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9]'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.splash_referral_title,
                      hintText: l10n.splash_referral_hint,
                      hintStyle: AppTypography.inputLabel,
                      filled: true,
                      fillColor: AppColors.inputSurface,
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusButton,
                        ),
                        borderSide: BorderSide(color: AppColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusButton,
                        ),
                        borderSide: BorderSide(color: AppColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusButton,
                        ),
                        borderSide: BorderSide(
                          color: AppColors.champagneGold,
                          width: AppDimensions.borderThin,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.champagneGold,
                      foregroundColor: AppColors.obsidianNight,
                      minimumSize: const Size(
                        double.infinity,
                        AppDimensions.buttonHeight,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusButton,
                        ),
                      ),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final code =
                                codeController.text.trim().toUpperCase();
                            if (code.length != 6) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: UiText(
                                    l10n.splash_referral_invalid,
                                    style: TextStyle(
                                      color: AppColors.readableOn(
                                          AppColors.errorRed),
                                    ),
                                  ),
                                  backgroundColor: AppColors.errorRed,
                                ),
                              );
                              return;
                            }
                            setSheetState(() => isSaving = true);
                            try {
                              final isValid = await ReferralService.instance
                                  .validateCode(code);
                              if (!sheetContext.mounted) return;
                              if (!isValid) {
                                setSheetState(() => isSaving = false);
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(
                                    content: UiText(
                                      l10n.splash_referral_invalid,
                                      style: TextStyle(
                                        color: AppColors.readableOn(
                                          AppColors.errorRed,
                                        ),
                                      ),
                                    ),
                                    backgroundColor: AppColors.errorRed,
                                  ),
                                );
                                return;
                              }
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setString(
                                  'pending_referral_code', code);
                              if (!sheetContext.mounted) return;
                              Navigator.pop(sheetContext, true);
                            } catch (_) {
                              if (!sheetContext.mounted) return;
                              setSheetState(() => isSaving = false);
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: UiText(l10n.common_error_generic),
                                  backgroundColor: AppColors.errorRed,
                                ),
                              );
                            }
                          },
                    child: isSaving
                        ? SilarahActivityIndicator(
                            size: 20,
                            color: AppColors.obsidianNight,
                          )
                        : UiText(
                            l10n.splash_referral_button,
                            style: AppTypography.button,
                          ),
                  ),
                  const SizedBox(height: AppDimensions.space12),
                ],
              ),
            ),
          );
        },
      ),
    );
    codeController.dispose();

    // Wait for the modal route to finish closing before using the parent
    // messenger. This prevents a disposed sheet context (or a fast double
    // submit) from replacing the discovery tab with ErrorWidget.
    if (saved != true || !mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: UiText(
          l10n.splash_referral_saved,
          style: AppTypography.body.copyWith(
            color: AppColors.readableOn(AppColors.surfaceGlassHover),
          ),
        ),
        backgroundColor: AppColors.surfaceGlassHover,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          side: BorderSide(color: AppColors.cardBorder),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: _WelcomeCanvas(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 700;
              return CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: compact ? 64 : 76,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              FadeTransition(
                                opacity: _lockupOpacity,
                                child: SlideTransition(
                                  position: _lockupSlide,
                                  child: const SilarahCompactLockup(),
                                ),
                              ),
                              PositionedDirectional(
                                start: 12,
                                child: FadeTransition(
                                  opacity: _tertiaryOpacity,
                                  child: Semantics(
                                    button: true,
                                    label: context.uiCopy('Change language'),
                                    child: InkResponse(
                                      onTap: () => _lightTap(
                                        () => context
                                            .go(AppRoutes.languageSelect),
                                      ),
                                      radius: 28,
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceGlass,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.cardBorder,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.champagneGold
                                                  .withValues(alpha: .07),
                                              blurRadius: 18,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.language_rounded,
                                          color: AppColors.pearlWhite,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: FadeTransition(
                            opacity: _heroOpacity,
                            child: SlideTransition(
                              position: _heroSlide,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 440),
                                  child: _IntentionalUnionHero(
                                    reveal: _orchestrator,
                                    ambient: _ambient,
                                    compact: compact,
                                    title: l10n.splash_intention_title,
                                    subtitle: l10n.splash_intention_subtitle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppDimensions.space24,
                            compact
                                ? AppDimensions.space12
                                : AppDimensions.space20,
                            AppDimensions.space24,
                            compact
                                ? AppDimensions.space20
                                : AppDimensions.space32,
                          ),
                          child: Column(
                            children: [
                              FadeTransition(
                                opacity: _primaryOpacity,
                                child: SlideTransition(
                                  position: _primarySlide,
                                  child: SilarahPrimaryButton(
                                    label: l10n.splash_button_createProfile,
                                    haptic: false,
                                    onTap: () => _lightTap(
                                      () => context.push(AppRoutes.legal),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppDimensions.space12),
                              FadeTransition(
                                opacity: _secondaryOpacity,
                                child: SlideTransition(
                                  position: _secondarySlide,
                                  child: SilarahSecondaryButton(
                                    label: l10n.splash_button_signIn,
                                    haptic: false,
                                    onTap: () => _lightTap(
                                      () => context.push(
                                        '${AppRoutes.email}?mode=signin',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppDimensions.space8),
                              FadeTransition(
                                opacity: _tertiaryOpacity,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Semantics(
                                        label: context.uiCopy(
                                          'I have a Guardian invitation',
                                        ),
                                        button: true,
                                        child: TextButton(
                                          onPressed: () => _lightTap(
                                            () => context.push(
                                              AppRoutes.guardianConnect,
                                            ),
                                          ),
                                          child: UiText(
                                            context
                                                .uiCopy('Guardian invitation'),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            style: AppTypography.captionMedium
                                                .copyWith(
                                              color: AppColors.champagneGold,
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () => _lightTap(
                                          () => _showReferralSheet(context),
                                        ),
                                        child: UiText(
                                          l10n.splash_referral_question,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          style: AppTypography.captionMedium
                                              .copyWith(
                                            color: AppColors.champagneGold,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FadeTransition(
                                opacity: _tertiaryOpacity,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    HapticFeedback.selectionClick();
                                    await SilarahProductGuide.show(context);
                                  },
                                  icon: Icon(
                                    Icons.menu_book_outlined,
                                    size: 17,
                                    color: AppColors.slateMist,
                                  ),
                                  label: UiText(
                                    context.uiCopy('How Silarah works'),
                                    style: AppTypography.captionMedium.copyWith(
                                      color: AppColors.slateMist,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _IntentionalUnionHero extends StatelessWidget {
  const _IntentionalUnionHero({
    required this.reveal,
    required this.ambient,
    required this.compact,
    required this.title,
    required this.subtitle,
  });

  final Animation<double> reveal;
  final Animation<double> ambient;
  final bool compact;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([reveal, ambient]),
      builder: (context, _) => RepaintBoundary(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 260 : 380),
          child: CustomPaint(
            painter: _UnionArchPainter(
              reveal: reveal.value,
              ambient: ambient.value,
              accent: AppColors.champagneGold,
              highlight: AppColors.champagneLight,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.space24,
                compact ? 56 : 82,
                AppDimensions.space24,
                compact ? 8 : 10,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  UiText(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTypography.screenTitle.copyWith(
                      color: AppColors.pearlWhite,
                      fontSize: compact ? 31 : 36,
                      height: 1.12,
                      letterSpacing: -.55,
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: UiText(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMuted.copyWith(
                        color: AppColors.slateMist,
                        fontSize: compact ? 14 : 15,
                        height: 1.55,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 18 : 28),
                  // Quiet reassurance for families deciding whether to trust
                  // the app; it fades in with the hero copy.
                  Opacity(
                    opacity: Curves.easeOut.transform(
                      ((reveal.value - .55) / .45).clamp(0.0, 1.0),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: _TrustLine(
                        text: context.uiCopy(
                          'Photo-checked members · Guardian-friendly · Private by design',
                        ),
                      ),
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

/// Three short trust phrases that wrap as whole units, never mid-phrase.
class _TrustLine extends StatelessWidget {
  const _TrustLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.caption.copyWith(
      color: AppColors.slateMist,
      fontSize: 12,
      height: 1.4,
    );
    final phrases = text.split(' · ');
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: [
        for (var i = 0; i < phrases.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (i == 0) ...[
                Icon(
                  Icons.verified_user_outlined,
                  size: 13,
                  color: AppColors.champagneGold,
                ),
                const SizedBox(width: 5),
              ],
              // A phrase breaks internally only when it cannot fit a line
              // on its own (very large text on a narrow phone).
              Flexible(
                child: UiText.verbatim(
                  phrases[i],
                  textAlign: TextAlign.center,
                  style: style,
                ),
              ),
              if (i < phrases.length - 1) UiText.verbatim(' · ', style: style),
            ],
          ),
      ],
    );
  }
}

/// Two fine threads resolve into one architectural arch. The motion is slow
/// enough to feel like living material rather than a looping illustration.
class _UnionArchPainter extends CustomPainter {
  const _UnionArchPainter({
    required this.reveal,
    required this.ambient,
    required this.accent,
    required this.highlight,
  });

  final double reveal;
  final double ambient;
  final Color accent;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final lineReveal = Curves.easeOutCubic.transform(
      ((reveal - .08) / .58).clamp(0.0, 1.0),
    );
    if (lineReveal <= .001) return;

    final left = Path()
      ..moveTo(-8, size.height * .78)
      ..cubicTo(
        size.width * .07,
        size.height * .28,
        size.width * .30,
        size.height * .08,
        size.width * .50,
        size.height * .10,
      );
    final right = Path()
      ..moveTo(size.width + 8, size.height * .78)
      ..cubicTo(
        size.width * .93,
        size.height * .28,
        size.width * .70,
        size.height * .08,
        size.width * .50,
        size.height * .10,
      );

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = .8
      ..color = accent.withValues(alpha: .10 * lineReveal);
    canvas
      ..drawPath(left, basePaint)
      ..drawPath(right, basePaint);

    final threadPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.35
      ..color = accent.withValues(alpha: .42);
    _drawProgress(canvas, left, lineReveal, threadPaint);
    _drawProgress(canvas, right, lineReveal, threadPaint);

    final phase = (ambient + .06 * math.sin(ambient * math.pi * 2)) % 1;
    final glintPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.65
      ..color = highlight.withValues(alpha: .34 * lineReveal);
    _drawMovingSegment(canvas, left, phase, glintPaint);
    _drawMovingSegment(canvas, right, (phase + .5) % 1, glintPaint);

    final apex = Offset(size.width * .5, size.height * .10);
    final apexOpacity = Curves.easeOut.transform(
      ((lineReveal - .72) / .28).clamp(0.0, 1.0),
    );
    canvas.save();
    canvas.translate(apex.dx, apex.dy);
    canvas.rotate(math.pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 7, height: 7),
        const Radius.circular(1.2),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: .62 * apexOpacity),
    );
    canvas.restore();

    _drawLeaf(
      canvas,
      Offset(size.width * .145, size.height * .49),
      -1.02,
      lineReveal,
    );
    _drawLeaf(
      canvas,
      Offset(size.width * .855, size.height * .49),
      math.pi + 1.02,
      lineReveal,
    );
  }

  void _drawProgress(
    Canvas canvas,
    Path path,
    double progress,
    Paint paint,
  ) {
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        paint,
      );
    }
  }

  void _drawMovingSegment(
    Canvas canvas,
    Path path,
    double phase,
    Paint paint,
  ) {
    for (final metric in path.computeMetrics()) {
      final start = metric.length * phase;
      final end = math.min(metric.length, start + metric.length * .13);
      canvas.drawPath(metric.extractPath(start, end), paint);
    }
  }

  void _drawLeaf(
    Canvas canvas,
    Offset center,
    double angle,
    double opacity,
  ) {
    canvas.save();
    canvas
      ..translate(center.dx, center.dy)
      ..rotate(angle);
    final leaf = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(8, -6, 15, 0)
      ..quadraticBezierTo(8, 6, 0, 0);
    canvas.drawPath(
      leaf,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = accent.withValues(alpha: .18 * opacity),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _UnionArchPainter oldDelegate) =>
      oldDelegate.reveal != reveal ||
      oldDelegate.ambient != ambient ||
      oldDelegate.accent != accent ||
      oldDelegate.highlight != highlight;
}

class _WelcomeCanvas extends StatelessWidget {
  const _WelcomeCanvas({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.obsidianNight,
              AppColors.midnightPlum.withValues(alpha: .40),
              AppColors.obsidianNight,
            ],
            stops: const [0, .34, 1],
          ),
        ),
        child: child,
      );
}
