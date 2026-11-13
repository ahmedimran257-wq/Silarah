// SILARAH — Guardian (Wali) Dashboard Screen
//
// Full in-app chat mirror for guardians. This is the guardian's
// primary interface when they log in. Shows all active
// conversations their ward is engaged in, with:
//   • Live message updates via Supabase Realtime
//   • Unread message badges
//   • Match approval controls (active mode)
//   • Read-only or interactive chat access
//
// This is SILARAH's biggest competitive moat against Muzz/Salams.
import 'dart:async';

import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';

import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/wali_mode_service.dart';
import '../../../core/services/live_refresh_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';

class GuardianDashboardScreen extends StatefulWidget {
  const GuardianDashboardScreen({super.key});

  @override
  State<GuardianDashboardScreen> createState() =>
      _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen>
    with WidgetsBindingObserver {
  final _waliService = WaliModeService.instance;
  List<GuardianDashboardItem> _chats = [];
  bool _isLoading = true;
  bool _isRealtimeConnected = false;
  late final LiveRefreshController _dashboardRefresh;
  bool _loadInFlight = false;
  bool _transcriptOpen = false;
  String? _pendingMarkSeenWardId;
  bool _hasLinkedWards = false;
  String? _dashboardError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dashboardRefresh =
        LiveRefreshController(refresh: () => _loadDashboard(silent: true))
          ..start();
    _loadDashboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dashboardRefresh.dispose();
    if (SupabaseService.isInitialized) {
      _waliService.disposeRealtime();
    }
    super.dispose();
  }

