// SILARAH — Interests Inbox (Items 17, 18, 19, 21, 22, 26)
//
// Items implemented here:
//   17 — Daily limit counter banner in Sent tab header (male only)
//   18 — Expiry countdown on pending received cards
//   19 — Withdraw confirm dialog on Sent tab
//   21 — Match modal: remove 48h note, show "Bismillah" CTA
//   22 — All cooling period text removed
//   26 — SilarahEmptyState on both tabs
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/cubits/interests/interests_cubit.dart';
import '../../../core/cubits/interests/interests_state.dart';
import '../../../core/cubits/chat/chat_cubit.dart';
import '../../../core/models/discovery_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/silarah_empty_state.dart';
import '../../../core/widgets/loaders/silarah_blur_image.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/overlays/silarah_dialog.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'chat_screen.dart';
import 'paywall_gate_screen.dart';

Future<void> _openChatForProfile(
  BuildContext context,
  DiscoveryProfile profile,
) async {
  final chatCubit = context.read<ChatCubit>();
  final navigator = Navigator.of(context);
  final convId = await chatCubit.openOrCreateConversation(
    profile.id,
    profile.firstName,
    profile.lastNameInitial,
  );
  if (!context.mounted) return;
  if (convId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: UiText(context
          .uiCopy('Your conversation is still being prepared. Try again.')),
      behavior: SnackBarBehavior.floating,
    ));
    return;
  }

  final access = await chatCubit.checkChatAccess(convId);
  if (!context.mounted) return;
  if (access.requiresSubscription) {
    await PaywallGateSheet.show(context);
    return;
  }
  if (!access.allowed) {
    final message = switch (access.reason) {
      ChatAccessReason.suspended =>
        'Messaging is temporarily restricted on this account.',
      ChatAccessReason.closed => 'This conversation has ended.',
      _ => 'We could not open this conversation. Please try again.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: UiText(message),
      behavior: SnackBarBehavior.floating,
    ));
    return;
  }

  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => ChatScreen(conversationId: convId),
    ),
  );
}

