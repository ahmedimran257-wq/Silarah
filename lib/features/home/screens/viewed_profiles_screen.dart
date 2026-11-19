// Viewed profiles: a private gallery of the profiles a member opened in
// Discover during the last 30 days, so a profile passed by in the carousel
// can be found again after a refresh, a restart or the next day.
//
//   • Grouped by Today / Yesterday / This week / Earlier
//   • Two-column portrait tiles with the card's photo, scrim and type
//   • Staggered entrance that respects reduce-motion
//   • Opening a tile goes through the same daily view check as Discover
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:silarah/l10n/ui_copy.dart';

import '../../../core/cubits/discovery/discovery_feed_cubit.dart';
import '../../../core/services/authorized_profile_service.dart';
import '../../../core/services/viewed_profiles_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_curves.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations/silarah_motion.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/loaders/silarah_blur_image.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/silarah_empty_state.dart';
import 'paywall_gate_screen.dart';
import 'profile_detail_screen.dart';

enum ViewedPeriod { today, yesterday, thisWeek, earlier }

/// Buckets a view time by the member's local calendar day.
ViewedPeriod viewedPeriodFor(DateTime viewedAt, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(viewedAt.year, viewedAt.month, viewedAt.day);
  final daysAgo = today.difference(day).inDays;
  if (daysAgo <= 0) return ViewedPeriod.today;
  if (daysAgo == 1) return ViewedPeriod.yesterday;
  if (daysAgo < 7) return ViewedPeriod.thisWeek;
  return ViewedPeriod.earlier;
}

String _periodLabel(BuildContext context, ViewedPeriod period) =>
    switch (period) {
      ViewedPeriod.today => context.uiCopy('Today'),
      ViewedPeriod.yesterday => context.uiCopy('Yesterday'),
      ViewedPeriod.thisWeek => context.uiCopy('Earlier this week'),
      ViewedPeriod.earlier => context.uiCopy('Earlier'),
    };

class ViewedProfilesScreen extends StatefulWidget {
  const ViewedProfilesScreen({super.key});

  static Future<void> open(BuildContext context) {
    HapticFeedback.selectionClick();
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ViewedProfilesScreen()),
    );
  }

  @override
  State<ViewedProfilesScreen> createState() => _ViewedProfilesScreenState();
}

class _ViewedProfilesScreenState extends State<ViewedProfilesScreen> {
  bool _loading = true;
  bool _failed = false;
  List<ViewedProfileEntry> _entries = const [];
  String? _openingId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    try {
      final entries = await ViewedProfilesService.instance.load();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _failed = false;
      });
    } catch (error) {
      debugPrint('[ViewedProfilesScreen] load failed: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = _entries.isEmpty;
      });
    }
  }

  Future<void> _open(ViewedProfileEntry entry) async {
    if (_openingId != null) return;
    HapticFeedback.selectionClick();
    setState(() => _openingId = entry.userId);
    try {
      // The same daily check as Discover: a profile already opened today is
      // free, anything else counts as one of today's views.
      final allowed = await context
          .read<DiscoveryFeedCubit>()
          .recordProfileView(entry.userId);
      if (!mounted) return;
      if (!allowed) {
        await PaywallGateSheet.show(context);
        return;
      }
      final profiles =
          await AuthorizedProfileService.loadDiscoveryProfiles([entry.userId]);
      if (!mounted) return;
      if (profiles.isEmpty) {
        _showUnavailable();
        unawaited(_load(quiet: true));
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ProfileDetailScreen(
            profile: profiles.first,
            heroTag: _heroTag(entry.userId),
          ),
        ),
      );
      if (mounted) unawaited(_load(quiet: true));
    } catch (error) {
      debugPrint('[ViewedProfilesScreen] open failed: $error');
      if (mounted) _showUnavailable();
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  void _showUnavailable() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.snackbarSurface,
          content: UiText(
            'This profile is not available right now.',
            style: AppTypography.body.copyWith(color: AppColors.onSnackbar),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: AppColors.obsidianNight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: context.uiCopy('Back'),
          child: GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              margin: const EdgeInsets.all(AppDimensions.space8),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.arrow_forward_rounded
                    : Icons.arrow_back_rounded,
                color: AppColors.pearlWhite,
                size: AppDimensions.iconSizeMedium,
              ),
            ),
          ),
        ),
        title: UiText(
          'Viewed profiles',
          style: AppTypography.screenTitle.copyWith(fontSize: 20),
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _entries.isEmpty) return const _GalleryShimmer();
    if (_failed) {
      return SilarahEmptyState(
        visual: SilarahEmptyVisual.connection,
        title: 'Could not load your viewed profiles',
        subtitle: 'Check your connection and try again.',
        ctaLabel: 'Try again',
        onCta: _load,
      );
    }
    if (_entries.isEmpty) {
      return SilarahEmptyState(
        visual: SilarahEmptyVisual.discovery,
        title: 'No viewed profiles yet',
        subtitle:
            'Profiles you open in Discover stay here for 30 days, so you can find them again.',
        ctaLabel: 'Back to Discover',
        onCta: () => Navigator.maybePop(context),
      );
    }

    final now = DateTime.now();
    final groups = <ViewedPeriod, List<ViewedProfileEntry>>{};
    for (final entry in _entries) {
      groups
          .putIfAbsent(viewedPeriodFor(entry.lastViewedAt, now), () => [])
          .add(entry);
    }

    final slivers = <Widget>[
      SliverToBoxAdapter(child: _GalleryIntro(count: _entries.length)),
    ];
    var tileIndex = 0;
    for (final period in ViewedPeriod.values) {
      final items = groups[period];
      if (items == null || items.isEmpty) continue;
      slivers
        ..add(SliverToBoxAdapter(
          child: _SectionHeader(
            label: _periodLabel(context, period),
            count: items.length,
          ),
        ))
        ..add(SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppDimensions.space20,
            0,
            AppDimensions.space20,
            AppDimensions.space8,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisSpacing: AppDimensions.space12,
              crossAxisSpacing: AppDimensions.space12,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final entry = items[index];
                final order = tileIndex + index;
                return SilarahEntrance(
                  delay: Duration(milliseconds: 40 * (order < 10 ? order : 10)),
                  duration: const Duration(milliseconds: 420),
                  offset: 14,
                  child: _ViewedTile(
                    entry: entry,
                    heroTag: _heroTag(entry.userId),
                    isOpening: _openingId == entry.userId,
                    onTap: () => _open(entry),
                  ),
                );
              },
              childCount: items.length,
            ),
          ),
        ));
      tileIndex += items.length;
    }
    slivers.add(const SliverToBoxAdapter(
      child: SizedBox(height: AppDimensions.space40),
    ));

    return RefreshIndicator(
      color: AppColors.champagneGold,
      backgroundColor: AppColors.surfaceElevated,
      onRefresh: () => _load(quiet: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      ),
    );
  }

  static String _heroTag(String userId) => 'viewed_profile_$userId';
}