  Future<void> _loadDashboard(
      {String? markSeenWardId, bool silent = false}) async {
    if (!SupabaseService.isInitialized) {
      if (mounted) {
        setState(() {
          _chats = [];
          _isLoading = false;
        });
      }
      return;
    }
    if (_loadInFlight) {
      _pendingMarkSeenWardId = markSeenWardId ?? _pendingMarkSeenWardId;
      _dashboardRefresh.request();
      return;
    }
    _loadInFlight = true;
    final actor = SupabaseService.currentUserId;
    if (!silent) setState(() => _isLoading = true);
    try {
      final chats = await _waliService.getDashboard(
        markSeenWardId: markSeenWardId,
      );
      final linked = chats.isNotEmpty || await _waliService.hasLinkedWards();
      if (mounted && SupabaseService.currentUserId == actor) {
        setState(() {
          _chats = chats;
          _hasLinkedWards = linked;
          _dashboardError = null;
          _isLoading = false;
        });
        if (linked) {
          _setupRealtime();
        } else {
          _waliService.disposeRealtime();
          _dashboardRefresh.stop();
          setState(() => _isRealtimeConnected = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _chats = [];
          _dashboardError =
              'Unable to refresh Guardian access. Please try again.';
        });
      }
    } finally {
      _loadInFlight = false;
      final pending = _pendingMarkSeenWardId;
      _pendingMarkSeenWardId = null;
      if (mounted &&
          pending != null &&
          SupabaseService.currentUserId == actor) {
        unawaited(_loadDashboard(markSeenWardId: pending, silent: true));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_transcriptOpen) {
      _dashboardRefresh.start();
      _dashboardRefresh.request();
    } else {
      _dashboardRefresh.stop();
    }
  }

  void _setupRealtime() {
    if (!SupabaseService.isInitialized ||
        !_hasLinkedWards ||
        _waliService.hasRealtimeChannel) {
      return;
    }
    _waliService.subscribeToMirroredChats(
      onNewMessage: (message) {
        // Refresh dashboard to update unread counts and last message
        _dashboardRefresh.request();
      },
      onStatusChange: (connected) {
        _dashboardRefresh.setConnected(connected);
        if (mounted) {
          setState(() => _isRealtimeConnected = connected);
        }
      },
    );
  }

  Future<void> _handleApproveMatch(GuardianDashboardItem chat) async {
    HapticFeedback.mediumImpact();
    try {
      await _waliService.approveMatch(chat.matchId);
      await _loadDashboard();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: UiText(
              context.uiCopyWith(
                  'Match approved — {ward} can now message {other}', {
                'ward': chat.wardName,
                'other': chat.otherPartyName,
              }),
              style: AppTypography.body.copyWith(
                color: AppColors.readableOn(AppColors.verifiedTeal),
              ),
            ),
            backgroundColor: AppColors.verifiedTeal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: UiText(
              context
                  .uiCopyWith('Failed to approve match: {error}', {'error': e}),
              style: AppTypography.body.copyWith(
                color: AppColors.readableOn(AppColors.errorRed),
              ),
            ),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openTranscript(GuardianDashboardItem chat) async {
    if (_transcriptOpen) return;
    _transcriptOpen = true;
    _dashboardRefresh.stop();
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _GuardianTranscriptScreen(chat: chat),
        ),
      );
    } finally {
      _transcriptOpen = false;
      if (mounted) {
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed) {
          _dashboardRefresh.start();
        }
        await _loadDashboard(markSeenWardId: chat.wardUserId, silent: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            UiText('سيلارا',
                style: AppTypography.wordmark.copyWith(fontSize: 22)),
            const SizedBox(width: AppDimensions.space6),
            UiText(context.uiCopy('GUARDIAN'),
                style: AppTypography.wordmark.copyWith(fontSize: 16)),
            const Spacer(),
            // Realtime connection indicator
            if (_hasLinkedWards)
              _RealtimeIndicator(isConnected: _isRealtimeConnected),
            PopupMenuButton<_GuardianAccountAction>(
              tooltip: context.uiCopy('Guardian account'),
              color: AppColors.surfaceDark,
              icon: Icon(
                Icons.account_circle_outlined,
                color: AppColors.pearlWhite,
              ),
              onSelected: (action) async {
                switch (action) {
                  case _GuardianAccountAction.acceptAnother:
                    await context.push(AppRoutes.guardianConnect);
                    if (mounted) {
                      _dashboardRefresh.start();
                      await _loadDashboard();
                    }
                    break;
                  case _GuardianAccountAction.help:
                    context.push(AppRoutes.helpSupport);
                    break;
                  case _GuardianAccountAction.delete:
                    context.push(AppRoutes.deleteAccount);
                    break;
                  case _GuardianAccountAction.signOut:
                    await context.read<AuthCubit>().signOut();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _GuardianAccountAction.acceptAnother,
                  child: UiText(
                    context.uiCopy('Accept another Guardian invitation'),
                  ),
                ),
                PopupMenuItem(
                  value: _GuardianAccountAction.help,
                  child: UiText(context.uiCopy('Help & Support')),
                ),
                PopupMenuItem(
                  value: _GuardianAccountAction.delete,
                  child: UiText(context.uiCopy('Delete account')),
                ),
                PopupMenuItem(
                  value: _GuardianAccountAction.signOut,
                  child: UiText(context.uiCopy('Sign out')),
                ),
              ],
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const _DashboardShimmer()
          : _dashboardError != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  UiText(context.uiCopy(_dashboardError!)),
                  TextButton(
                      onPressed: _loadDashboard,
                      child: UiText(context.uiCopy('Try again'))),
                ]))
              : _chats.isEmpty
                  ? _EmptyDashboard(onRefresh: _loadDashboard)
                  : RefreshIndicator(
                      color: AppColors.champagneGold,
                      backgroundColor: AppColors.obsidianNight,
                      onRefresh: _loadDashboard,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.space16,
                          vertical: AppDimensions.space12,
                        ),
                        itemCount: _chats.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppDimensions.space10),
                        itemBuilder: (context, index) {
                          final chat = _chats[index];
                          return _ChatTile(
                            chat: chat,
                            onTap: () => unawaited(_openTranscript(chat)),
                            onApprove: chat.needsApproval
                                ? () => _handleApproveMatch(chat)
                                : null,
                          );
                        },
                      ),
                    ),
    );
  }
}

enum _GuardianAccountAction { acceptAnother, help, delete, signOut }

class _GuardianTranscriptScreen extends StatefulWidget {
  const _GuardianTranscriptScreen({required this.chat});

  final GuardianDashboardItem chat;

  @override
  State<_GuardianTranscriptScreen> createState() =>
      _GuardianTranscriptScreenState();
}