class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key});

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final TabController _tabCtrl;
  final Set<String> _acceptingInterestIds = <String>{};
  final Set<String> _processingInterestIds = <String>{};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showMutualMatchModal(DiscoveryProfile profile) {
    HapticFeedback.mediumImpact();
    showSilarahDialog<void>(
      context: context,
      barrierColor: AppColors.obsidianNight.withValues(alpha: 0.85),
      builder: (context) => Center(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.space32),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                border: Border.all(color: AppColors.goldBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldGlow,
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Overlapping avatars + heart centre badge
                  _MatchAvatarPair(),
                  const SizedBox(height: AppDimensions.space24),

                  // Gold title
                  UiText(
                    context.uiCopy('Mabrook!'),
                    style: AppTypography.screenTitle
                        .copyWith(color: AppColors.champagneGold, fontSize: 28),
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  UiText(
                    context.uiCopy('You have a mutual interest.'),
                    style: AppTypography.screenTitle
                        .copyWith(color: AppColors.pearlWhite, fontSize: 18),
                  ),
                  const SizedBox(height: AppDimensions.space12),

                  UiText(
                    context.uiCopy('Say bismillah and begin a conversation.'),
                    style: AppTypography.bodyMuted.copyWith(height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.space28),

                  // Message Now CTA — gold, full width
                  SizedBox(
                    width: double.infinity,
                    height: AppDimensions.buttonHeight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.champagneGold,
                        foregroundColor: AppColors.obsidianNight,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusButton),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).pop();
                        await _openChatForProfile(this.context, profile);
                      },
                      child: UiText(context.uiCopy('Message Now'),
                          style: AppTypography.button),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space12),

                  // Maybe later
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: UiText(
                      context.uiCopy('Maybe later'),
                      style: AppTypography.caption
                          .copyWith(color: AppColors.slateMist),
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

  Future<void> _acceptInterest(InterestEntry entry) async {
    if (_acceptingInterestIds.contains(entry.id)) return;
    setState(() => _acceptingInterestIds.add(entry.id));
    final accepted =
        await context.read<InterestsCubit>().acceptInterest(entry.id);
    if (!mounted) return;
    setState(() => _acceptingInterestIds.remove(entry.id));
    if (!accepted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: UiText(context
              .uiCopy('The interest could not be accepted. Please retry.')),
        ));
      return;
    }
    _showMutualMatchModal(entry.profile);
  }

  Future<void> _declineInterest(InterestEntry entry) async {
    if (_processingInterestIds.contains(entry.id)) return;
    setState(() => _processingInterestIds.add(entry.id));
    final declined =
        await context.read<InterestsCubit>().declineInterest(entry.id);
    if (!mounted) return;
    setState(() => _processingInterestIds.remove(entry.id));
    if (!declined) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: UiText(context.uiCopy(
          'The interest could not be declined. Please retry.',
        )),
      ));
    }
  }

  void _showWithdrawDialog(InterestEntry entry) {
    if (_processingInterestIds.contains(entry.id)) return;
    HapticFeedback.selectionClick();
    showSilarahDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        title: UiText(context.uiCopy('Withdraw interest?'),
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.pearlWhite, fontSize: 17)),
        content: UiText(
          context.uiCopy("They won't be notified."),
          style: AppTypography.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: UiText(context.uiCopy('Cancel'),
                style:
                    AppTypography.caption.copyWith(color: AppColors.slateMist)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _processingInterestIds.add(entry.id));
              final withdrawn = await context
                  .read<InterestsCubit>()
                  .withdrawInterest(entry.id);
              if (!mounted) return;
              setState(() => _processingInterestIds.remove(entry.id));
              if (!withdrawn) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: UiText(context.uiCopy(
                    'The interest could not be withdrawn. Please retry.',
                  )),
                ));
              }
            },
            child: UiText(context.uiCopy('Withdraw'),
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.softCoral, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // Build
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<InterestsCubit, InterestsState>(
      builder: (context, state) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.space24,
                AppDimensions.space16,
                AppDimensions.space24,
                0,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: UiText(AppLocalizations.of(context).interests_title,
                    style: AppTypography.screenTitle),
              ),
            ),
            const SizedBox(height: AppDimensions.space16),

            // Tab bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
              // An inset track with a raised thumb that slides between tabs.
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.champagneGold.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  labelStyle: AppTypography.bodyMedium
                      .copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                  unselectedLabelStyle:
                      AppTypography.bodyMuted.copyWith(fontSize: 14),
                  labelColor: AppColors.champagneGold,
                  unselectedLabelColor: AppColors.slateMist,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  splashBorderRadius: BorderRadius.circular(999),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          UiText(AppLocalizations.of(context)
                              .interests_tab_received),
                          if (state.pendingReceived.isNotEmpty) ...[
                            const SizedBox(width: AppDimensions.space6),
                            _CountBadge(count: state.pendingReceived.length),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          UiText(
                              AppLocalizations.of(context).interests_tab_sent),
                          if (state.sent.any((e) =>
                              e.effectiveStatus ==
                              InterestStatus.accepted)) ...[
                            const SizedBox(width: AppDimensions.space6),
                            const _NewBadge(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space16),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // Received tab
                  state.displayReceived.isEmpty
                      ? const SilarahEmptyState(
                          visual: SilarahEmptyVisual.interests,
                          title: 'No interests yet',
                          subtitle:
                              'When someone sends you an interest it appears here.',
                        )
                      : _ReceivedList(
                          entries: state.displayReceived,
                          acceptingIds: _acceptingInterestIds,
                          processingIds: _processingInterestIds,
                          onAccept: _acceptInterest,
                          onDecline: _declineInterest,
                        ),

                  // Sent tab
                  Column(
                    children: [
                      // Supabase-authoritative quota for every member.
                      _DailyLimitBanner(state: state),

                      Expanded(
                        child: state.sent.isEmpty
                            ? const SilarahEmptyState(
                                visual: SilarahEmptyVisual.sentInterests,
                                title: "You haven't sent any interests",
                                subtitle:
                                    'Browse profiles and send your first interest.',
                              )
                            : _SentList(
                                entries: state.sent,
                                onWithdraw: (entry) =>
                                    _showWithdrawDialog(entry),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DailyLimitBanner extends StatelessWidget {
  const _DailyLimitBanner({required this.state});
  final InterestsState state;

  @override
  Widget build(BuildContext context) {
    if (state.dailyLimit <= 0) return const SizedBox.shrink();

    final sent = state.interestsSentToday;
    final limit = state.dailyLimit;
    final frac = limit > 0 ? (sent / limit).clamp(0.0, 1.0) : 0.0;
    final atLimit = state.isDailyLimitReached;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppDimensions.space24, 0,
          AppDimensions.space24, AppDimensions.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                atLimit ? Icons.block_rounded : Icons.favorite_outline_rounded,
                size: 14,
                color: atLimit ? AppColors.softCoral : AppColors.champagneGold,
              ),
              const SizedBox(width: AppDimensions.space6),
              Expanded(
                child: UiText(
                  context.uiCopyWith('{tier} · {sent} of {limit} sent today', {
                    'tier':
                        context.uiCopy(state.isPremium ? 'Premium' : 'Free'),
                    'sent': sent,
                    'limit': limit,
                  }),
                  style: AppTypography.caption.copyWith(
                    color:
                        atLimit ? AppColors.softCoral : AppColors.champagneGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!atLimit)
                UiText(
                  context.uiCopyWith(
                      '{count} remaining', {'count': state.remainingToday}),
                  style: AppTypography.caption,
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.space6),
          // Gold progress bar (3px height)
          SilarahLinearProgress(
            value: frac,
            height: 3,
            trackColor: AppColors.surfaceGlassHover,
            color: atLimit ? AppColors.softCoral : AppColors.champagneGold,
          ),
        ],
      ),
    );
  }
}

// Avatar pair widget for match modal
class _MatchAvatarPair extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 30,
            child: _Avatar(border: AppColors.champagneGold),
          ),
          Positioned(
            right: 30,
            child: _Avatar(border: AppColors.champagneGold),
          ),
          // Heart badge
          Container(
            padding: const EdgeInsets.all(AppDimensions.space8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.champagneGold, width: 2),
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: AppColors.champagneGold,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.border});
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceGlassHover,
        border: Border.all(color: border, width: 2),
      ),
      child: Icon(
        Icons.person_rounded,
        color: AppColors.slateMist,
        size: 30,
      ),
    );
  }
}

