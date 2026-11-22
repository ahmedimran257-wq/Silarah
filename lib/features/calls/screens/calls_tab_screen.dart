// SILARAH — Calls tab (docs/voice_calling_spec.md 12.5, 13).
//
// Top to bottom: "turn on call notifications" (when this phone cannot
// ring), the minutes card, this month's talk time, planned calls, filters,
// then the history by day. Everything shown comes from the server; the app
// only arranges it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:silarah/l10n/ui_copy.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_curves.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations/silarah_motion.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/silarah_empty_state.dart';
import '../../home/screens/paywall_gate_screen.dart';
import '../call_api.dart';
import '../call_log.dart';
import '../call_log_controller.dart';
import '../call_platform.dart';
import '../calls_hub.dart';
import '../widgets/call_details_sheet.dart';
import '../widgets/call_minutes_sheet.dart';
import '../widgets/calls_tab_widgets.dart';
import '../widgets/chat_call_widgets.dart';

class CallsTabScreen extends StatefulWidget {
  const CallsTabScreen({super.key, this.initialPeerId, this.controller, this.hub});

  /// Opens this member's call details once the history has loaded.
  final String? initialPeerId;

  /// Tests pass their own; the app uses the defaults.
  final CallLogController? controller;
  final CallsHub? hub;

  @override
  State<CallsTabScreen> createState() => _CallsTabScreenState();
}

class _CallsTabScreenState extends State<CallsTabScreen> {
  late final CallLogController _log = widget.controller ?? CallLogController();
  late final CallsHub _hub = widget.hub ?? CallsHub.instance;
  final _search = TextEditingController();
  bool _searching = false;
  bool _peerOpened = false;

  @override
  void initState() {
    super.initState();
    unawaited(_log.load().then((_) => _openInitialPeer()));
  }