class _GuardianTranscriptScreenState extends State<_GuardianTranscriptScreen>
    with WidgetsBindingObserver {
  final _service = WaliModeService.instance;
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  final List<GuardianTranscriptMessage> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<void>? _accessSubscription;
  late final LiveRefreshController _transcriptRefresh;
  bool _latestInFlight = false;
  String? _sendOperationId;
  String? _sendContent;
  late GuardianDashboardItem _chat;
  bool _loading = true;
  bool _loadingOlder = false;
  bool _hasOlder = true;
  bool _sending = false;
  bool _approving = false;
  String? _error;
  bool _accessVerified = false;
  bool _mustVerifyAccess = true;
  int _accessGeneration = 0;

  void _invalidateAccess({bool revoked = false}) {
    if (!mounted) return;
    _accessGeneration++;
    setState(() {
      _accessVerified = false;
      _mustVerifyAccess = true;
      _messages.clear();
      _composer.clear();
      _hasOlder = false;
      // A page still loading belongs to the old access check; its result is
      // dropped, so it must not leave the older-messages loader stuck on.
      _loadingOlder = false;
      _loading = false;
      _error = revoked
          ? 'Guardian access is no longer available.'
          : 'Checking Guardian access…';
    });
  }

  @override
  void initState() {
    super.initState();
    _chat = widget.chat;
    WidgetsBinding.instance.addObserver(this);
    _transcriptRefresh = LiveRefreshController(refresh: _loadLatest)..start();
    _transcriptRefresh.setConnected(_service.isRealtimeConnected);
    _connectionSubscription =
        _service.connectionStream.listen(_transcriptRefresh.setConnected);
    _accessSubscription = _service.accessChanges.listen((_) {
      _invalidateAccess();
      _transcriptRefresh.request();
    });
    _scrollController.addListener(_maybeLoadOlder);
    _messageSubscription = _service.messageStream.listen((event) {
      if (event['match_id']?.toString() == _chat.matchId) {
        _transcriptRefresh.request();
      }
    });
    unawaited(_loadLatest());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transcriptRefresh.dispose();
    _connectionSubscription?.cancel();
    _accessSubscription?.cancel();
    _messageSubscription?.cancel();
    _scrollController
      ..removeListener(_maybeLoadOlder)
      ..dispose();
    _composer.dispose();
    super.dispose();
  }

  void _maybeLoadOlder() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 180 ||
        _loadingOlder ||
        !_hasOlder) {
      return;
    }
    unawaited(_loadOlder());
  }

  Future<void> _loadLatest() async {
    if (_latestInFlight) {
      _transcriptRefresh.request();
      return;
    }
    _latestInFlight = true;
    final generation = _accessGeneration;
    final actor = SupabaseService.currentUserId;
    try {
      var current = _chat;
      if (_mustVerifyAccess || !_accessVerified) {
        final dashboard = await _service.getDashboard();
        final refreshed = dashboard
            .where((item) => item.matchId == _chat.matchId)
            .firstOrNull;
        if (!mounted ||
            SupabaseService.currentUserId != actor ||
            generation != _accessGeneration) {
          return;
        }
        if (refreshed == null) {
          _invalidateAccess(revoked: true);
          _transcriptRefresh.stop();
          try {
            if (!await _service.hasLinkedWards()) _service.disposeRealtime();
          } catch (_) {
            // Authorization is already revoked; channel cleanup is best effort.
          }
          return;
        }
        current = refreshed;
      }
      final loaded = await _service.getTranscript(matchId: _chat.matchId);
      if (!mounted ||
          SupabaseService.currentUserId != actor ||
          generation != _accessGeneration) {
        return;
      }
      final existing = {for (final message in _messages) message.id: message};
      for (final message in loaded) {
        existing[message.id] = message;
      }
      final merged = existing.values.toList()
        ..sort((a, b) {
          final byTime = b.createdAt.compareTo(a.createdAt);
          return byTime != 0 ? byTime : b.id.compareTo(a.id);
        });
      setState(() {
        _chat = current;
        _accessVerified = true;
        _mustVerifyAccess = false;
        _messages
          ..clear()
          ..addAll(merged);
        _hasOlder = loaded.length == 50;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      _invalidateAccess(revoked: WaliModeService.isAccessDenied(error));
      setState(() {
        _loading = false;
        if (!WaliModeService.isAccessDenied(error)) {
          _error = 'Conversation could not be loaded. Please try again.';
        }
      });
    } finally {
      _latestInFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _invalidateAccess();
      _transcriptRefresh.start();
      _transcriptRefresh.request();
    } else {
      _transcriptRefresh.stop();
    }
  }

  Future<void> _loadOlder() async {
    if (_messages.isEmpty || !_accessVerified) return;
    final generation = _accessGeneration;
    setState(() => _loadingOlder = true);
    try {
      final loaded = await _service.getTranscript(
        matchId: _chat.matchId,
        before: _messages.last,
      );
      if (!mounted || generation != _accessGeneration) return;
      final known = _messages.map((message) => message.id).toSet();
      setState(() {
        _messages.addAll(loaded.where((message) => known.add(message.id)));
        _hasOlder = loaded.length == 50;
        _loadingOlder = false;
      });
    } catch (error) {
      if (WaliModeService.isAccessDenied(error)) {
        _invalidateAccess(revoked: true);
      }
      if (mounted && generation == _accessGeneration) {
        setState(() => _loadingOlder = false);
      }
    }
  }

  Future<void> _approve() async {
    if (_approving || !_accessVerified) return;
    final generation = _accessGeneration;
    setState(() => _approving = true);
    try {
      await _service.approveMatch(_chat.matchId);
      final dashboard = await _service.getDashboard();
      final refreshed =
          dashboard.where((item) => item.matchId == _chat.matchId).firstOrNull;
      if (!mounted || generation != _accessGeneration) return;
      if (refreshed == null) {
        _invalidateAccess(revoked: true);
        return;
      }
      setState(() {
        _chat = refreshed;
        _approving = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (WaliModeService.isAccessDenied(error)) {
        _invalidateAccess(revoked: true);
        return;
      }
      setState(() {
        _approving = false;
        _error = 'Approval could not be saved. Please try again.';
      });
    }
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty ||
        _sending ||
        !_accessVerified ||
        !_chat.canSendMessages) {
      return;
    }
    setState(() => _sending = true);
    try {
      if (_sendOperationId == null || _sendContent != text) {
        _sendOperationId = const Uuid().v4();
        _sendContent = text;
      }
      await _service.sendMessageAsGuardian(
        matchId: _chat.matchId,
        content: text,
        operationId: _sendOperationId!,
      );
      _sendOperationId = null;
      _sendContent = null;
      _composer.clear();
      await _loadLatest();
    } catch (error) {
      if (WaliModeService.isAccessDenied(error)) {
        _invalidateAccess(revoked: true);
        return;
      }
      if (mounted) {
        setState(() =>
            _error = 'Message could not be sent. Review it and try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: AppColors.obsidianNight,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UiText(
              _chat.otherPartyName,
              style: AppTypography.bodyMedium,
            ),
            UiText(
              !_accessVerified
                  ? 'Guardian access unconfirmed'
                  : '${_chat.wardName} · ${_chat.guardianMode == 'active' ? 'Active Guardian' : 'Read-only Guardian'}',
              style: AppTypography.caption.copyWith(
                color: AppColors.slateMist,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_accessVerified)
              _GuardianAccessBanner(
                chat: _chat,
                approving: _approving,
                onApprove: _chat.needsApproval ? _approve : null,
              ),
            if (_error != null)
              MaterialBanner(
                content: UiText(context.uiCopy(_error!)),
                backgroundColor: AppColors.errorRed.withValues(alpha: 0.14),
                actions: [
                  TextButton(
                    onPressed: _loadLatest,
                    child: UiText(context.uiCopy('Try again')),
                  ),
                ],
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: SilarahPulseLoader(),
                    )
                  : _messages.isEmpty
                      ? Center(
                          child: UiText(
                            context.uiCopy('No messages yet'),
                            style: AppTypography.body.copyWith(
                              color: AppColors.slateMist,
                            ),
                          ),
                        )
                      : ListView.builder(
                          reverse: true,
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                          itemCount: _messages.length + (_loadingOlder ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(
                                  child: SilarahActivityIndicator(),
                                ),
                              );
                            }
                            return _GuardianMessageBubble(
                              message: _messages[index],
                              wardName: _chat.wardName,
                              otherPartyName: _chat.otherPartyName,
                            );
                          },
                        ),
            ),
            if (_accessVerified && _chat.canSendMessages)
              _GuardianComposer(
                controller: _composer,
                sending: _sending,
                onSend: _send,
              ),
          ],
        ),
      ),
    );
  }
}