// Received list
class _ReceivedList extends StatelessWidget {
  const _ReceivedList({
    required this.entries,
    required this.onAccept,
    required this.onDecline,
    required this.acceptingIds,
    required this.processingIds,
  });
  final List<InterestEntry> entries;
  final ValueChanged<InterestEntry> onAccept;
  final ValueChanged<InterestEntry> onDecline;
  final Set<String> acceptingIds;
  final Set<String> processingIds;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space24,
        vertical: AppDimensions.space4,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.space12),
      itemBuilder: (_, i) {
        final entry = entries[i];
        return _ReceivedTile(
          entry: entry,
          accepting: acceptingIds.contains(entry.id),
          processing: processingIds.contains(entry.id),
          onOpen: () => context.push('/profile/${entry.profile.id}'),
          onAccept: () => onAccept(entry),
          onDecline: () => onDecline(entry),
        );
      },
    );
  }
}

class _ReceivedTile extends StatelessWidget {
  const _ReceivedTile({
    required this.entry,
    required this.onOpen,
    required this.onAccept,
    required this.onDecline,
    required this.accepting,
    required this.processing,
  });
  final InterestEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool accepting;
  final bool processing;

  @override
  Widget build(BuildContext context) {
    final p = entry.profile;
    final status = entry.effectiveStatus;
    final isAccepted = status == InterestStatus.accepted;
    final isDeclined = status == InterestStatus.declined;
    final isPending = status == InterestStatus.pending;

    return AnimatedContainer(
      duration: AppDimensions.durationTransition,
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: isAccepted
              ? AppColors.goldBorder
              : isDeclined
                  ? AppColors.cardBorder.withValues(alpha: 0.5)
                  : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: avatar + name/city + time
          Semantics(
            button: true,
            label: context
                .uiCopyWith('View {name} profile', {'name': p.displayName}),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
              child: Row(
                children: [
                  _CircleAvatar(
                    photoUrl: p.photoUrl,
                    borderColor: isAccepted
                        ? AppColors.champagneGold
                        : AppColors.cardBorder,
                    opacity: isDeclined ? 0.5 : 1.0,
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UiText(
                          p.displayName,
                          style: AppTypography.bodyMedium.copyWith(
                            color: isDeclined
                                ? AppColors.slateMist
                                : AppColors.pearlWhite,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space2),
                        UiText(
                          '${p.age} · ${p.cityName}',
                          style: AppTypography.caption,
                        ),
                        if (p.occupation != null)
                          UiText(p.occupation!, style: AppTypography.caption),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      UiText(context.uiRelativeTime(entry.timeAgo),
                          style: AppTypography.caption),
                      const SizedBox(height: AppDimensions.space4),
                      if (isAccepted)
                        _StatusPill(
                            label: '✓ Matched', color: AppColors.champagneGold),
                      if (isDeclined)
                        _StatusPill(
                            label: 'Declined', color: AppColors.slateMist),
                    ],
                  ),
                  const SizedBox(width: AppDimensions.space4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.slateMist,
                    size: AppDimensions.iconSizeSmall,
                  ),
                ],
              ),
            ),
          ),

          // G3: Display sender's interest note
          if (entry.note != null && entry.note!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.space12),
              decoration: BoxDecoration(
                color: AppColors.champagneGold.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                border: Border.all(
                  color: AppColors.goldBorder.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote_rounded,
                      color: AppColors.champagneGold.withValues(alpha: 0.5),
                      size: 16),
                  const SizedBox(width: AppDimensions.space8),
                  Expanded(
                    child: UiText(
                      entry.note!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.pearlWhite.withValues(alpha: 0.85),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isPending) _ExpiryRow(entry: entry),

          // Action buttons — pending only
          if (isPending) ...[
            const SizedBox(height: AppDimensions.space14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      // Same height as Accept; the two themes differ.
                      minimumSize: const Size.fromHeight(48),
                      maximumSize: const Size.fromHeight(48),
                      side: BorderSide(color: AppColors.cardBorder),
                      foregroundColor: AppColors.slateMist,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusButton),
                      ),
                    ),
                    onPressed: accepting || processing
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            onDecline();
                          },
                    child: UiText(
                        AppLocalizations.of(context).interests_button_decline,
                        style: AppTypography.bodyMuted),
                  ),
                ),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      maximumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.champagneGold,
                      foregroundColor: AppColors.obsidianNight,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusButton),
                      ),
                      elevation: 0,
                    ),
                    onPressed: accepting || processing
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            onAccept();
                          },
                    child: accepting
                        ? SilarahActivityIndicator(
                            size: 18,
                            color: AppColors.obsidianNight,
                          )
                        : UiText(
                            AppLocalizations.of(context)
                                .interests_button_accept,
                            style: AppTypography.button),
                  ),
                ),
              ],
            ),
          ],

          // Message CTA — accepted only
          if (isAccepted) ...[
            const SizedBox(height: AppDimensions.space12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.champagneGold),
                  foregroundColor: AppColors.champagneGold,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: UiText(context.uiMessagePerson(p.firstName),
                    style: AppTypography.buttonSecondary),
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  await _openChatForProfile(context, p);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpiryRow extends StatelessWidget {
  const _ExpiryRow({required this.entry});
  final InterestEntry entry;

  @override
  Widget build(BuildContext context) {
    final hours = entry.hoursRemaining;
    if (hours == null) return const SizedBox.shrink();

    final isUrgent = hours < 24;
    final color = isUrgent ? AppColors.softCoral : AppColors.expiryAmber;
    final icon =
        isUrgent ? Icons.warning_amber_rounded : Icons.access_time_rounded;
    final days = entry.daysRemaining ?? 0;
    final text = isUrgent
        ? 'Expires today'
        : context.uiCopyWith(
            days == 1 ? 'Expires in {count} day' : 'Expires in {count} days',
            {'count': days});

    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: AppDimensions.space4),
          UiText(
            text,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// Sent list
class _SentList extends StatelessWidget {
  const _SentList({
    required this.entries,
    required this.onWithdraw,
  });
  final List<InterestEntry> entries;
  final ValueChanged<InterestEntry> onWithdraw;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space24,
        vertical: AppDimensions.space4,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.space12),
      itemBuilder: (_, i) {
        final entry = entries[i];
        return _SentTile(
          entry: entry,
          onWithdraw: () => onWithdraw(entry),
        );
      },
    );
  }
}