  @override
  void dispose() {
    if (widget.controller == null) _log.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _openInitialPeer() async {
    final peer = widget.initialPeerId;
    if (peer == null || _peerOpened || !mounted) return;
    _peerOpened = true;
    final rows = groupCallLog(_log.visibleEntries, now: DateTime.now()).expand((s) => s.rows);
    var row = rows.where((r) => r.latest.otherUserId == peer).firstOrNull;
    if (row == null) {
      final calls = await CallApi.instance.log(otherUserId: peer, limit: 100).catchError((_) => <CallLogEntry>[]);
      if (calls.isEmpty || !mounted) return;
      row = CallLogRow(calls);
    }
    await _openDetails(row);
  }

  Future<void> _refresh() async {
    await Future.wait([_hub.refresh(), _log.load(quiet: true)]);
  }

  Future<void> _openDetails(CallLogRow row) async {
    final result = await showCallDetailsSheet(
      context,
      row: row,
      photoUrl: _log.photoUrls[row.latest.otherUserId],
    );
    if (result != null && mounted) unawaited(_refresh());
  }

  Future<void> _callBack(CallLogEntry entry) async {
    final matchId = entry.matchId;
    if (matchId == null) return;
    await placeCall(
      context,
      matchId: matchId,
      name: entry.displayName,
      photoUrl: _log.photoUrls[entry.otherUserId],
      otherUserId: entry.otherUserId,
    );
  }

  void _remove(CallLogRow row) {
    final handle = _log.removeRow(row);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: UiText(context.uiCopy('Removed from your call history')),
      action: SnackBarAction(
        label: context.uiCopy('Undo'),
        textColor: AppColors.champagneGold,
        onPressed: handle.undo,
      ),
    ));
    unawaited(controller.closed.then((reason) async {
      if (reason == SnackBarClosedReason.action) return;
      final ok = await handle.commit();
      if (!ok && mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: UiText(context.uiCopy('Could not save. Please try again.')),
        ));
      }
    }));
  }

  Future<void> _respond(CallPlan plan, bool accept) async {
    final outcome = await CallApi.instance.respondPlan(plan.id, accept: accept);
    if (!mounted) return;
    if (outcome != 'accepted' && outcome != 'declined') {
      _snack(outcome == 'closed' ? 'This call time is no longer open.' : 'Could not save. Please try again.');
    }
    unawaited(_refresh());
  }

  Future<void> _cancel(CallPlan plan) async {
    final outcome = await CallApi.instance.cancelPlan(plan.id);
    if (!mounted) return;
    if (outcome != 'cancelled') _snack('Could not save. Please try again.');
    unawaited(_refresh());
  }

  Future<void> _callPlan(CallPlan plan) async {
    await placeCall(
      context,
      matchId: plan.matchId,
      name: plan.displayName,
      photoUrl: _log.photoUrls[plan.otherUserId],
      otherUserId: plan.otherUserId,
    );
  }

  void _snack(String copy) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: UiText(context.uiCopy(copy)),
    ));
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _search.clear();
        _log.setQuery('');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_log, _hub, _hub.unseenMissed]),
      builder: (context, _) {
        final overview = _hub.overview;
        if (overview != null) {
          unawaited(_log.loadPhotosFor(
            overview.plans.where((p) => !p.memberUnavailable).map((p) => p.otherUserId).whereType<String>(),
          ));
        }
        return Column(
          children: [
            _header(context),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.extentAfter < 480) unawaited(_log.loadMore());
                  return false;
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.horizontalMargin),
                      sliver: SliverList.list(
                        children: [
                          if (!_hub.phoneCanRing) ...[
                            SilarahEntrance(
                              child: CallNotificationsPrompt(
                                onOpenSettings: () => unawaited(CallPlatform.instance.openNotificationSettings()),
                              ),
                            ),
                            const SizedBox(height: AppDimensions.space12),
                          ],
                          if (overview != null) ...[
                            SilarahEntrance(
                              child: CallMinutesCard(
                                overview: overview,
                                onTopUp: () async {
                                  await showCallMinutesSheet(context);
                                  unawaited(_hub.refresh());
                                },
                                onPremium: () => PaywallGateSheet.show(context, gate: PremiumGate.calls),
                              ),
                            ),
                            if (overview.monthTalkSeconds > 0) ...[
                              const SizedBox(height: AppDimensions.space14),
                              SilarahEntrance(
                                delay: const Duration(milliseconds: 60),
                                child: CallInsightLine(seconds: overview.monthTalkSeconds),
                              ),
                            ],
                            if (overview.plans.isNotEmpty && _log.filter != CallLogFilter.planned) ...[
                              const SizedBox(height: AppDimensions.space20),
                              CallDayHeader(label: context.uiCopy('Planned calls')),
                              for (final plan in overview.plans) ...[
                                _planCard(plan, overview),
                                const SizedBox(height: AppDimensions.space8),
                              ],
                            ],
                          ] else
                            const SilarahShimmer(
                              child: ShimmerBox(width: double.infinity, height: 112, radius: AppDimensions.radiusCard),
                            ),
                          const SizedBox(height: AppDimensions.space16),
                        ],
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: CallFilterBar(
                        selected: _log.filter,
                        unseenMissed: _hub.unseenMissed.value,
                        onSelected: _log.setFilter,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.space8)),
                    ..._body(context, overview),
                    const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.space32)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _planCard(CallPlan plan, CallOverview? overview) => CallPlanCard(
        key: ValueKey('plan-${plan.id}'),
        plan: plan,
        photoUrl: _log.photoUrls[plan.otherUserId],
        premium: overview?.premium ?? false,
        female: overview?.female ?? false,
        onCall: () => _callPlan(plan),
        onPremium: () => PaywallGateSheet.show(context, gate: PremiumGate.calls),
        onRespond: (accept) => _respond(plan, accept),
        onCancel: () => _cancel(plan),
      );

  List<Widget> _body(BuildContext context, CallOverview? overview) {
    EdgeInsets pad() => const EdgeInsets.symmetric(horizontal: AppDimensions.horizontalMargin);
    if (_log.loading && (_log.filter == CallLogFilter.planned ? _log.plans.isEmpty : _log.entries.isEmpty)) {
      return [SliverPadding(padding: pad(), sliver: const SliverToBoxAdapter(child: CallsListSkeleton()))];
    }
    if (_log.failed && _log.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: SilarahEmptyState(
            visual: SilarahEmptyVisual.connection,
            title: 'Calls could not be loaded',
            subtitle: 'Check your connection and try again.',
            ctaLabel: 'Try again',
            onCta: () => unawaited(_log.load()),
          ),
        ),
      ];
    }
    if (_log.isEmpty) {
      final (title, subtitle) = switch (_log.filter) {
        _ when _log.query.isNotEmpty => ('No calls with that name', 'Try another name.'),
        CallLogFilter.missed => ('No missed calls', 'You are all caught up.'),
        CallLogFilter.incoming => ('No incoming calls yet', 'Calls from your matches will show here.'),
        CallLogFilter.outgoing => ('No outgoing calls yet', 'Calls you make will show here.'),
        CallLogFilter.planned => ('No planned calls', 'Choose a time to talk from a chat or a call\'s details.'),
        CallLogFilter.all => (
            'Your calls will appear here',
            'Call a match from your chat. Calls are private and never recorded.',
          ),
      };
      return [
        SliverToBoxAdapter(
          child: SilarahEmptyState(visual: SilarahEmptyVisual.calls, title: title, subtitle: subtitle),
        ),
      ];
    }
    if (_log.filter == CallLogFilter.planned) {
      return [
        SliverPadding(
          padding: pad(),
          sliver: SliverList.separated(
            itemCount: _log.plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.space8),
            itemBuilder: (context, i) => SilarahEntrance(
              delay: Duration(milliseconds: (i.clamp(0, 6)) * 40),
              child: _planCard(_log.plans[i], overview),
            ),
          ),
        ),
      ];
    }
    final sections = groupCallLog(_log.visibleEntries, now: DateTime.now());
    final items = <Widget>[];
    var index = 0;
    for (final section in sections) {
      items.add(CallDayHeader(label: callDayLabel(context, section)));
      for (final row in section.rows) {
        final entry = row.latest;
        final canCallBack = !entry.memberUnavailable && entry.matchId != null;
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.space8),
          child: SilarahEntrance(
            key: ValueKey('row-${entry.requestId}'),
            delay: Duration(milliseconds: (index.clamp(0, 6)) * 40),
            child: CallRowTile(
              row: row,
              photoUrl: _log.photoUrls[entry.otherUserId],
              onOpen: () => unawaited(_openDetails(row)),
              onCallBack: canCallBack ? () => unawaited(_callBack(entry)) : null,
              onRemove: () => _remove(row),
            ),
          ),
        ));
        index++;
      }
    }
    if (_log.loadingMore) {
      items.add(const Padding(
        padding: EdgeInsets.all(AppDimensions.space16),
        child: Center(child: SilarahActivityIndicator(size: 22, label: 'Loading more calls')),
      ));
    }
    return [SliverPadding(padding: pad(), sliver: SliverList.list(children: items))];
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.space24,
        AppDimensions.space16,
        AppDimensions.space24,
        AppDimensions.space16,
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: AppDimensions.durationTransition,
              switchInCurve: AppCurves.reveal,
              switchOutCurve: AppCurves.transition,
              child: _searching
                  ? TextField(
                      key: const ValueKey('calls_search'),
                      controller: _search,
                      autofocus: true,
                      onChanged: _log.setQuery,
                      style: AppTypography.body,
                      cursorColor: AppColors.champagneGold,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: context.uiCopy('Search by name'),
                        hintStyle: AppTypography.body.copyWith(color: AppColors.slateMist),
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.surfaceGlass,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.space12,
                          vertical: AppDimensions.space12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                          borderSide: BorderSide(color: AppColors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                          borderSide: BorderSide(color: AppColors.goldBorder),
                        ),
                      ),
                    )
                  : Align(
                      key: const ValueKey('calls_title'),
                      alignment: AlignmentDirectional.centerStart,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Semantics(
                          header: true,
                          child: UiText('Calls', style: AppTypography.screenTitle, maxLines: 1),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppDimensions.space8),
          SilarahPressable(
            semanticLabel: context.uiCopy(_searching ? 'Close search' : 'Search calls'),
            onTap: _toggleSearch,
            child: AnimatedContainer(
              duration: AppDimensions.durationTransition,
              curve: AppCurves.transition,
              width: AppDimensions.minTouchTarget,
              height: AppDimensions.minTouchTarget,
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                shape: BoxShape.circle,
                border: Border.all(color: _searching ? AppColors.goldBorder : AppColors.cardBorder),
              ),
              child: Icon(
                _searching ? Icons.close_rounded : Icons.search_rounded,
                color: AppColors.slateMist,
                size: AppDimensions.iconSizeLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