class _GuardianAccessBanner extends StatelessWidget {
  const _GuardianAccessBanner({
    required this.chat,
    required this.approving,
    this.onApprove,
  });

  final GuardianDashboardItem chat;
  final bool approving;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    final copy = chat.guardianMode == 'passive'
        ? 'Read-only oversight · messages cannot be sent from this account.'
        : !chat.guardianHasApproved
            ? 'Approve this match before messaging can begin.'
            : !chat.allGuardiansApproved
                ? 'Your approval is saved. Waiting for the other connected Guardian.'
                : 'Active oversight · Guardian messages are clearly labelled.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.goldGlow,
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: AppColors.champagneGold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: UiText(
              context.uiCopy(copy),
              style: AppTypography.caption.copyWith(
                color: AppColors.pearlWhite,
              ),
            ),
          ),
          if (onApprove != null)
            TextButton(
              onPressed: approving ? null : onApprove,
              child: approving
                  ? const SilarahActivityIndicator(
                      size: 18,
                    )
                  : UiText(context.uiCopy('Approve')),
            ),
        ],
      ),
    );
  }
}

class _GuardianMessageBubble extends StatelessWidget {
  const _GuardianMessageBubble({
    required this.message,
    required this.wardName,
    required this.otherPartyName,
  });

  final GuardianTranscriptMessage message;
  final String wardName;
  final String otherPartyName;

