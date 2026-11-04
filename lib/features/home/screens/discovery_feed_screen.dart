//
//   • Horizontal paged carousel — one card at a time
//   • viewportFraction 0.88 → adjacent cards peek at 0.95 scale
//   • Cursor-based pagination via DiscoveryFeedCubit
//   • Skeleton loaders on initial load AND page-load-more
//   • Filter bar (horizontal scrollable chips)
//   • Every 10th card: "Someone you might connect with" label
//   • Free-tier counter: "12 profiles remaining today"
//   • Dot indicator (max 7, sliding window)
//   • Interest ceremony → cubit + overlay
//   • Bookmark toggle with persistence via BookmarkService
import 'package:silarah/l10n/ui_copy.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/cubits/block_report/block_report_cubit.dart';
import '../../../core/cubits/discovery/discovery_feed_cubit.dart';
import '../../../core/cubits/discovery/discovery_feed_state.dart';
import '../../../core/cubits/interests/interests_cubit.dart';
import '../../../core/cubits/interests/interests_state.dart';
import '../../../core/cubits/subscription/subscription_cubit.dart';
import '../../../core/services/bookmark_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cards/silarah_profile_card.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/silarah_empty_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/discovery_empty_state.dart';
import '../widgets/discovery_filter_bar.dart';
import '../widgets/discovery_filter_sheet.dart';
import '../widgets/interest_note_sheet.dart';
import '../widgets/notification_bell_button.dart';
import 'paywall_gate_screen.dart';
import 'profile_detail_screen.dart';
import 'notifications_screen.dart';

class DiscoveryFeedScreen extends StatefulWidget {
  const DiscoveryFeedScreen({super.key, this.onOpenTab});

  final ValueChanged<int>? onOpenTab;

  @override
  State<DiscoveryFeedScreen> createState() => _DiscoveryFeedScreenState();
}