class _SentTile extends StatelessWidget {
  const _SentTile({required this.entry, required this.onWithdraw});
  final InterestEntry entry;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final p = entry.profile;
    final status = entry.effectiveStatus;
    final isPending = status == InterestStatus.pending;
    final isAccepted = status == InterestStatus.accepted;
    final isExpired = status == InterestStatus.expired;
    final isWithdrawn = status == InterestStatus.withdrawn;

    return AnimatedContainer(
      duration: AppDimensions.durationTransition,
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: isAccepted ? AppColors.goldBorder : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          _CircleAvatar(
            photoUrl: p.photoUrl,
            borderColor:
                isAccepted ? AppColors.champagneGold : AppColors.cardBorder,
            opacity: (isWithdrawn || isExpired) ? 0.5 : 1.0,
          ),
          const SizedBox(width: AppDimensions.space12),

          // Name + info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(
                  p.displayName,
                  style: AppTypography.bodyMedium.copyWith(
                    color: (isWithdrawn || isExpired)
                        ? AppColors.slateMist
                        : AppColors.pearlWhite,
                  ),
                ),
                const SizedBox(height: AppDimensions.space2),
                UiText('${p.age} · ${p.cityName}',
                    style: AppTypography.caption),
                if (isPending) _ExpiryRow(entry: entry),
              ],
            ),
          ),

          // Right side: time + status pill / withdraw
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              UiText(context.uiRelativeTime(entry.timeAgo),
                  style: AppTypography.caption),
              const SizedBox(height: AppDimensions.space6),
              if (isPending)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onWithdraw();
                  },
                  child: UiText(
                    context.uiCopy('Withdraw'),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.softCoral,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else if (isAccepted)
                _StatusPill(label: '✓ Accepted', color: AppColors.champagneGold)
              else if (isExpired)
                _StatusPill(label: 'Expired', color: AppColors.slateMist)
              else if (isWithdrawn)
                _StatusPill(label: 'Withdrawn', color: AppColors.slateMist)
              else
                _StatusPill(label: 'Declined', color: AppColors.softCoral),
            ],
          ),
        ],
      ),
    );
  }
}

// Shared widgets
class _CircleAvatar extends StatelessWidget {
  const _CircleAvatar({
    required this.borderColor,
    this.photoUrl,
    this.opacity = 1.0,
  });
  final Color borderColor;
  final String? photoUrl;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceGlassHover,
          border: Border.all(color: borderColor),
        ),
        child: ClipOval(
          child: photoUrl == null || photoUrl!.isEmpty
              ? Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.slateMist,
                  size: 28,
                )
              : SilarahBlurImage(
                  imageUrl: photoUrl!,
                  width: 52,
                  height: 52,
                ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusTiny),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: UiText(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.champagneGold,
        borderRadius: BorderRadius.circular(AppDimensions.radiusTiny),
      ),
      child: UiText(context.uiCopy('new'),
          style: AppTypography.badge.copyWith(fontSize: 10)),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.champagneGold,
        borderRadius: BorderRadius.circular(AppDimensions.radiusTiny),
      ),
      child: UiText('$count', style: AppTypography.badge),
    );
  }
}
