// SILARAH — Profile quality card
// Top of the Profile tab: the member's photo inside a completeness ring, the
// one next step that raises it most, and what helps them rank in Discover.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:silarah/l10n/ui_copy.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_curves.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations/silarah_ornament.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The completeness items in the order the Profile tab suggests them, with
/// the points each adds. The points sum to 100.
enum ProfileQualityStep {
  photo(25, Icons.add_a_photo_outlined),
  bio(15, Icons.edit_note_rounded),
  deen(15, Icons.mosque_outlined),
  education(10, Icons.school_outlined),
  family(10, Icons.family_restroom_rounded),
  partnerPreferences(10, Icons.tune_rounded),
  secondPhoto(8, Icons.photo_library_outlined),
  income(4, Icons.account_balance_wallet_outlined),
  languages(3, Icons.translate_rounded);

  const ProfileQualityStep(this.points, this.icon);

  final int points;
  final IconData icon;

  /// Photo steps are fixed in Manage photos; the rest in Edit profile.
  bool get opensPhotos => this == photo || this == secondPhoto;

  String label(AppLocalizations l10n) => switch (this) {
        photo => l10n.profile_quality_step_photo,
        bio => l10n.profile_quality_step_bio,
        deen => l10n.profile_quality_step_deen,
        education => l10n.profile_quality_step_education,
        family => l10n.profile_quality_step_family,
        partnerPreferences => l10n.profile_quality_step_partner,
        secondPhoto => l10n.profile_quality_step_second_photo,
        income => l10n.profile_quality_step_income,
        languages => l10n.profile_quality_step_languages,
      };
}

/// What raises a profile's Discover quality score (migration 289). Matching
/// preferences still count most; these help among good matches.
class ProfileRankTips {
  const ProfileRankTips({
    required this.photoVerified,
    required this.approvedPhotoCount,
    required this.bioLength,
    required this.guardianLinked,
    required this.onVerify,
    required this.onPhotos,
    required this.onBio,
    required this.onGuardian,
  });

  static const maxRankedPhotos = 4;
  static const meaningfulBioLength = 150;

  final bool photoVerified;
  final int approvedPhotoCount;
  final int bioLength;
  final bool guardianLinked;
  final VoidCallback onVerify;
  final VoidCallback onPhotos;
  final VoidCallback onBio;
  final VoidCallback onGuardian;

  int get rankedPhotos => approvedPhotoCount.clamp(0, maxRankedPhotos);
  bool get photosDone => rankedPhotos >= maxRankedPhotos;
  bool get bioDone => bioLength >= meaningfulBioLength;

  int get doneCount => [photoVerified, photosDone, bioDone, guardianLinked]
      .where((done) => done)
      .length;
}

class ProfileQualityCard extends StatefulWidget {
  const ProfileQualityCard({
    super.key,
    required this.score,
    required this.nextStep,
    required this.onNextStep,
    required this.avatar,
    required this.name,
    required this.subtitle,
    this.nameBadge,
    this.identityStatus,
    this.tips,
  });

  /// Diameter the [avatar] is laid out at, inside the ring.
  static const avatarSize = 64.0;
  static const _ringSize = 84.0;

  final int score;

  /// Null once every completeness item is done.
  final ProfileQualityStep? nextStep;
  final ValueChanged<ProfileQualityStep> onNextStep;
  final Widget avatar;
  final String name;
  final String subtitle;
  final Widget? nameBadge;

  /// Photo verification seal or link; null while the status loads.
  final Widget? identityStatus;

  /// Discover ranking checklist; null while verification status loads.
  final ProfileRankTips? tips;

  @override
  State<ProfileQualityCard> createState() => _ProfileQualityCardState();
}