class _DiscoveryFeedScreenState extends State<DiscoveryFeedScreen>
    with AutomaticKeepAliveClientMixin {
  late final PageController _pageCtrl;
  int _currentPage = 0;
  final Set<String> _recordedViewIds = {};
  // Bookmarks now use profile IDs (String) for persistence
  Set<String> _bookmarked = {};
  final Set<String> _bookmarkWritesInFlight = <String>{};
  final Set<String> _interestWritesInFlight = <String>{};
  Timer? _rematchCountdownTimer;
  DateTime? _nextRematchCountdownTick;
  DiscoveryFilter? _lastObservedFilter;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.88);

    // Trigger initial load after first frame so cubit is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscoveryFeedCubit>().loadInitial();
      _loadBookmarks();
      _scheduleRematchCountdown(
        context.read<DiscoveryFeedCubit>().state.profiles,
      );
    });
  }

  @override
  void dispose() {
    _rematchCountdownTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _scheduleRematchCountdown(List<FeedProfile> profiles) {
    final now = DateTime.now();
    DateTime? nextTick;
    for (final entry in profiles) {
      final availableAt = entry.profile.rematchAvailableAt;
      if (availableAt == null || !availableAt.isAfter(now)) continue;
      final remaining = availableAt.difference(now);
      final days =
          (remaining.inMilliseconds / const Duration(days: 1).inMilliseconds)
              .ceil();
      final candidate = days <= 1
          ? availableAt
          : availableAt.subtract(Duration(days: days - 1));
      if (nextTick == null || candidate.isBefore(nextTick)) {
        nextTick = candidate;
      }
    }
    if (_nextRematchCountdownTick == nextTick) return;
    _rematchCountdownTimer?.cancel();
    _nextRematchCountdownTick = nextTick;
    if (nextTick == null) return;
    final delay = nextTick.difference(now) + const Duration(milliseconds: 150);
    _rematchCountdownTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _nextRematchCountdownTick = null;
      _scheduleRematchCountdown(
        context.read<DiscoveryFeedCubit>().state.profiles,
      );
    });
  }

  Future<void> _loadBookmarks() async {
    try {
      final ids = await BookmarkService.load();
      if (mounted) setState(() => _bookmarked = ids);
    } catch (_) {
      if (mounted) setState(() => _bookmarked = {});
    }
  }

  void _onPageChanged(int page) {
    _currentPage = page;
    // Trigger pagination when 2 cards from the end
    final feedState = context.read<DiscoveryFeedCubit>().state;
    final hidden = context.read<BlockReportCubit>().state.hiddenProfileIds;
    final profiles = feedState.profiles
        .where((entry) => !hidden.contains(entry.profile.id))
        .toList(growable: false);
    if (page >= 0 && page < profiles.length) {
      _recordVisibleProfileView(profiles[page].profile.id);
    }
    final total = profiles.length;
    if (page >= total - 2 && feedState.status == FeedStatus.loaded) {
      context.read<DiscoveryFeedCubit>().loadMore();
    }
  }

  Future<void> _handleSendInterest(int index, FeedProfile fp) async {
    final profileId = fp.profile.id;
    if (_interestWritesInFlight.contains(profileId)) return;
    if (!await context.read<InterestsCubit>().canStartInterest() || !mounted) {
      return;
    }
    // G2: Show note sheet before sending (consistent with profile detail)
    final note = await showInterestNoteSheet(
      context,
      firstName: fp.profile.firstName,
    );
    if (note == null || !mounted) return; // cancelled

    setState(() => _interestWritesInFlight.add(profileId));
    bool sent;
    try {
      sent = await context.read<InterestsCubit>().sendInterest(
            fp.profile,
            note: note.isNotEmpty ? note : null,
          );
    } finally {
      if (mounted) {
        setState(() => _interestWritesInFlight.remove(profileId));
      }
    }
    if (!mounted || !sent) return;
    HapticFeedback.mediumImpact();
  }

  Future<void> _handleBookmark(int index, FeedProfile fp) async {
    final id = fp.profile.id;
    if (_bookmarkWritesInFlight.contains(id)) return;
    _bookmarkWritesInFlight.add(id);
    HapticFeedback.selectionClick();
    final previous = Set<String>.from(_bookmarked);
    setState(() {
      if (_bookmarked.contains(id)) {
        _bookmarked.remove(id);
      } else {
        _bookmarked.add(id);
      }
    });

    final targetSaved = _bookmarked.contains(id);
    try {
      final saved = await BookmarkService.setSaved(id, targetSaved);
      if (mounted) setState(() => _bookmarked = saved);
    } catch (_) {
      if (mounted) setState(() => _bookmarked = previous);
      _bookmarkWritesInFlight.remove(id);
      return;
    }

    _bookmarkWritesInFlight.remove(id);

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: UiText(
            _bookmarked.contains(id)
                ? l10n.discovery_bookmark_saved(fp.profile.firstName)
                : l10n.discovery_bookmark_removed(fp.profile.firstName),
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
          duration: const Duration(seconds: 1),
        ),
      );
  }

  Future<void> _openProfile(FeedProfile fp) async {
    final allowed = await _recordVisibleProfileView(fp.profile.id);
    if (!mounted) return;
    if (!allowed) {
      PaywallGateSheet.show(context);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileDetailScreen(
          profile: fp.profile,
          heroTag: 'profile_photo_${fp.profile.id}',
        ),
      ),
    );
  }

  Future<bool> _recordVisibleProfileView(String profileUserId) async {
    if (_recordedViewIds.contains(profileUserId)) return true;
    final allowed = await context
        .read<DiscoveryFeedCubit>()
        .recordProfileView(profileUserId);
    if (allowed && mounted) {
      _recordedViewIds.add(profileUserId);
    }
    return allowed;
  }

  // Build
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final interests = context.watch<InterestsCubit>().state;
    final gender = context.select<AuthCubit, String>((cubit) {
      final auth = cubit.state;
      return auth is AuthAuthenticated ? (auth.gender ?? '') : '';
    });
    final canMessage = context.select<SubscriptionCubit, bool>(
      (cubit) => cubit.state.canMessage(gender),
    );
    final hiddenProfileIds = context.select<BlockReportCubit, Set<String>>(
      (cubit) => cubit.state.hiddenProfileIds,
    );
    return BlocConsumer<DiscoveryFeedCubit, DiscoveryFeedState>(
      listenWhen: (previous, current) =>
          previous.activeFilter != current.activeFilter ||
          previous.profiles != current.profiles,
      listener: (context, state) {
        if (_lastObservedFilter != state.activeFilter) {
          _lastObservedFilter = state.activeFilter;
          _currentPage = 0;
        }
        _scheduleRematchCountdown(state.profiles);
        if (_currentPage >= state.profiles.length &&
            state.profiles.isNotEmpty) {
          _currentPage = state.profiles.length - 1;
        }
        if (_pageCtrl.positions.length == 1 &&
            _currentPage < state.profiles.length) {
          _pageCtrl.jumpToPage(_currentPage);
        }
      },
      builder: (context, feedState) {
        return RefreshIndicator(
          color: AppColors.champagneGold,
          backgroundColor: AppColors.obsidianNight,
          onRefresh: () async {
            _recordedViewIds.clear();
            await context.read<DiscoveryFeedCubit>().loadInitial(force: true);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.space24,
                    AppDimensions.space16,
                    AppDimensions.space24,
                    AppDimensions.space12,
                  ),
                  child: Row(
                    children: [
                      UiText('سيلارا',
                          style: AppTypography.wordmark.copyWith(fontSize: 26)),
                      const SizedBox(width: AppDimensions.space8),
                      UiText('SILARAH', style: AppTypography.wordmark),
                      const Spacer(),
                      // Free-tier counter badge
                      if ((feedState.status == FeedStatus.loaded ||
                              feedState.status == FeedStatus.refreshing ||
                              feedState.status == FeedStatus.loadingMore) &&
                          feedState.dailyLimit < 1000000)
                        _FreeTierCounter(remaining: feedState.remainingToday),
                      const SizedBox(width: AppDimensions.space12),
                      _NotificationButton(),
                    ],
                  ),
                ),
              ),

              // Filter bar
              const SliverToBoxAdapter(child: DiscoveryFilterBar()),
              const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.space16)),

              // Card carousel
              SliverFillRemaining(
                hasScrollBody: true,
                child: _buildCarousel(
                  feedState,
                  interests,
                  canMessage,
                  hiddenProfileIds,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCarousel(
    DiscoveryFeedState feedState,
    InterestsState interests,
    bool canMessage,
    Set<String> hiddenProfileIds,
  ) {
    // Full-screen skeleton on initial load
    if (feedState.status == FeedStatus.initial ||
        feedState.status == FeedStatus.loading) {
      return _InitialShimmer();
    }

    final isLimited =
        feedState.isFreeTierLimitReached && feedState.dailyLimit < 1000000;

    if (isLimited) {
      return _FreeTierLimitReached(
        onUpgrade: () => PaywallGateSheet.show(context),
      );
    }

    if (feedState.status == FeedStatus.empty) {
      return _EmptyFeed(filter: feedState.activeFilter);
    }

    if (feedState.status == FeedStatus.error) {
      return _DiscoveryError(
        kind: feedState.failureKind ?? DiscoveryFailureKind.unavailable,
        message: feedState.errorMessage ??
            'Profiles are temporarily unavailable. Please try again.',
        onRetry: () =>
            context.read<DiscoveryFeedCubit>().loadInitial(force: true),
      );
    }

    final profiles = feedState.profiles
        .where((entry) => !hiddenProfileIds.contains(entry.profile.id))
        .toList(growable: false);
    if (profiles.isEmpty) {
      return _EmptyFeed(filter: feedState.activeFilter);
    }
    final isLoadingMore = feedState.status == FeedStatus.loadingMore;

    final itemCount = profiles.length + (isLoadingMore ? 1 : 0);

    final carousel = PageView.builder(
      controller: _pageCtrl,
      itemCount: itemCount,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        // Skeleton card at the end while loading more
        if (index >= profiles.length) {
          return _scaledCard(
            index,
            _cardPadding(child: const SilarahProfileCardShimmer()),
          );
        }

        final fp = profiles[index];
        final p = fp.profile;
        final action = _profileAction(index, fp, interests, canMessage);

        return _scaledCard(
          index,
          _cardPadding(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Only the photo participates in the shared-element flight.
                // Transforming the entire text-rich card on reverse navigation
                // can leave baseline/ghost artifacts on some Android GPUs.
                SilarahProfileCard(
                  displayName: p.displayName,
                  age: p.age,
                  cityName: p.cityName,
                  sect: p.sect,
                  deenLevel: p.deenLevel,
                  profession: p.occupation,
                  photoUrl: p.photoUrl,
                  blurhash: p.blurhash,
                  photoCount: p.photoCount,
                  isPhotoPrivate: p.isPhotoPrivate,
                  isVerified: p.isVerified,
                  isGuardianManaged: p.isGuardianProfile,
                  lastActiveLabel:
                      _localizedLastActive(context, fp.lastActiveAt),
                  isFocused: true, // Scale handled externally now
                  cardScale: 1,
                  isBookmarked: _bookmarked.contains(p.id),
                  interestActionLabel: action.label,
                  isInterestActionEnabled: action.onTap != null,
                  // A past match is history only while there is no
                  // current one; "Previously matched" beside Open Chat is
                  // contradictory.
                  previousMatchLabel: p.previousMatchAt == null ||
                          interests.interactionWith(p.id) ==
                              ProfileInteractionState.matched ||
                          p.relationshipState == 'matched'
                      ? null
                      : AppLocalizations.of(context).discovery_previous_match(
                          MaterialLocalizations.of(context).formatMediumDate(
                            p.previousMatchAt!.toLocal(),
                          ),
                        ),
                  photoHeroTag: 'profile_photo_${p.id}',
                  onTap: () => _openProfile(fp),
                  onSendInterest: action.onTap,
                  onBookmark: () => _handleBookmark(index, fp),
                ),

                // Wild-card label — "Someone you might connect with"
                if (fp.isWildCard)
                  Positioned(
                    top: -12,
                    left: AppDimensions.space12,
                    right: AppDimensions.space12,
                    child: Center(
                      child: _WildCardLabel(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    return Stack(
      children: [
        carousel,
        if (feedState.status == FeedStatus.refreshing)
          Positioned(
            top: 0,
            left: AppDimensions.space40,
            right: AppDimensions.space40,
            child: SilarahLinearProgress(
              height: 1.5,
              color: AppColors.champagneGold,
              trackColor: AppColors.transparent,
            ),
          ),
        if (feedState.failureKind != null)
          Positioned(
            top: AppDimensions.space8,
            left: AppDimensions.space24,
            right: AppDimensions.space24,
            child: _DiscoveryConnectionNotice(
              kind: feedState.failureKind!,
              message: feedState.errorMessage ?? '',
              onRetry: () =>
                  context.read<DiscoveryFeedCubit>().loadInitial(force: true),
            ),
          ),
      ],
    );
  }

  String _localizedLastActive(BuildContext context, DateTime? lastActiveAt) {
    if (lastActiveAt == null) return '';
    final difference = DateTime.now().difference(lastActiveAt);
    if (difference.inMinutes < 5) return context.uiCopy('Online now');
    if (difference.inMinutes < 60) {
      return context.uiMinutesAgo(difference.inMinutes);
    }
    if (difference.inHours < 24) return context.uiHoursAgo(difference.inHours);
    return context.uiDaysAgo(difference.inDays);
  }

  _DiscoveryProfileAction _profileAction(
    int index,
    FeedProfile profile,
    InterestsState interests,
    bool canMessage,
  ) {
    final l10n = AppLocalizations.of(context);
    if (_interestWritesInFlight.contains(profile.profile.id)) {
      return const _DiscoveryProfileAction(label: 'Sending...');
    }
    var interaction = interests.interactionWith(profile.profile.id);
    final hasLocalRelationshipRecord = interests.matches.any(
          (entry) => entry.profile.id == profile.profile.id,
        ) ||
        interests.received.any(
          (entry) => entry.profile.id == profile.profile.id,
        ) ||
        interests.sent.any(
          (entry) => entry.profile.id == profile.profile.id,
        );
    if (interaction == ProfileInteractionState.none &&
        !hasLocalRelationshipRecord) {
      interaction = switch (profile.profile.relationshipState) {
        'pending_sent' => ProfileInteractionState.pendingSent,
        'pending_received' => ProfileInteractionState.pendingReceived,
        'matched' => ProfileInteractionState.matched,
        _ => ProfileInteractionState.none,
      };
    }
    switch (interaction) {
      case ProfileInteractionState.pendingSent:
        return const _DiscoveryProfileAction(label: 'Interest Sent');
      case ProfileInteractionState.pendingReceived:
        return _DiscoveryProfileAction(
          label: 'Review Interest',
          onTap:
              widget.onOpenTab == null ? null : () => widget.onOpenTab?.call(1),
        );
      case ProfileInteractionState.matched:
        return _DiscoveryProfileAction(
          label: canMessage ? 'Open Chat' : 'Unlock Chat',
          onTap: canMessage
              ? (widget.onOpenTab == null
                  ? null
                  : () => widget.onOpenTab?.call(2))
              : () => PaywallGateSheet.show(context),
        );
      case ProfileInteractionState.none:
        final cooldownDays = profile.profile.rematchCooldownDaysRemaining;
        if (cooldownDays != null) {
          return _DiscoveryProfileAction(
            label: l10n.discovery_rematch_days(cooldownDays),
          );
        }
        return _DiscoveryProfileAction(
          label: profile.profile.isRematchCandidate
              ? 'Send Interest Again'
              : 'Send Interest',
          onTap: () => _handleSendInterest(index, profile),
        );
    }
  }

  Widget _scaledCard(int index, Widget child) {
    return AnimatedBuilder(
      animation: _pageCtrl,
      child: RepaintBoundary(child: child),
      builder: (context, child) {
        final page = _pageCtrl.positions.length == 1
            ? (_pageCtrl.page ?? _currentPage.toDouble())
            : _currentPage.toDouble();
        final offset = (index - page).abs();
        final scale = (1.0 - (offset * 0.05)).clamp(0.95, 1.0);
        return Transform.scale(scale: scale, child: child);
      },
    );
  }

  Widget _cardPadding({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space6,
        vertical: AppDimensions.space4,
      ),
      child: child,
    );
  }
}

class _DiscoveryProfileAction {
  const _DiscoveryProfileAction({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;
}

class _DiscoveryError extends StatelessWidget {
  const _DiscoveryError({
    required this.kind,
    required this.message,
    required this.onRetry,
  });

  final DiscoveryFailureKind kind;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final title = switch (kind) {
      DiscoveryFailureKind.offline => "You're offline",
      DiscoveryFailureKind.unavailable => 'Profiles unavailable',
      DiscoveryFailureKind.profileNotReady => 'Profile not live yet',
      DiscoveryFailureKind.authenticationRequired => 'Sign in required',
    };
    return SilarahEmptyState(
      visual: SilarahEmptyVisual.connection,
      title: title,
      subtitle: message,
      ctaLabel: kind == DiscoveryFailureKind.offline
          ? 'Check connection'
          : 'Try again',
      onCta: onRetry,
    );
  }
}

class _DiscoveryConnectionNotice extends StatelessWidget {
  const _DiscoveryConnectionNotice({
    required this.kind,
    required this.message,
    required this.onRetry,
  });

  final DiscoveryFailureKind kind;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final offline = kind == DiscoveryFailureKind.offline;
    return Semantics(
      liveRegion: true,
      button: true,
      label: context.uiCopy(message),
      child: SilarahPressable(
        onTap: onRetry,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated.withValues(alpha: .96),
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            border: Border.all(
              color: offline ? AppColors.softCoral : AppColors.goldBorder,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space12,
              vertical: AppDimensions.space8,
            ),
            child: Row(
              children: [
                Icon(
                  offline
                      ? Icons.cloud_off_rounded
                      : Icons.sync_problem_rounded,
                  size: AppDimensions.iconSizeSmall,
                  color:
                      offline ? AppColors.softCoral : AppColors.champagneGold,
                ),
                const SizedBox(width: AppDimensions.space8),
                Expanded(
                  child: UiText(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
                ),
                Icon(
                  Icons.refresh_rounded,
                  size: AppDimensions.iconSizeSmall,
                  color: AppColors.slateMist,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Wild-card Label
class _WildCardLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.champagneGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border:
            Border.all(color: AppColors.champagneGold.withValues(alpha: 0.5)),
      ),
      child: UiText(
        l10n.discovery_wildcard_label,
        style: AppTypography.caption.copyWith(
          color: AppColors.champagneGold,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// Free-Tier Counter Badge
class _FreeTierCounter extends StatelessWidget {
  const _FreeTierCounter({required this.remaining});
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedContainer(
      duration: AppDimensions.durationTransition,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space10,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: remaining <= 3
            ? AppColors.errorRed.withValues(alpha: 0.15)
            : AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(
          color: remaining <= 3 ? AppColors.errorRed : AppColors.cardBorder,
        ),
      ),
      child: UiText(
        l10n.discovery_remaining_profiles(remaining.toString()),
        style: AppTypography.caption.copyWith(
          color: remaining <= 3 ? AppColors.errorRed : AppColors.slateMist,
          fontSize: 11,
        ),
      ),
    );
  }
}

// Notification Button
class _NotificationButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NotificationBellButton(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const NotificationsScreen(),
          ),
        );
      },
    );
  }
}

// Initial Shimmer (3-card stack)
class _InitialShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.space6,
        vertical: AppDimensions.space4,
      ),
      child: SilarahProfileCardShimmer(),
    );
  }
}

// Empty Feed State
class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.filter});

  final DiscoveryFilter filter;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DiscoveryFeedCubit>();
    return DiscoveryEmptyState(
      filter: filter,
      onRefresh: () => cubit.loadInitial(force: true),
      onClearFilters: cubit.clearFilters,
      onAdjustFilters: (section) => showDiscoveryFilterSheet(
        context,
        initial: filter,
        scrollToSection: section,
      ),
    );
  }
}

// M9: Free-Tier Browse Limit
class _FreeTierLimitReached extends StatelessWidget {
  const _FreeTierLimitReached({required this.onUpgrade});
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.champagneGold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldBorder),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldGlow,
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                Icons.lock_clock_rounded,
                color: AppColors.champagneGold,
                size: 44,
              ),
            ),
            const SizedBox(height: AppDimensions.space28),
            UiText(
              l10n.discovery_limit_title,
              style: AppTypography.screenTitle.copyWith(fontSize: 22),
            ),
            const SizedBox(height: AppDimensions.space12),
            UiText(
              l10n.discovery_limit_subtitle,
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space24),
            GestureDetector(
              onTap: onUpgrade,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space24,
                  vertical: AppDimensions.space14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.champagneGold,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                ),
                child: UiText(l10n.discovery_limit_button,
                    style: AppTypography.button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