  @override
  Widget build(BuildContext context) {
    final alignRight = message.isFromWard;
    final sender = message.sentByGuardian
        ? context.uiCopyWith('You, as {name}', {'name': wardName})
        : alignRight
            ? wardName
            : otherPartyName;
    final time = TimeOfDay.fromDateTime(message.createdAt).format(context);
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
        decoration: BoxDecoration(
          color: alignRight ? AppColors.goldGlow : AppColors.surfaceGlass,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(alignRight ? 18 : 5),
            bottomRight: Radius.circular(alignRight ? 5 : 18),
          ),
          border: Border.all(
            color: message.sentByGuardian
                ? AppColors.champagneGold
                : AppColors.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UiText(
              sender,
              style: AppTypography.caption.copyWith(
                color: message.sentByGuardian
                    ? AppColors.champagneGold
                    : AppColors.slateMist,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            UiText(message.content, style: AppTypography.body),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: UiText(
                time,
                style: AppTypography.caption.copyWith(
                  color: AppColors.slateMist,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuardianComposer extends StatelessWidget {
  const _GuardianComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !sending,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              decoration: InputDecoration(
                hintText: context.uiCopy('Message as Guardian'),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SilarahActivityIndicator(
                    size: 18,
                  )
                : const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}

// Realtime Connection Indicator
class _RealtimeIndicator extends StatelessWidget {
  const _RealtimeIndicator({required this.isConnected});
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConnected ? AppColors.verifiedTeal : AppColors.slateMist,
            boxShadow: isConnected
                ? [
                    BoxShadow(
                      color: AppColors.verifiedTeal.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        UiText(
          isConnected ? 'Live' : 'Offline',
          style: AppTypography.caption.copyWith(
            color: isConnected ? AppColors.verifiedTeal : AppColors.slateMist,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// Chat Tile
class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.onTap,
    this.onApprove,
  });

  final GuardianDashboardItem chat;
  final VoidCallback onTap;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(
            color: chat.hasUnread
                ? AppColors.champagneGold.withValues(alpha: 0.5)
                : AppColors.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main chat info row
            Padding(
              padding: const EdgeInsets.all(AppDimensions.space16),
              child: Row(
                children: [
                  // Avatar placeholder or photo
                  _Avatar(
                    photoUrl: chat.otherPartyPhoto,
                    hasUnread: chat.hasUnread,
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  // Chat details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ward name & other party
                        Row(
                          children: [
                            UiText(
                              chat.wardName,
                              style: AppTypography.captionMedium.copyWith(
                                color: AppColors.champagneGold,
                                fontSize: 11,
                              ),
                            ),
                            UiText(
                              '  ↔  ',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.slateMist,
                                fontSize: 10,
                              ),
                            ),
                            Expanded(
                              child: UiText(
                                chat.otherPartyName,
                                style: AppTypography.captionMedium.copyWith(
                                  color: AppColors.pearlWhite,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Last message preview
                        UiText(
                          chat.lastMessage ?? 'No messages yet',
                          style: AppTypography.caption.copyWith(
                            color: chat.hasUnread
                                ? AppColors.pearlWhite
                                : AppColors.slateMist,
                            fontWeight: chat.hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space8),
                  // Right side: time + unread badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (chat.lastMessageAt != null)
                        UiText(
                          _formatTime(context, chat.lastMessageAt!),
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            color: chat.hasUnread
                                ? AppColors.champagneGold
                                : AppColors.slateMist,
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (chat.hasUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.champagneGold,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: UiText(
                            '${chat.unreadCount}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.obsidianNight,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Guardian approval banner (active mode, pending matches)
            if (onApprove != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space16,
                  vertical: AppDimensions.space10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.goldGlow,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppDimensions.radiusCard),
                    bottomRight: Radius.circular(AppDimensions.radiusCard),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.champagneGold,
                      size: 16,
                    ),
                    const SizedBox(width: AppDimensions.space8),
                    Expanded(
                      child: UiText(
                        context.uiCopy('Awaiting your approval'),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.champagneGold,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onApprove,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.space12,
                          vertical: AppDimensions.space4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.champagneGold,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusChip),
                        ),
                        child: UiText(
                          context.uiCopy('Approve'),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.obsidianNight,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Mode badge
            Padding(
              padding: const EdgeInsets.only(
                left: AppDimensions.space16,
                right: AppDimensions.space16,
                bottom: AppDimensions.space10,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: chat.guardianMode == 'active'
                          ? AppColors.verifiedTeal.withValues(alpha: 0.15)
                          : AppColors.surfaceGlassHover,
                      border: Border.all(
                        color: chat.guardianMode == 'active'
                            ? AppColors.verifiedTeal.withValues(alpha: 0.5)
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: UiText(
                      chat.guardianMode == 'active' ? 'ACTIVE' : 'VIEWING',
                      style: AppTypography.caption.copyWith(
                        fontSize: 9,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                        color: chat.guardianMode == 'active'
                            ? AppColors.verifiedTeal
                            : AppColors.slateMist,
                      ),
                    ),
                  ),
                  const Spacer(),
                  UiText(
                    chat.matchStatus.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      fontSize: 9,
                      color: AppColors.slateMist,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(BuildContext context, DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return context.uiCopy('now');
    if (diff.inMinutes < 60) return context.uiMinutesShort(diff.inMinutes);
    if (diff.inHours < 24) return context.uiHoursShort(diff.inHours);
    if (diff.inDays < 7) return context.uiDaysShort(diff.inDays);
    return '${time.day}/${time.month}';
  }
}

// Avatar
class _Avatar extends StatelessWidget {
  const _Avatar({this.photoUrl, required this.hasUnread});
  final String? photoUrl;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: hasUnread ? AppColors.champagneGold : AppColors.cardBorder,
          width: hasUnread ? 2 : 1,
        ),
        color: AppColors.surfaceGlassHover,
      ),
      child: photoUrl != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: photoUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 144,
                maxWidthDiskCache: 192,
                errorWidget: (_, __, ___) => Icon(
                  Icons.person,
                  color: AppColors.slateMist,
                  size: 24,
                ),
              ),
            )
          : Icon(Icons.person, color: AppColors.slateMist, size: 24),
    );
  }
}

// Empty Dashboard
class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldBorder, width: 2),
                color: AppColors.goldGlow,
              ),
              child: Icon(
                Icons.shield_outlined,
                color: AppColors.champagneGold,
                size: 36,
              ),
            ),
            const SizedBox(height: AppDimensions.space24),
            UiText(
              context.uiCopy('No Active Conversations'),
              style: AppTypography.screenTitle.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space12),
            UiText(
              context.uiCopy(
                'Conversations appear here when a member connects you as Guardian and has an active match.',
              ),
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
            TextButton(
                onPressed: onRefresh, child: UiText(context.uiCopy('Refresh'))),
          ],
        ),
      ),
    );
  }
}

// Dashboard Shimmer
class _DashboardShimmer extends StatelessWidget {
  const _DashboardShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.space16),
      itemCount: 4,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.space10),
      itemBuilder: (_, __) => Container(
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceGlassHover,
                ),
              ),
              const SizedBox(width: AppDimensions.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGlassHover,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 200,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGlassHover,
                        borderRadius: BorderRadius.circular(4),
                      ),
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
