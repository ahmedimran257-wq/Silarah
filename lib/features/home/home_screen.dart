// SILARAH — Home Screen Shell
// IndexedStack with 4 tabs + SilarahBottomNav.
// Preserves scroll state across tab switches.
import 'package:silarah/l10n/ui_copy.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/cubits/account_standing/account_standing_cubit.dart';
import '../../core/cubits/account_standing/account_standing_state.dart';
import '../../core/cubits/chat/chat_cubit.dart';
import '../../core/cubits/discovery/discovery_feed_cubit.dart';
import '../../core/cubits/interests/interests_cubit.dart';
import '../../core/cubits/interests/interests_state.dart';
import '../../core/cubits/notifications/notifications_cubit.dart';
import '../../core/cubits/subscription/subscription_cubit.dart';
import '../../core/cubits/subscription/subscription_state.dart';
import '../../core/router/app_router.dart';
import '../../core/router/notification_navigation.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/coach_mark_service.dart';
import '../../core/services/policy_reminder_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_curves.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons/silarah_pressable.dart';
import '../../core/widgets/loaders/silarah_shimmer.dart';
import '../../core/widgets/silarah_coach_mark.dart';
import 'screens/discovery_feed_screen.dart';
import 'screens/interests_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/my_profile_screen.dart';
import 'widgets/silarah_bottom_nav.dart';
import 'widgets/interest_quota_sheet.dart';
import 'widgets/policy_reminder_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTab});
  final int? initialTab;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentTab = 0;
  late final List<Widget?> _tabCache;
  int _profileRefreshToken = 0;
  bool _policyReminderChecked = false;
  late final CoachMarkService _coachMarks;
  int? _coachTab;
  bool _coachCheckInFlight = false;
  static const _tabCount = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _coachMarks = CoachMarkService();
    CoachMarkService.replayRevision.addListener(_replayCoachMarks);
    if (widget.initialTab != null) {
      _currentTab = widget.initialTab!;
    }
    _tabCache = List<Widget?>.filled(_tabCount, null);
    _ensureTabBuilt(_currentTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPolicyReminderIfDue();
    });
  }

  Future<void> _showPolicyReminderIfDue() async {
    if (_policyReminderChecked) return;
    _policyReminderChecked = true;
    final state = await PolicyReminderService.instance.getState();
    if (!mounted) return;
    if (state.isDue) {
      await PolicyReminderSheet.show(context);
    }
    if (mounted) await _showCoachMarkIfNeeded(_currentTab);
  }

  Future<void> _showCoachMarkIfNeeded(int tab) async {
    if (_coachCheckInFlight || _coachTab != null) return;
    _coachCheckInFlight = true;
    final interests = context.read<InterestsCubit>().state;
    final alreadyUsed = switch (tab) {
      1 => interests.sent.isNotEmpty || interests.respondedReceived.isNotEmpty,
      2 => context.read<ChatCubit>().state.conversations.isNotEmpty,
      _ => false,
    };
    final shouldShow = await _coachMarks.shouldShow(
      _coachTips[tab].id,
      alreadyUsed: alreadyUsed,
    );
    if (!mounted) return;
    _coachCheckInFlight = false;
    if (tab != _currentTab) {
      await _showCoachMarkIfNeeded(_currentTab);
      return;
    }
    if (!shouldShow || _coachTab != null) return;

    // Marking on presentation prevents a tip from repeatedly returning when a
    // member navigates away without pressing a button.
    await _coachMarks.markSeen(_coachTips[tab].id);
    if (mounted && tab == _currentTab) setState(() => _coachTab = tab);
  }

  void _dismissCoachMark() {
    if (_coachTab != null) setState(() => _coachTab = null);
  }

  void _replayCoachMarks() {
    if (!mounted) return;
    _dismissCoachMark();
    _showCoachMarkIfNeeded(_currentTab);
  }

  Future<void> _disableCoachMarks() async {
    await _coachMarks.disableAll();
    if (mounted) _dismissCoachMark();
  }

  @override
  void dispose() {
    for (final timer in _entitlementReloads) {
      timer.cancel();
    }
    CoachMarkService.replayRevision.removeListener(_replayCoachMarks);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshTabData(_currentTab);
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != null &&
        widget.initialTab != oldWidget.initialTab) {
      _ensureTabBuilt(widget.initialTab!);
      _currentTab = widget.initialTab!;
    }
  }

  /// Allows child widgets (e.g. DiscoveryFeedScreen) to switch tabs programmatically.
  void switchToTab(int index) {
    if (index < 0 || index >= _tabCount || index == _currentTab) return;
    setState(() {
      _ensureTabBuilt(index);
      if (index == 3) {
        _tabCache[3] = MyProfileScreen(refreshToken: ++_profileRefreshToken);
      }
      _coachTab = null;
      _currentTab = index;
    });
    _refreshTabData(index);
    _showCoachMarkIfNeeded(index);
  }

  void _selectTab(int index) {
    if (index == _currentTab) {
      _refreshTabData(index);
      _showCoachMarkIfNeeded(index);
      return;
    }
    setState(() {
      _ensureTabBuilt(index);
      if (index == 3) {
        _tabCache[3] = MyProfileScreen(refreshToken: ++_profileRefreshToken);
      }
      _coachTab = null;
      _currentTab = index;
    });
    _refreshTabData(index);
    _showCoachMarkIfNeeded(index);
  }

  void _refreshTabData(int index) {
    switch (index) {
      case 0:
        context.read<DiscoveryFeedCubit>().refreshIfChanged();
      case 1:
        // Selecting Interests is an explicit freshness boundary. This performs
        // one tiny revision check and reloads the bounded lists only on change.
        context.read<InterestsCubit>().refreshIfChanged(forceCheck: true);
        // Seeing the Interests tab handles "new interest" / "accepted" alerts.
        context.read<NotificationsCubit>().markHandled(
              (n) =>
                  n.type == 'interest_received' ||
                  n.type == 'interest_accepted',
            );
      case 2:
        context.read<ChatCubit>().refreshIfChanged();
    }
  }

  void _ensureTabBuilt(int index) {
    _tabCache[index] ??= switch (index) {
      0 => DiscoveryFeedScreen(onOpenTab: switchToTab),
      1 => const InterestsScreen(),
      2 => const ChatListScreen(),
      _ => MyProfileScreen(refreshToken: _profileRefreshToken),
    };
  }

  final _entitlementReloads = <Timer>[];

  /// Locked inbox previews and message gates come from the server. When
  /// Premium switches on (a purchase) or off (expiry), reload them now and
  /// again after the RevenueCat webhook has had time to reach the server.
  void _reloadForEntitlementChange() {
    for (final timer in _entitlementReloads) {
      timer.cancel();
    }
    _entitlementReloads.clear();
    void reload() {
      if (!mounted) return;
      context
          .read<ChatCubit>()
          .loadConversations(showLoading: false, force: true);
    }

    reload();
    for (final delay in const [Duration(seconds: 4), Duration(seconds: 12)]) {
      _entitlementReloads.add(Timer(delay, reload));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return HomeTabBackScope(
      currentTab: _currentTab,
      onReturnToPrimaryTab: () => _selectTab(0),
      child: BlocListener<SubscriptionCubit, SubscriptionState>(
        listenWhen: (previous, current) =>
            previous.isSubscribed != current.isSubscribed,
        listener: (_, __) => _reloadForEntitlementChange(),
        child: BlocListener<InterestsCubit, InterestsState>(
          listenWhen: (previous, current) =>
              (!previous.limitError && current.limitError) ||
              // Background refreshes (start-up, resume, entitlement reloads)
              // retry quietly; only a failed check while starting an
              // interest is worth interrupting the member for.
              (!previous.quotaCheckFailed && current.quotaCheckFailed),
          listener: (context, quota) {
            if (quota.limitError) {
              InterestQuotaSheet.show(context, quota: quota);
              context.read<InterestsCubit>().clearLimitError();
              return;
            }
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(SnackBar(
                content: UiText(
                  context.uiCopy(
                      'We could not verify your daily allowance. Check your connection and try again.'),
                ),
                behavior: SnackBarBehavior.floating,
              ));
            context.read<InterestsCubit>().clearQuotaUnavailable();
          },
          child: Scaffold(
            backgroundColor: AppColors.obsidianNight,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const _ConnectivityStatusBanner(),
                  BlocBuilder<AccountStandingCubit, AccountStandingState>(
                    buildWhen: (previous, current) =>
                        previous.kind != current.kind ||
                        previous.updating != current.updating ||
                        previous.errorMessage != current.errorMessage,
                    builder: (context, standing) => AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : AppDimensions.durationReveal,
                      switchInCurve: AppCurves.reveal,
                      switchOutCurve: AppCurves.dismiss,
                      // The Profile tab (index 3) shows the same standing in its
                      // own card with a Resume action, so the banner would repeat.
                      child: standing.showsPersistentNotice && _currentTab != 3
                          ? _PersistentStandingBanner(
                              key: ValueKey(standing.kind),
                              standing: standing,
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('standing-clear')),
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _currentTab,
                      children: List.generate(
                        _tabCount,
                        (index) => TickerMode(
                          enabled: index == _currentTab,
                          child: ExcludeSemantics(
                            excluding: index != _currentTab,
                            child: RepaintBoundary(
                              child:
                                  _tabCache[index] ?? const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A dedicated dock cannot obscure bookmark, interest, or chat
                // actions. Large-text tips scroll independently above navigation.
                if (_coachTab case final int tab)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 560,
                      maxHeight: MediaQuery.sizeOf(context).height * .34,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: SilarahCoachMark(
                        icon: _coachTips[tab].icon,
                        title: context.uiCopy(_coachTips[tab].title),
                        message: context.uiCopy(_coachTips[tab].message),
                        onDismiss: _dismissCoachMark,
                        onDisableAll: _disableCoachMarks,
                      ),
                    ),
                  ),
                SilarahBottomNav(
                  currentIndex: _currentTab,
                  onTabSelected: _selectTab,
                ),
              ],
            ),
            resizeToAvoidBottomInset: false,
          ),
        ),
      ),
    );
  }
}

class _CoachTip {
  const _CoachTip({
    required this.id,
    required this.icon,
    required this.title,
    required this.message,
  });

  final String id;
  final IconData icon;
  final String title;
  final String message;
}

const _coachTips = <_CoachTip>[
  _CoachTip(
    id: 'discover',
    icon: Icons.tune_rounded,
    title: 'Shape your discovery',
    message:
        'Use filters to focus on age, location, practice, and trust signals. Save a profile when you want time to consider it.',
  ),
  _CoachTip(
    id: 'interests',
    icon: Icons.favorite_outline_rounded,
    title: 'Keep every interest clear',
    message:
        'Every interest keeps a clear status. Open Sent to review, withdraw, or follow its progress without losing the profile.',
  ),
  _CoachTip(
    id: 'chat',
    icon: Icons.forum_outlined,
    title: 'Conversations begin after acceptance',
    message:
        'A conversation opens after an interest is accepted. Women message free; men use Premium to send.',
  ),
  _CoachTip(
    id: 'profile',
    icon: Icons.visibility_outlined,
    title: 'Build trust at your pace',
    message:
        'The activity eye shows profile visits. Your profile, photo controls, and optional trust checks stay together here.',
  ),
];

class _ConnectivityStatusBanner extends StatelessWidget {
  const _ConnectivityStatusBanner();

  @override
  Widget build(BuildContext context) {
    if (!ConnectivityService.isInitialized) {
      return const SizedBox.shrink();
    }
    final connectivity = ConnectivityService.instance;
    return StreamBuilder<bool>(
      stream: connectivity.connectivityStream,
      initialData: connectivity.isOnline,
      builder: (context, snapshot) {
        final disconnected = snapshot.data == false;
        final offline = disconnected && !connectivity.hasNetworkInterface;
        final message = offline
            ? 'No internet connection. Saved content remains available and reconnection is automatic.'
            : 'Silarah is temporarily unavailable. Saved content remains available and retry is automatic.';
        return AnimatedSwitcher(
          duration: AppDimensions.durationTransition,
          child: disconnected
              ? Semantics(
                  key: const ValueKey('offline-banner'),
                  liveRegion: true,
                  container: true,
                  label: context.uiCopy(message),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space16,
                      vertical: AppDimensions.space8,
                    ),
                    color: AppColors.errorRed.withValues(alpha: .12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: AppDimensions.iconSizeSmall,
                          color: AppColors.softCoral,
                        ),
                        const SizedBox(width: AppDimensions.space8),
                        Flexible(
                          child: UiText(
                            message,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.softCoral,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('online-banner')),
        );
      },
    );
  }
}

class _PersistentStandingBanner extends StatelessWidget {
  const _PersistentStandingBanner({
    super.key,
    required this.standing,
  });

  final AccountStandingState standing;

  @override
  Widget build(BuildContext context) {
    final restricted = standing.isRestricted;
    final accent = restricted ? AppColors.softCoral : AppColors.champagneGold;
    final (title, message, icon) = switch (standing.kind) {
      AccountStandingKind.paused => (
          'Profile paused',
          'You are hidden from discovery.',
          Icons.pause_circle_outline_rounded,
        ),
      AccountStandingKind.suspended => (
          'Profile suspended',
          'Discovery access is restricted. Support can review this decision.',
          Icons.gpp_maybe_outlined,
        ),
      AccountStandingKind.banned => (
          'Account banned',
          'Your account has an enforced restriction. Contact support to appeal.',
          Icons.block_rounded,
        ),
      _ => (
          'Profile unavailable',
          'Contact support for help restoring your profile.',
          Icons.person_off_outlined,
        ),
    };

    return Semantics(
      liveRegion: true,
      container: true,
      label: '${context.uiCopy(title)}. ${context.uiCopy(message)}',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: accent.withValues(alpha: 0.42)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText(
                    title,
                    style: AppTypography.captionMedium.copyWith(color: accent),
                  ),
                  const SizedBox(height: 2),
                  UiText(
                    standing.errorMessage ?? message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(height: 1.25),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SilarahPressable(
              semanticLabel: restricted ? 'Contact support' : 'Resume profile',
              onTap: standing.updating
                  ? null
                  : restricted
                      ? () => context.push(AppRoutes.helpSupport)
                      : () =>
                          context.read<AccountStandingCubit>().resumeProfile(),
              enabled: !standing.updating,
              child: Container(
                constraints: const BoxConstraints(minWidth: 76),
                height: 38,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: restricted ? Colors.transparent : accent,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                  border: Border.all(color: accent),
                ),
                child: standing.updating
                    ? SilarahActivityIndicator(
                        size: 17,
                        color: restricted ? accent : AppColors.obsidianNight,
                      )
                    : UiText(
                        restricted ? 'Get help' : 'Resume',
                        style: AppTypography.captionMedium.copyWith(
                          color: restricted ? accent : AppColors.obsidianNight,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