class _GalleryIntro extends StatelessWidget {
  const _GalleryIntro({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.space20,
        AppDimensions.space4,
        AppDimensions.space20,
        AppDimensions.space8,
      ),
      child: SilarahEntrance(
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.space16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard - 6),
            border: Border.all(color: AppColors.goldBorder),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                AppColors.champagneGold.withValues(alpha: 0.12),
                AppColors.surfaceGlass,
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.champagneGold.withValues(alpha: 0.14),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: AppColors.champagneGold,
                  size: AppDimensions.iconSizeLarge,
                ),
              ),
              const SizedBox(width: AppDimensions.space14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UiText.verbatim(
                      context.uiCopyWith(
                        count == 1
                            ? '{count} profile in the last 30 days'
                            : '{count} profiles in the last 30 days',
                        {'count': count},
                      ),
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space4),
                    UiText(
                      'Only you can see this list.',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.space24,
        AppDimensions.space20,
        AppDimensions.space24,
        AppDimensions.space12,
      ),
      child: Row(
        children: [
          Transform.rotate(
            angle: 0.785398,
            child: Container(
              width: 7,
              height: 7,
              color: AppColors.champagneGold,
            ),
          ),
          const SizedBox(width: AppDimensions.space10),
          UiText.verbatim(
            label,
            style: AppTypography.sectionLabel.copyWith(
              color: AppColors.champagneGold,
            ),
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [AppColors.goldBorder, AppColors.transparent],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.space12),
          UiText.verbatim(
            '$count',
            style: AppTypography.caption.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewedTile extends StatelessWidget {
  const _ViewedTile({
    required this.entry,
    required this.heroTag,
    required this.isOpening,
    required this.onTap,
  });

  final ViewedProfileEntry entry;
  final String heroTag;
  final bool isOpening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photoUrl = entry.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final nameColor = hasPhoto ? AppColors.onMedia : AppColors.pearlWhite;
    final detailColor = hasPhoto
        ? AppColors.onMedia.withValues(alpha: 0.82)
        : AppColors.slateMist;
    final ageLabel = entry.age > 0 ? ', ${entry.age}' : '';

    return SilarahPressable(
      semanticLabel: '${entry.displayName}$ageLabel',
      pressedScale: 0.97,
      onTap: isOpening ? null : onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard - 4),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.obsidianDeep.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard - 4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: heroTag,
                child: hasPhoto
                    ? SilarahBlurImage(
                        imageUrl: photoUrl,
                        blurhash: entry.blurhash,
                        fit: BoxFit.cover,
                      )
                    : _MonogramPlaceholder(entry: entry),
              ),
              if (hasPhoto)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x14000000),
                        Color(0xA6000000),
                        Color(0xE6000000),
                      ],
                      stops: [0.0, 0.45, 0.78, 1.0],
                    ),
                  ),
                ),
              PositionedDirectional(
                top: AppDimensions.space10,
                end: AppDimensions.space10,
                child: _ViewedTimeChip(viewedAt: entry.lastViewedAt),
              ),
              PositionedDirectional(
                start: AppDimensions.space12,
                end: AppDimensions.space12,
                bottom: AppDimensions.space12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: UiText.verbatim(
                            '${entry.displayName}$ageLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.userName.copyWith(
                              fontSize: 17,
                              color: nameColor,
                              height: 1.15,
                            ),
                          ),
                        ),
                        if (entry.isVerified) ...[
                          const SizedBox(width: AppDimensions.space4),
                          Icon(
                            Icons.verified_rounded,
                            size: 15,
                            color: AppColors.verifiedTeal,
                            semanticLabel:
                                context.uiCopy('Profile photo verified'),
                          ),
                        ],
                      ],
                    ),
                    if (entry.cityName.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.space4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: detailColor,
                          ),
                          const SizedBox(width: AppDimensions.space2),
                          Flexible(
                            child: UiText.verbatim(
                              entry.cityName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: detailColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: AppDimensions.durationTransition,
                switchInCurve: AppCurves.reveal,
                switchOutCurve: AppCurves.dismiss,
                child: isOpening
                    ? const ColoredBox(
                        key: ValueKey('opening'),
                        color: AppColors.overlayBlack45,
                        child: Center(
                          child: SilarahActivityIndicator(
                            color: AppColors.onMedia,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('idle')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when there is no photo the member may see: private photos, a photo
/// that is still loading, or a profile without photos.
class _MonogramPlaceholder extends StatelessWidget {
  const _MonogramPlaceholder({required this.entry});

  final ViewedProfileEntry entry;

  @override
  Widget build(BuildContext context) {
    final initial = entry.firstName.trim().isEmpty
        ? '·'
        : entry.firstName.trim().characters.first.toUpperCase();
    // Only say "private" when the owner chose it; a public photo whose link
    // could not be fetched just shows the monogram.
    final isPrivate = entry.hasPhotos && entry.photoPrivacy != 'public';
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            AppColors.surfaceGlassHover,
            Color.lerp(
              AppColors.surfaceGlassHover,
              AppColors.champagneGold,
              0.10,
            )!,
          ],
        ),
      ),
      child: Align(
        alignment: const Alignment(0, -0.28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.champagneGold.withValues(alpha: 0.08),
                border: Border.all(color: AppColors.goldBorder, width: 1.5),
              ),
              child: UiText.verbatim(
                initial,
                style: AppTypography.screenTitle.copyWith(
                  fontSize: 30,
                  color: AppColors.champagneGold,
                  height: 1,
                ),
              ),
            ),
            if (isPrivate) ...[
              const SizedBox(height: AppDimensions.space10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 12,
                    color: AppColors.slateMist,
                  ),
                  const SizedBox(width: AppDimensions.space4),
                  UiText(
                    'Private photos',
                    style: AppTypography.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ViewedTimeChip extends StatelessWidget {
  const _ViewedTimeChip({required this.viewedAt});

  final DateTime viewedAt;

  @override
  Widget build(BuildContext context) {
    final difference = DateTime.now().difference(viewedAt);
    final label = difference.inMinutes < 60
        ? context.uiMinutesAgo(difference.inMinutes < 1 ? 1 : difference.inMinutes)
        : difference.inHours < 24
            ? context.uiHoursAgo(difference.inHours)
            : context.uiDaysAgo(difference.inDays);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.overlayBlack45,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip + 4),
        border: Border.all(color: AppColors.onMedia.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 11,
            color: AppColors.onMedia.withValues(alpha: 0.9),
          ),
          const SizedBox(width: AppDimensions.space4),
          UiText.verbatim(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.onMedia,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryShimmer extends StatelessWidget {
  const _GalleryShimmer();

  @override
  Widget build(BuildContext context) {
    return SilarahShimmer(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.space20,
          AppDimensions.space24,
          AppDimensions.space20,
          AppDimensions.space20,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          mainAxisSpacing: AppDimensions.space12,
          crossAxisSpacing: AppDimensions.space12,
          childAspectRatio: 0.72,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard - 4),
            border: Border.all(color: AppColors.cardBorder),
          ),
        ),
      ),
    );
  }
}
