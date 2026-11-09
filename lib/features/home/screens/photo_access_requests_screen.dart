import 'package:silarah/l10n/ui_copy.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/photo_access_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/live_refresh_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/overlays/silarah_dialog.dart';

class PhotoAccessRequestsScreen extends StatefulWidget {
  const PhotoAccessRequestsScreen({super.key});

  @override
  State<PhotoAccessRequestsScreen> createState() =>
      _PhotoAccessRequestsScreenState();
}

class _PhotoAccessRequestsScreenState extends State<PhotoAccessRequestsScreen>
    with WidgetsBindingObserver {
  List<IncomingPhotoAccessRequest> _requests = const [];
  final Set<String> _busyIds = <String>{};
  RealtimeChannel? _channel;
  bool _loading = true;
  String? _error;
  late final LiveRefreshController _refresh;
  bool _loadInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh = LiveRefreshController(refresh: () => _load(silent: true))
      ..start();
    unawaited(_load());
    unawaited(_subscribe());
  }

  Future<void> _subscribe() async {
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (!mounted || userId == null) return;
    final channel = SupabaseService.client
        .channel('photo_access_requests_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'photo_access_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'owner_id',
            value: userId,
          ),
          callback: (_) => _refresh.request(),
        )
        .subscribe((status, error) {
      if (mounted && SupabaseService.currentUserId == userId) {
        _refresh.setConnected(status == RealtimeSubscribeStatus.subscribed);
      }
    });
    if (!mounted) {
      await SupabaseService.client.removeChannel(channel);
      return;
    }
    _channel = channel;
  }

  Future<void> _load({bool silent = false}) async {
    if (_loadInFlight) {
      _refresh.request();
      return;
    }
    final actor = SupabaseService.currentUserId;
    _loadInFlight = true;
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final requests = await PhotoAccessService.instance.getIncomingRequests();
      if (!mounted || SupabaseService.currentUserId != actor) return;
      setState(() {
        _requests = requests;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is StateError
            ? error.message
            : 'Photo requests could not be loaded.';
      });
    } finally {
      _loadInFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh.start();
      _refresh.request();
    } else {
      _refresh.stop();
    }
  }

  Future<void> _respond(
    IncomingPhotoAccessRequest request, {
    required bool grant,
  }) async {
    if (_busyIds.contains(request.id)) return;
    setState(() => _busyIds.add(request.id));
    try {
      final status = await PhotoAccessService.instance.respond(
        request.id,
        grant: grant,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _requests = _requests
            .map((item) =>
                item.id == request.id ? item.copyWith(status: status) : item)
            .toList(growable: false);
      });
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busyIds.remove(request.id));
    }
  }

  Future<void> _revoke(IncomingPhotoAccessRequest request) async {
    final confirmed = await showSilarahDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            title: UiText(context.uiCopy('Revoke photo access?'),
                style: AppTypography.bodyMedium),
            content: UiText(
              context.uiCopyWith(
                  '{name} will no longer be able to open your private photos.',
                  {'name': request.displayName}),
              style: AppTypography.bodyMuted,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: UiText(context.uiCopy('Keep access')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: UiText(context.uiCopy('Revoke'),
                    style: TextStyle(color: AppColors.softCoral)),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || _busyIds.contains(request.id)) return;
    setState(() => _busyIds.add(request.id));
    try {
      final status = await PhotoAccessService.instance.revoke(request.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _requests = _requests
            .map((item) =>
                item.id == request.id ? item.copyWith(status: status) : item)
            .toList(growable: false);
      });
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busyIds.remove(request.id));
    }
  }

  void _showError(Object error) {
    final message = error is StateError
        ? error.message
        : 'Photo access could not be updated.';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: UiText(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.snackbarSurface,
      ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refresh.dispose();
    final channel = _channel;
    if (channel != null) {
      unawaited(SupabaseService.client
          .removeChannel(channel)
          .catchError((Object _) => 'error'));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        _requests.where((item) => item.status == 'pending').toList();
    final granted =
        _requests.where((item) => item.status == 'granted').toList();
    final history = _requests
        .where((item) => item.status != 'pending' && item.status != 'granted')
        .toList();

    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: AppColors.obsidianNight,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.uiCopy('Back'),
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: UiText(context.uiCopy('Photo access'),
            style: AppTypography.bodyMedium),
      ),
      body: RefreshIndicator(
        color: AppColors.champagneGold,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.space24,
            AppDimensions.space16,
            AppDimensions.space24,
            AppDimensions.space48,
          ),
          children: [
            const _AccessHeader(),
            const SizedBox(height: AppDimensions.space24),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: AppDimensions.space64),
                child: Center(child: SilarahPulseLoader(size: 48)),
              )
            else if (_error != null)
              _AccessError(message: _error!, onRetry: _load)
            else if (_requests.isEmpty)
              const _NoRequests()
            else ...[
              if (pending.isNotEmpty) ...[
                _AccessSectionLabel(label: 'PENDING', count: pending.length),
                const SizedBox(height: AppDimensions.space10),
                ...pending.map((request) => _AccessRequestCard(
                      request: request,
                      busy: _busyIds.contains(request.id),
                      onGrant: () => _respond(request, grant: true),
                      onDeny: () => _respond(request, grant: false),
                      onRevoke: null,
                    )),
              ],
              if (granted.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.space20),
                _AccessSectionLabel(
                    label: 'SHARED WITH', count: granted.length),
                const SizedBox(height: AppDimensions.space10),
                ...granted.map((request) => _AccessRequestCard(
                      request: request,
                      busy: _busyIds.contains(request.id),
                      onGrant: null,
                      onDeny: null,
                      onRevoke: () => _revoke(request),
                    )),
              ],
              if (history.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.space20),
                _AccessSectionLabel(label: 'HISTORY', count: history.length),
                const SizedBox(height: AppDimensions.space10),
                ...history.map((request) => _AccessRequestCard(
                      request: request,
                      busy: _busyIds.contains(request.id),
                      onGrant: request.status == 'denied'
                          ? () => _respond(request, grant: true)
                          : null,
                      onDeny: null,
                      onRevoke: null,
                    )),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _AccessHeader extends StatelessWidget {
  const _AccessHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiText(
          context.uiCopy('You decide who sees you'),
          style: AppTypography.screenTitle,
        ),
        const SizedBox(height: AppDimensions.space10),
        UiText(
          context.uiCopy(
              'Review every request individually. Access can be revoked whenever you choose.'),
          style: AppTypography.bodyMuted.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

class _AccessSectionLabel extends StatelessWidget {
  const _AccessSectionLabel({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UiText(label, style: AppTypography.sectionLabel),
        const SizedBox(width: AppDimensions.space8),
        UiText('$count',
            style:
                AppTypography.caption.copyWith(color: AppColors.champagneGold)),
      ],
    );
  }
}

class _AccessRequestCard extends StatelessWidget {
  const _AccessRequestCard({
    required this.request,
    required this.busy,
    required this.onGrant,
    required this.onDeny,
    required this.onRevoke,
  });

  final IncomingPhotoAccessRequest request;
  final bool busy;
  final VoidCallback? onGrant;
  final VoidCallback? onDeny;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final initial = request.firstName.isEmpty
        ? 'S'
        : request.firstName.characters.first.toUpperCase();
    return AnimatedContainer(
      duration: AppDimensions.durationTransition,
      margin: const EdgeInsets.only(bottom: AppDimensions.space10),
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(
          color: request.status == 'pending'
              ? AppColors.goldBorder
              : AppColors.cardBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.goldGlow,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                ),
                child: UiText(initial,
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.champagneLight)),
              ),
              const SizedBox(width: AppDimensions.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UiText(request.displayName,
                        style: AppTypography.bodyMedium),
                    const SizedBox(height: AppDimensions.space2),
                    UiText(_statusLabel(request.status),
                        style: AppTypography.caption
                            .copyWith(color: _statusColor(request.status))),
                  ],
                ),
              ),
              if (busy)
                SilarahActivityIndicator(
                  size: 22,
                  color: AppColors.champagneGold,
                ),
            ],
          ),
          if (!busy &&
              (onGrant != null || onDeny != null || onRevoke != null)) ...[
            const SizedBox(height: AppDimensions.space14),
            Row(
              children: [
                if (onDeny != null)
                  Expanded(
                    child: _AccessButton(
                      label: 'Decline',
                      onTap: onDeny,
                      primary: false,
                    ),
                  ),
                if (onDeny != null && onGrant != null)
                  const SizedBox(width: AppDimensions.space10),
                if (onGrant != null)
                  Expanded(
                    child: _AccessButton(
                      label: request.status == 'denied'
                          ? 'Grant access'
                          : 'Share photos',
                      onTap: onGrant,
                      primary: true,
                    ),
                  ),
                if (onRevoke != null)
                  Expanded(
                    child: _AccessButton(
                      label: 'Revoke access',
                      onTap: onRevoke,
                      primary: false,
                      danger: true,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'pending' => 'Waiting for your decision',
        'granted' => 'Can currently view your photos',
        'denied' => 'Request declined',
        'revoked' => 'Access revoked',
        _ => status,
      };

  Color _statusColor(String status) => switch (status) {
        'granted' => AppColors.verifiedTeal,
        'pending' => AppColors.champagneGold,
        'denied' || 'revoked' => AppColors.slateMist,
        _ => AppColors.slateMist,
      };
}

class _AccessButton extends StatelessWidget {
  const _AccessButton({
    required this.label,
    required this.onTap,
    required this.primary,
    this.danger = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? AppColors.softCoral : AppColors.champagneGold;
    return SilarahPressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: AppDimensions.buttonHeightSmall,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? AppColors.champagneGold : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: primary ? AppColors.champagneGold : accent),
        ),
        child: UiText(
          label,
          style: AppTypography.captionMedium.copyWith(
            color: primary ? AppColors.obsidianNight : accent,
          ),
        ),
      ),
    );
  }
}

class _NoRequests extends StatelessWidget {
  const _NoRequests();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space64),
      child: Column(
        children: [
          Icon(Icons.lock_person_outlined,
              color: AppColors.champagneGold, size: 48),
          const SizedBox(height: AppDimensions.space16),
          UiText(context.uiCopy('No photo requests'),
              style: AppTypography.bodyMedium),
          const SizedBox(height: AppDimensions.space6),
          UiText(
            context.uiCopy('New requests will appear here instantly.'),
            style: AppTypography.bodyMuted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AccessError extends StatelessWidget {
  const _AccessError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space48),
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, color: AppColors.slateMist, size: 42),
          const SizedBox(height: AppDimensions.space12),
          UiText(message,
              style: AppTypography.bodyMuted, textAlign: TextAlign.center),
          const SizedBox(height: AppDimensions.space16),
          _AccessButton(label: 'Try again', onTap: onRetry, primary: false),
        ],
      ),
    );
  }
}