class _ProfileQualityCardState extends State<ProfileQualityCard>
    with TickerProviderStateMixin {
  late final AnimationController _ring;
  late final AnimationController _entrance;
  late final AnimationController _sweep;
  double _ringFrom = 0;
  bool _reduceMotion = false;

  double get _target => widget.score.clamp(0, 100) / 100.0;

  double get _ringValue =>
      _ringFrom +
      (_target - _ringFrom) * AppCurves.reveal.transform(_ring.value);

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduceMotion) {
      _ring.value = 1;
      _entrance.value = 1;
      _sweep.value = 1;
    } else if (_entrance.isDismissed) {
      _ring.forward();
      _entrance.forward();
      if (widget.nextStep == null) _sweep.forward();
    }
  }

  @override
  void didUpdateWidget(covariant ProfileQualityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score == widget.score) return;
    if (_reduceMotion) {
      _ringFrom = _target;
      return;
    }
    // Continue from what is on screen, never jump back to zero.
    final oldTarget = oldWidget.score.clamp(0, 100) / 100.0;
    _ringFrom = _ringFrom +
        (oldTarget - _ringFrom) * AppCurves.reveal.transform(_ring.value);
    _ring.forward(from: 0);
    if (widget.nextStep == null && oldWidget.nextStep != null) {
      _sweep.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    _entrance.dispose();
    _sweep.dispose();
    super.dispose();
  }

  Animation<double> _stagger(double start) => CurvedAnimation(
        parent: _entrance,
        curve:
            Interval(start, math.min(1, start + 0.55), curve: AppCurves.reveal),
      );

  Widget _reveal(double start, Widget child) {
    final animation = _stagger(start);
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(animation),
        child: child,
      ),
    );
  }

  String _tier(AppLocalizations l10n) {
    final score = widget.score;
    if (score >= 100) return l10n.profile_quality_tier_complete;
    if (score >= 80) return l10n.profile_quality_tier_strong;
    if (score >= 50) return l10n.profile_quality_tier_good;
    return l10n.profile_quality_tier_start;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tips = widget.tips;
    final step = widget.nextStep;
    final gold = AppColors.premiumGold;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.cardBorder),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceElevated,
            Color.lerp(AppColors.surfaceElevated, gold, 0.035)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.champagneGold.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Stack(
          children: [
            // Faint khatam watermark, half off the top-right corner.
            Positioned(
              top: -34,
              right: -34,
              child: IgnorePointer(
                child: CustomPaint(
                  size: const Size.square(132),
                  painter: _KhatamWatermarkPainter(
                    color: gold.withValues(alpha: 0.09),
                  ),
                ),
              ),
            ),
            // Hairline gold accent along the top edge.
            Positioned(
              top: 0,
              left: AppDimensions.space32,
              right: AppDimensions.space32,
              child: IgnorePointer(
                child: Container(
                  height: 1.2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      gold.withValues(alpha: 0),
                      gold.withValues(alpha: 0.7),
                      gold.withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.space20,
                AppDimensions.space20,
                AppDimensions.space20,
                AppDimensions.space16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, l10n),
                  const SizedBox(height: AppDimensions.space20),
                  _reveal(
                    0.25,
                    step == null
                        ? _CompleteTile(sweep: _sweep)
                        : _NextStepTile(
                            step: step,
                            reach: widget.score + step.points,
                            onTap: () => widget.onNextStep(step),
                          ),
                  ),
                  if (tips != null) ...[
                    const SizedBox(height: AppDimensions.space16),
                    _reveal(0.4, _RankChecklist(tips: tips)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final gold = AppColors.premiumGold;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _ring,
          builder: (context, _) {
            final value = _ringValue;
            return Semantics(
              label: l10n.profile_quality_ring_semantics(widget.score),
              child: SizedBox(
                width: ProfileQualityCard._ringSize,
                height: ProfileQualityCard._ringSize + AppDimensions.space8,
                child: Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: const Size.square(ProfileQualityCard._ringSize),
                      painter: QualityRingPainter(
                        progress: value,
                        track: AppColors.progressBarBase,
                        start: AppColors.champagneGold,
                        end: gold,
                      ),
                      child: SizedBox.square(
                        dimension: ProfileQualityCard._ringSize,
                        child: Center(
                          child: SizedBox.square(
                            dimension: ProfileQualityCard.avatarSize,
                            child: ClipOval(child: widget.avatar),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: ExcludeSemantics(
                        child: _PercentBadge(percent: (value * 100).round()),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(width: AppDimensions.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CustomPaint(
                    size: const Size.square(9),
                    painter: _KhatamGlyphPainter(color: gold),
                  ),
                  const SizedBox(width: AppDimensions.space6),
                  Flexible(
                    child: UiText.verbatim(
                      context.uiCopy('Profile quality'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.sectionLabel.copyWith(
                        color: gold,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Flexible(
                    child: UiText.verbatim(
                      '  ·  ${_tier(l10n)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.sectionLabel.copyWith(
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space6),
              Row(children: [
                Flexible(
                  child: UiText.verbatim(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.userName.copyWith(fontSize: 21),
                  ),
                ),
                if (widget.nameBadge != null) ...[
                  const SizedBox(width: AppDimensions.space8),
                  widget.nameBadge!,
                ],
              ]),
              const SizedBox(height: AppDimensions.space2),
              UiText.verbatim(
                widget.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption,
              ),
              if (widget.identityStatus != null) ...[
                const SizedBox(height: AppDimensions.space8),
                widget.identityStatus!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PercentBadge extends StatelessWidget {
  const _PercentBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical: AppDimensions.space2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.premiumGold.withValues(alpha: 0.55),
        ),
      ),
      child: UiText.verbatim(
        '$percent%',
        style: AppTypography.userName.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.champagneGold,
          height: 1.25,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _NextStepTile extends StatelessWidget {
  const _NextStepTile({
    required this.step,
    required this.reach,
    required this.onTap,
  });

  final ProfileQualityStep step;
  final int reach;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = AppColors.champagneGold;
    return SilarahPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.space12,
          AppDimensions.space10,
          AppDimensions.space10,
          AppDimensions.space10,
        ),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppDimensions.space14),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.12),
              ),
              child: Icon(step.icon, color: accent, size: 18),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText.verbatim(
                    l10n.profile_quality_next_eyebrow(reach.clamp(0, 100)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: AppColors.premiumGold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space2),
                  UiText.verbatim(
                    step.label(l10n),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.captionMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.space8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space8,
                vertical: AppDimensions.space4,
              ),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: UiText.verbatim(
                l10n.profile_quality_points(step.points),
                style: AppTypography.captionMedium.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.readableOn(accent),
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.space2),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.slateMist, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Shown at 100%: a quiet gold medallion and one slow light sweep.
class _CompleteTile extends StatelessWidget {
  const _CompleteTile({required this.sweep});

  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gold = AppColors.premiumGold;
    final radius = BorderRadius.circular(AppDimensions.space14);
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.space12),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.07),
              borderRadius: radius,
              border: Border.all(color: gold.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gold.withValues(alpha: 0.14),
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size.square(18),
                      painter: _KhatamGlyphPainter(color: gold),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UiText.verbatim(
                        l10n.profile_quality_complete_title,
                        style: AppTypography.captionMedium.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space2),
                      UiText.verbatim(
                        l10n.profile_quality_complete_body,
                        style: AppTypography.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: sweep,
                builder: (context, _) {
                  final t = sweep.value;
                  if (t <= 0 || t >= 1) return const SizedBox.shrink();
                  return CustomPaint(
                    painter: _SweepPainter(
                      t: AppCurves.breathe.transform(t),
                      color: gold.withValues(alpha: 0.18),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankChecklist extends StatelessWidget {
  const _RankChecklist({required this.tips});

  final ProfileRankTips tips;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: AppDimensions.space12),
          color: AppColors.divider,
        ),
        Row(
          children: [
            Expanded(
              child: UiText(
                'What helps you appear higher in Discover',
                style: AppTypography.captionMedium,
              ),
            ),
            const SizedBox(width: AppDimensions.space8),
            UiText.verbatim(
              '${tips.doneCount}/4',
              style: AppTypography.captionMedium.copyWith(
                color: AppColors.premiumGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space4),
        _RankTipRow(
          icon: Icons.verified_user_outlined,
          label: 'Verified profile photo',
          benefit: l10n.profile_quality_tip_verified_benefit,
          done: tips.photoVerified,
          onTap: tips.onVerify,
        ),
        _RankTipRow(
          icon: Icons.photo_library_outlined,
          label: 'Up to 4 approved photos',
          benefit: l10n.profile_quality_tip_photos_benefit,
          done: tips.photosDone,
          progress: '${tips.rankedPhotos}/${ProfileRankTips.maxRankedPhotos}',
          onTap: tips.onPhotos,
        ),
        _RankTipRow(
          icon: Icons.edit_note_rounded,
          label: 'A bio of a few lines',
          benefit: l10n.profile_quality_tip_bio_benefit,
          done: tips.bioDone,
          onTap: tips.onBio,
        ),
        _RankTipRow(
          icon: Icons.shield_outlined,
          label: 'Guardian linked',
          benefit: l10n.profile_quality_tip_guardian_benefit,
          done: tips.guardianLinked,
          onTap: tips.onGuardian,
        ),
        const SizedBox(height: AppDimensions.space6),
        UiText(
          'Matching preferences always count most. Staying active also helps.',
          style: AppTypography.caption.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

class _RankTipRow extends StatelessWidget {
  const _RankTipRow({
    required this.icon,
    required this.label,
    required this.benefit,
    required this.done,
    required this.onTap,
    this.progress,
  });

  final IconData icon;

  /// English source, localized through the Discover rank copy catalog.
  final String label;
  final String benefit;
  final bool done;
  final VoidCallback onTap;
  final String? progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final success = AppColors.verifiedTeal;
    return SilarahPressable(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.space6),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? success.withValues(alpha: 0.12)
                      : AppColors.surfaceGlassHover,
                  border: done
                      ? null
                      : Border.all(color: AppColors.cardBorder, width: 0.8),
                ),
                child: Icon(
                  done ? Icons.check_rounded : icon,
                  color: done ? success : AppColors.slateMist,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppDimensions.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UiText(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.captionMedium,
                    ),
                    UiText.verbatim(
                      benefit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.space8),
              if (done)
                UiText.verbatim(
                  l10n.profile_quality_done,
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: success,
                  ),
                )
              else ...[
                if (progress != null)
                  UiText.verbatim(
                    progress!,
                    style: AppTypography.captionMedium.copyWith(
                      fontSize: 12,
                      color: AppColors.premiumGold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.slateMist, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Completeness ring: a soft track and an arc that warms from the theme
/// accent into antique gold, starting at twelve o'clock.
class QualityRingPainter extends CustomPainter {
  const QualityRingPainter({
    required this.progress,
    required this.track,
    required this.start,
    required this.end,
  });

  final double progress;
  final Color track;
  final Color start;
  final Color end;

  static const strokeWidth = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - strokeWidth / 2 - 0.5;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = track,
    );
    final value = progress.clamp(0.0, 1.0);
    if (value <= 0) return;
    final sweep = 2 * math.pi * value;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [start, end],
          stops: [0, math.max(value, 0.001)],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
    // The round cap before twelve o'clock samples the gradient's far end;
    // repaint it in the start colour so the arc begins cleanly.
    canvas.drawCircle(
      center + Offset(0, -radius),
      strokeWidth / 2,
      Paint()..color = start,
    );
  }

  @override
  bool shouldRepaint(QualityRingPainter old) =>
      old.progress != progress ||
      old.track != track ||
      old.start != start ||
      old.end != end;
}

class _KhatamGlyphPainter extends CustomPainter {
  const _KhatamGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      SilarahOrnament.khatam(
        size.center(Offset.zero),
        size.shortestSide / 2,
        rotation: math.pi / 8,
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_KhatamGlyphPainter old) => old.color != color;
}

class _KhatamWatermarkPainter extends CustomPainter {
  const _KhatamWatermarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    canvas
      ..drawPath(SilarahOrnament.khatam(center, radius), stroke)
      ..drawPath(
        SilarahOrnament.khatam(center, radius * 0.62, rotation: math.pi / 8),
        stroke,
      )
      ..drawCircle(center, radius * 0.3, stroke);
  }

  @override
  bool shouldRepaint(_KhatamWatermarkPainter old) => old.color != color;
}

class _SweepPainter extends CustomPainter {
  const _SweepPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final band = size.width * 0.35;
    final left = -band + (size.width + band * 2) * t - band;
    final rect = Rect.fromLTWH(left, 0, band * 2, size.height);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color,
            color.withValues(alpha: 0)
          ],
          transform: const GradientRotation(0.35),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.t != t || old.color != color;
}
