// SILARAH — Chat Cubit (RPC-backed production flow)
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../services/my_account_snapshot.dart';
import '../../services/supabase_service.dart';
import '../../services/relationship_revision_service.dart';
import '../../services/profile_photo_service.dart';
import '../../services/live_refresh_controller.dart';
import 'chat_state.dart';
import 'chat_message_page.dart';

enum ChatAccessReason {
  allowed,
  readOnly,
  subscriptionRequired,
  guardianApprovalRequired,
  suspended,
  accountRestricted,
  closed,
  notFound,
  memberUnavailableReadOnly,
  unavailable,
}

class ChatAccessDecision {
  const ChatAccessDecision(this.reason);

  final ChatAccessReason reason;
  bool get allowed =>
      reason == ChatAccessReason.allowed ||
      reason == ChatAccessReason.readOnly ||
      reason == ChatAccessReason.memberUnavailableReadOnly;
  bool get readOnly =>
      reason == ChatAccessReason.readOnly ||
      reason == ChatAccessReason.memberUnavailableReadOnly;
  bool get requiresSubscription =>
      reason == ChatAccessReason.subscriptionRequired;
}

class ChatCubit extends Cubit<ChatState> {
  ChatCubit() : super(const ChatState());

  static const int _messagePageSize = 30;

  int _sessionEpoch = 0;
  int _loadVersion = 0;
  bool _inboxLoadInFlight = false;
  Completer<void>? _inboxLoadCompletion;
  DateTime? _lastInboxLoadedAt;
  static const _inboxFreshness = Duration(minutes: 2);
  static const _revisionCheckFreshness = Duration(seconds: 90);
  String? _loadedRelationshipRevision;
  DateTime? _lastRelationshipRevisionCheckAt;
  final Set<String> _messageLoadsInFlight = {};
  final Set<String> _pendingMessageReloads = {};
  final Set<String> _exhaustedMessagePages = {};
  final Map<String, String> _latestFetchedMessageIds = {};
  final Map<String, String> _closureOperationIds = {};

  // Responsive enough for a live typing indicator while reducing Realtime
  // broadcast volume by more than half versus the previous 1.4-second loop.
  static const Duration _typingRefreshInterval = Duration(milliseconds: 3000);
  static const Duration _localTypingIdleTimeout = Duration(milliseconds: 2200);
  static const Duration _remoteTypingExpiry = Duration(milliseconds: 7000);

  RealtimeChannel? _activeChatSubscription;
  String? _realtimeUserId;
  String? _activeConversationId;
  String? _loadedUserId;
  bool _reloadInboxAfterCurrentLoad = false;
  Timer? _localTypingIdleTimer;
  Timer? _remoteTypingExpiryTimer;
  Timer? _inboxReconcileTimer;
  DateTime? _lastTypingBroadcastAt;
  bool _localTypingActive = false;
  bool _isForeground = true;
  LiveRefreshController? _liveRecovery;

  bool get _isRealMode => SupabaseService.isInitialized;

  /// Asks Supabase for the authoritative access decision. Callers must never
  /// infer messaging access from cached gender or RevenueCat state.
  Future<ChatAccessDecision> checkChatAccess(String matchId) async {
    if (!_isRealMode || matchId.isEmpty) {
      return const ChatAccessDecision(ChatAccessReason.unavailable);
    }
    try {
      final response = await SupabaseService.client.rpc(
        'can_open_chat',
        params: {'p_match_id': matchId},
      );
      final rows = response as List<dynamic>;
      if (rows.isEmpty) {
        return const ChatAccessDecision(ChatAccessReason.unavailable);
      }
      final row = Map<String, dynamic>.from(rows.first as Map);
      if (row['allowed'] == true &&
          row['reason']?.toString() == 'member_unavailable_read_only') {
        return const ChatAccessDecision(
          ChatAccessReason.memberUnavailableReadOnly,
        );
      }
      if (row['allowed'] == true && row['reason']?.toString() == 'read_only') {
        return const ChatAccessDecision(ChatAccessReason.readOnly);
      }
      if (row['allowed'] == true) {
        return const ChatAccessDecision(ChatAccessReason.allowed);
      }
      return ChatAccessDecision(switch (row['reason']?.toString()) {
        'subscription_required' => ChatAccessReason.subscriptionRequired,
        'guardian_approval_required' =>
          ChatAccessReason.guardianApprovalRequired,
        'suspended' => ChatAccessReason.suspended,
        'account_restricted' => ChatAccessReason.accountRestricted,
        'closed' => ChatAccessReason.closed,
        'not_found' => ChatAccessReason.notFound,
        _ => ChatAccessReason.unavailable,
      });
    } catch (error) {
      debugPrint('ChatCubit: access check failed: $error');
      return const ChatAccessDecision(ChatAccessReason.unavailable);
    }
  }

  Future<void> loadConversations({
    bool showLoading = true,
    bool force = false,
  }) async {
    if (isClosed) return;
    final me = SupabaseService.currentUserId;
    if (_inboxLoadInFlight) {
      if (force) _reloadInboxAfterCurrentLoad = true;
      // Opening a chat must wait for the existing inbox fetch; returning early
      // here makes a valid deep link look like an absent conversation.
      await _inboxLoadCompletion?.future;
      return;
    }
    final lastLoadedAt = _lastInboxLoadedAt;
    if (!force &&
        me != null &&
        _loadedUserId == me &&
        lastLoadedAt != null &&
        DateTime.now().difference(lastLoadedAt) < _inboxFreshness) {
      return;
    }
    _inboxLoadInFlight = true;
    final completion = Completer<void>();
    _inboxLoadCompletion = completion;
    final loadVersion = ++_loadVersion;
    if (!_isRealMode) {
      emit(state.copyWith(conversations: const [], isLoading: false));
      _inboxLoadInFlight = false;
      _inboxLoadCompletion = null;
      completion.complete();
      return;
    }

    if (showLoading) {
      emit(state.copyWith(isLoading: true));
    }
    try {
      final me = SupabaseService.currentUserId;
      if (me == null) {
        if (_isCurrentLoad(loadVersion)) {
          clear();
        }
        return;
      }

      // The suspension date is display-only here: chat RPCs enforce it on
      // the server, so the shared account snapshot is fresh enough.
      final results = await Future.wait<dynamic>([
        MyAccountSnapshot.instance.user(me),
        SupabaseService.client.rpc(
          'get_chat_inbox',
          params: {'p_limit': 50},
        ),
        RelationshipRevisionService.readToken(),
      ]);

      if (!_isCurrentLoad(loadVersion) || SupabaseService.currentUserId != me) {
        return;
      }

      final userRow = results[0] as Map<String, dynamic>?;
      final inboxRows = _asRows(results[1]);
      final suspendedUntil = _parseDate(userRow?['messaging_suspended_until']);
      final photoUrls = await _loadConversationPhotoUrls(inboxRows);
      if (!_isCurrentLoad(loadVersion) || SupabaseService.currentUserId != me) {
        return;
      }
      final loaded = inboxRows
          .map((row) => _conversationFromInbox(row, me, photoUrls))
          .toList();

      emit(state.copyWith(
        conversations: _mergeLoadedConversations(state.conversations, loaded),
        isLoading: false,
        messagingSuspendedUntil: suspendedUntil,
      ));
      _loadedUserId = me;
      _lastInboxLoadedAt = DateTime.now();
      _loadedRelationshipRevision = results[2] as String?;
      _lastRelationshipRevisionCheckAt = DateTime.now();
    } catch (e) {
      debugPrint('ChatCubit: Error loading conversations: $e');
      if (_isCurrentLoad(loadVersion)) emit(state.copyWith(isLoading: false));
    } finally {
      if (!completion.isCompleted) completion.complete();
      // An old account's completion must never unlock a new account's load.
      if (identical(_inboxLoadCompletion, completion)) {
        _inboxLoadCompletion = null;
        _inboxLoadInFlight = false;
        if (_reloadInboxAfterCurrentLoad &&
            !isClosed &&
            SupabaseService.currentUserId != null) {
          _reloadInboxAfterCurrentLoad = false;
          unawaited(loadConversations(showLoading: false, force: true));
        }
      }
    }
  }

  /// Uses the relationship revision to detect match closures/status changes.
  /// New-message FCM, app resume and the two-minute freshness window recover
  /// inbox state without keeping a Realtime connection open for every member.
  Future<void> refreshIfChanged({bool forceCheck = false}) async {
    final me = SupabaseService.currentUserId;
    if (me == null || _inboxLoadInFlight) return;

    final loadedAt = _lastInboxLoadedAt;
    if (_loadedUserId != me || loadedAt == null) {
      await loadConversations(showLoading: false);
      return;
    }
    if (DateTime.now().difference(loadedAt) >= _inboxFreshness) {
      await loadConversations(showLoading: false);
      return;
    }

    final checkedAt = _lastRelationshipRevisionCheckAt;
    if (!forceCheck &&
        checkedAt != null &&
        DateTime.now().difference(checkedAt) < _revisionCheckFreshness) {
      return;
    }

    _lastRelationshipRevisionCheckAt = DateTime.now();
    final serverRevision = await RelationshipRevisionService.readToken();
    if (serverRevision == null || isClosed) return;
    if (_loadedRelationshipRevision == serverRevision) return;
    await loadConversations(showLoading: false, force: true);
  }

  /// Entitlement is not part of the relationship revision token. Force one
  /// authoritative inbox read so newly unlocked chats open immediately and
  /// expired/revoked chats redact any history retained in memory.
  Future<void> refreshForEntitlementChange() async {
    _lastInboxLoadedAt = null;
    await loadConversations(showLoading: false, force: true);
  }

  /// Coalesces notification and FCM recovery signals into one authoritative
  /// inbox refresh. If a chat is open, its bounded message page is refreshed
  /// too, so message delivery recovers even when Realtime is unavailable.
  void scheduleInboxReconciliation() {
    if (_inboxReconcileTimer != null) return;
    _inboxReconcileTimer = Timer(const Duration(milliseconds: 800), () {
      _inboxReconcileTimer = null;
      if (!isClosed) {
        unawaited(_reconcileInboxAndActiveConversation());
      }
    });
  }

  /// True when a push deep link points at the conversation already on
  /// screen, so the in-app banner would only repeat what the member sees.
  bool isViewingConversationLink(String? deepLink) {
    final active = _activeConversationId;
    if (active == null || !_isForeground || deepLink == null) return false;
    final conversation = _findConversation(active);
    final ids = {active, conversation?.matchId}.whereType<String>();
    return ids.any((id) => deepLink.trim() == 'silarah://chat/$id');
  }

  Future<void> _reconcileInboxAndActiveConversation() async {
    final activeConversationId = _activeConversationId;
    await loadConversations(showLoading: false, force: true);
    if (isClosed || !_isForeground || activeConversationId == null) return;
    if (_activeConversationId != activeConversationId) return;
    await loadMessages(activeConversationId);
    if (!isClosed && _activeConversationId == activeConversationId) {
      await markRead(activeConversationId);
    }
  }

  Future<void> loadMessages(
    String conversationId, {
    bool older = false,
    bool activate = false,
  }) async {
    if (isClosed || !_isRealMode) return;
    if (activate) _subscribeToActiveChat(conversationId);
    if (_messageLoadsInFlight.contains(conversationId)) {
      if (!older) _pendingMessageReloads.add(conversationId);
      return;
    }
    if (older && _exhaustedMessagePages.contains(conversationId)) return;

    final me = SupabaseService.currentUserId;
    final epoch = _sessionEpoch;
    if (me == null) return;
    _messageLoadsInFlight.add(conversationId);
    try {
      var conv = _findConversation(conversationId);
      if (conv == null) {
        await loadConversations(force: true);
        if (isClosed ||
            epoch != _sessionEpoch ||
            SupabaseService.currentUserId != me) {
          return;
        }
        conv = _findConversation(conversationId);
        if (conv == null) return;
      }
      final oldest = oldestPersistedChatMessage(conv.messages);
      if (older && oldest == null) return;
      final before = older ? oldest!.sentAt.toUtc().toIso8601String() : null;
      final beforeId = older ? oldest!.id : null;
      final rows = _asRows(await SupabaseService.client.rpc(
        'get_chat_messages_v2',
        params: {
          'p_match_id': conversationId,
          'p_limit': _messagePageSize,
          if (before != null) 'p_before_created_at': before,
          if (beforeId != null) 'p_before_id': beforeId,
        },
      ));

      if (isClosed ||
          epoch != _sessionEpoch ||
          SupabaseService.currentUserId != me) {
        return;
      }
      if (_loadedUserId != null && _loadedUserId != me) return;
      final messages = rows.map((row) => _messageFromRow(row, me)).toList();
      final updated = state.conversations.map((c) {
        if (c.id != conversationId) return c;
        final page = reconcileChatMessagePage(
          current: c.messages,
          incoming: messages,
          older: older,
          wasExhausted: _exhaustedMessagePages.contains(conversationId),
          pageSize: _messagePageSize,
          lastFetchedMessageId: _latestFetchedMessageIds[conversationId],
        );
        if (page.olderExhausted) {
          _exhaustedMessagePages.add(conversationId);
        } else {
          _exhaustedMessagePages.remove(conversationId);
        }
        return c.copyWith(messages: page.messages);
      }).toList();
      if (!older) {
        if (messages.isEmpty) {
          _latestFetchedMessageIds.remove(conversationId);
        } else {
          _latestFetchedMessageIds[conversationId] =
              mergeChatMessagesById(const [], messages).last.id;
        }
      }
      emit(state.copyWith(conversations: updated));
    } catch (e) {
      debugPrint('ChatCubit: Error loading messages: $e');
    } finally {
      if (epoch == _sessionEpoch) {
        _messageLoadsInFlight.remove(conversationId);
        if (_pendingMessageReloads.remove(conversationId) &&
            !isClosed &&
            _activeConversationId == conversationId &&
            _isForeground) {
          _liveRecovery?.request();
        }
      }
    }
  }

  Future<String> openOrCreateConversation(
    String otherUserId,
    String matchName,
    String lastInitial,
  ) async {
    final active = state.activeConversationWith(otherUserId);
    if (active != null) return active.id;

    if (!_isRealMode) return '';
    // A cached closed cycle is not proof that no active rematch exists. Force
    // a bounded inbox reconciliation before resolving the current match. The
    // first pass can join an in-flight load that predates a just-accepted
    // match, so a second fresh pass runs if the match is still missing. A
    // slow phone must get the "still being prepared" message, never an
    // uncaught timeout that leaves the button silently doing nothing.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await loadConversations(force: true)
            .timeout(const Duration(seconds: 12));
      } on TimeoutException {
        debugPrint('ChatCubit: inbox reconciliation timed out');
        return '';
      }
      final found = state.activeConversationWith(otherUserId);
      if (found != null) return found.id;
    }
    return '';
  }

  Future<bool> sendMessage(String conversationId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSuspended) return false;

    final conv = _findConversation(conversationId);
    if (conv == null || conv.isMatchClosed || !_isRealMode) return false;

    final operationId = const Uuid().v4();
    final tempMsgId = 'local_$operationId';
    final localMsg = ChatMessage(
      id: tempMsgId,
      operationId: operationId,
      text: trimmed,
      sentAt: DateTime.now(),
      isMe: true,
      status: MessageStatus.queued,
    );
    _appendMessage(conversationId, localMsg);

    return _persistMessage(conversationId, localMsg);
  }

  /// Retries the same local failed bubble instead of creating duplicates.
  Future<bool> retryMessage(String conversationId, String messageId) async {
    final conv = _findConversation(conversationId);
    if (conv == null || conv.isMatchClosed || state.isSuspended) return false;
    final failed = conv.messages
        .where((message) =>
            message.id == messageId && message.status == MessageStatus.failed)
        .firstOrNull;
    if (failed == null) return false;
    _updateMessageStatus(conversationId, messageId, MessageStatus.queued);
    return _persistMessage(
      conversationId,
      failed.copyWith(status: MessageStatus.queued),
    );
  }

  Future<bool> _persistMessage(
    String conversationId,
    ChatMessage localMessage,
  ) async {
    final localId = localMessage.id;
    final epoch = _sessionEpoch;
    final actor = SupabaseService.currentUserId;
    if (actor == null || localMessage.operationId == null) return false;

    try {
      final rows = _asRows(await SupabaseService.client.rpc(
        'send_chat_message_idempotent',
        params: {
          'p_match_id': conversationId,
          'p_content': localMessage.text,
          'p_operation_id': localMessage.operationId,
        },
      ));

      if (isClosed ||
          epoch != _sessionEpoch ||
          SupabaseService.currentUserId != actor) {
        return false;
      }

      final row = rows.isNotEmpty ? rows.first : const <String, dynamic>{};
      final realId = row['message_id']?.toString();
      final createdAt = _parseDate(row['created_at']) ?? DateTime.now();
      if (realId == null) {
        _updateMessageStatus(conversationId, localId, MessageStatus.failed);
        return false;
      }

      _replaceQueuedMessage(
        conversationId,
        localId,
        ChatMessage(
          id: realId,
          text: localMessage.text,
          sentAt: createdAt,
          isMe: true,
          status: MessageStatus.sent,
        ),
      );
      if (_messageLoadsInFlight.contains(conversationId)) {
        _pendingMessageReloads.add(conversationId);
      }
      return true;
    } catch (e) {
      if (isClosed ||
          epoch != _sessionEpoch ||
          SupabaseService.currentUserId != actor) {
        return false;
      }
      debugPrint('ChatCubit: Error sending message: $e');
      _updateMessageStatus(conversationId, localId, MessageStatus.failed);
      if (_isSafetyBlock(e)) {
        unawaited(loadConversations(force: true));
      }
      return false;
    }
  }

  Future<void> markRead(String conversationId) async {
    if (!_isRealMode ||
        !_isForeground ||
        !_conversationExists(conversationId)) {
      return;
    }
    final epoch = _sessionEpoch;
    final actor = SupabaseService.currentUserId;
    try {
      await SupabaseService.client.rpc(
        'mark_chat_read',
        params: {'p_match_id': conversationId},
      );
      if (isClosed ||
          epoch != _sessionEpoch ||
          SupabaseService.currentUserId != actor) {
        return;
      }
      final updated = state.conversations.map((c) {
        if (c.id != conversationId) return c;
        final messages = c.messages.map((m) {
          if (m.isMe) return m;
          return m.copyWith(status: MessageStatus.read);
        }).toList();
        return c.copyWith(messages: messages, unreadCount: 0);
      }).toList();
      emit(state.copyWith(conversations: updated));
    } catch (e) {
      debugPrint('ChatCubit: Error marking read: $e');
    }
  }

  Future<void> reportMessage(
    String conversationId,
    String messageId,
    String reason, {
    String? description,
  }) async {
    if (!_isRealMode || !_conversationExists(conversationId)) return;
    await SupabaseService.client.rpc(
      'report_chat_message',
      params: {
        'p_message_id': messageId,
        'p_reason': reason,
        'p_description': description,
      },
    );
  }

  Future<void> blockUser(String conversationId, {String? reason}) async {
    if (!_isRealMode) return;
    final conv = _findConversation(conversationId);
    final otherUserId = conv?.otherUserId;
    if (conv == null || otherUserId == null) return;

    await SupabaseService.client.rpc(
      'block_chat_user',
      params: {
        'p_user_id': otherUserId,
        'p_reason': reason,
      },
    );

    final updated = state.conversations.map((c) {
      if (c.id != conversationId) return c;
      return c.copyWith(
        isMatchClosed: true,
        unreadCount: 0,
        closureMessage: 'This member has been blocked.',
      );
    }).toList();
    emit(state.copyWith(conversations: updated));
  }

  Future<bool> closeMatch(String conversationId, String message) async {
    if (!_isRealMode) return false;

    final conv = _findConversation(conversationId);
    if (conv == null || conv.isMatchClosed) return false;

    try {
      final operationId = _closureOperationIds.putIfAbsent(
        conversationId,
        () => const Uuid().v4(),
      );
      final response = await SupabaseService.client.rpc(
        'send_and_close_match',
        params: {
          'p_match_id': conversationId,
          'p_closure_reason': message,
          'p_operation_id': operationId,
        },
      );
      if (response is! Map || response['closed'] != true) return false;
      _closureOperationIds.remove(conversationId);
      await loadConversations(force: true);
      return true;
    } catch (e) {
      debugPrint('ChatCubit: Error closing match: $e');
      return false;
    }
  }

  /// Removes a finished conversation from this member's inbox only. The
  /// server retains the other participant's copy and moderation evidence.
  Future<bool> hideConversation(String conversationId) async {
    if (!_isRealMode) return false;
    final conv = _findConversation(conversationId);
    if (conv == null || !conv.isMatchClosed) return false;

    try {
      final hidden = await SupabaseService.client.rpc(
        'hide_chat_conversation',
        params: {'p_match_id': conversationId},
      );
      if (hidden != true || isClosed) return false;
      emit(state.copyWith(
        conversations: state.conversations
            .where((item) => item.id != conversationId)
            .toList(growable: false),
      ));
      if (_activeConversationId == conversationId) _disposeRealtime();
      return true;
    } catch (error) {
      debugPrint('ChatCubit: Error hiding conversation: $error');
      return false;
    }
  }

  void toggleTimestamp(String conversationId, String messageId) {
    final updated = state.conversations.map((c) {
      if (c.id != conversationId) return c;
      final msgs = c.messages.map((m) {
        if (m.id != messageId) return m;
        return m.copyWith(isTimestampVisible: !m.isTimestampVisible);
      }).toList();
      return c.copyWith(messages: msgs);
    }).toList();
    emit(state.copyWith(conversations: updated));
  }

  /// Publishes ephemeral typing presence to the currently open private chat.
  /// Keystrokes and message content are never included in this payload.
  void updateTyping(String conversationId, {required bool isTyping}) {
    if (_activeConversationId != conversationId ||
        _activeChatSubscription == null ||
        SupabaseService.currentUserId == null) {
      return;
    }

    _localTypingIdleTimer?.cancel();
    if (!isTyping) {
      if (_localTypingActive) _sendTypingBroadcast(false);
      return;
    }

    final now = DateTime.now();
    final shouldRefresh = !_localTypingActive ||
        _lastTypingBroadcastAt == null ||
        now.difference(_lastTypingBroadcastAt!) >= _typingRefreshInterval;
    if (shouldRefresh) _sendTypingBroadcast(true);

    _localTypingIdleTimer = Timer(
      _localTypingIdleTimeout,
      () => _sendTypingBroadcast(false),
    );
  }

  void leaveConversation(String conversationId) {
    if (_activeConversationId != conversationId) return;
    _disposeRealtime();
  }

  void clear() {
    _sessionEpoch++;
    _loadVersion++;
    _inboxReconcileTimer?.cancel();
    _inboxReconcileTimer = null;
    _messageLoadsInFlight.clear();
    _pendingMessageReloads.clear();
    _exhaustedMessagePages.clear();
    _latestFetchedMessageIds.clear();
    _closureOperationIds.clear();
    _loadedUserId = null;
    _lastInboxLoadedAt = null;
    _loadedRelationshipRevision = null;
    _lastRelationshipRevisionCheckAt = null;
    final inboxCompletion = _inboxLoadCompletion;
    _inboxLoadCompletion = null;
    if (inboxCompletion != null && !inboxCompletion.isCompleted) {
      inboxCompletion.complete();
    }
    _inboxLoadInFlight = false;
    _reloadInboxAfterCurrentLoad = false;
    _disposeRealtime();
    if (!isClosed) emit(const ChatState());
  }

  void _subscribeToActiveChat(String conversationId) {
    final me = SupabaseService.currentUserId;
    if (me == null) return;
    if (_realtimeUserId == me &&
        _activeConversationId == conversationId &&
        _activeChatSubscription != null) {
      return;
    }

    _disposeRealtime();
    _realtimeUserId = me;
    _activeConversationId = conversationId;
    // Authorization may finish after the app has backgrounded. Remember the
    // visible route, but do not open a fresh socket until foreground resume.
    if (!_isForeground) return;
    final recovery = LiveRefreshController(refresh: () async {
      if (isClosed ||
          !_isForeground ||
          _activeConversationId != conversationId ||
          SupabaseService.currentUserId != me) {
        return;
      }
      await loadMessages(conversationId);
      if (!isClosed &&
          _isForeground &&
          _activeConversationId == conversationId &&
          SupabaseService.currentUserId == me) {
        await markRead(conversationId);
      }
    });
    _liveRecovery = recovery;
    if (_isForeground) recovery.start();

    // Scale guard: realtime is scoped to the currently open chat only.
    // Inbox state is refreshed through get_chat_inbox RPC and background
    // notifications, avoiding broad per-user message/match subscriptions.
    _activeChatSubscription = SupabaseService.client
        .channel(
          'chat:$conversationId',
          opts: const RealtimeChannelConfig(private: true, ack: true),
        )
        .onBroadcast(
          event: 'typing',
          callback: (payload) =>
              _handleTypingBroadcast(payload, conversationId, me),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: conversationId,
          ),
          callback: (payload) => _handleMessageRealtime(payload, me),
        )
        .subscribe((status, error) {
      if (!identical(_liveRecovery, recovery) ||
          SupabaseService.currentUserId != me) {
        return;
      }
      recovery.setConnected(status == RealtimeSubscribeStatus.subscribed);
    });
  }

  void setForeground(bool foreground) {
    _isForeground = foreground;
    if (foreground) {
      final conversationId = _activeConversationId;
      if (conversationId != null && _activeChatSubscription == null) {
        _subscribeToActiveChat(conversationId);
      }
      _liveRecovery?.start();
      _liveRecovery?.request();
    } else {
      _liveRecovery?.stop();
    }
  }

  void _sendTypingBroadcast(bool isTyping) {
    final channel = _activeChatSubscription;
    final conversationId = _activeConversationId;
    final me = SupabaseService.currentUserId;
    if (channel == null || conversationId == null || me == null) return;
    if (!isTyping && !_localTypingActive) return;

    _localTypingActive = isTyping;
    _lastTypingBroadcastAt = DateTime.now();
    unawaited(
      channel.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'user_id': me,
          'is_typing': isTyping,
          'sent_at': _lastTypingBroadcastAt!.toUtc().toIso8601String(),
        },
      ).then((response) {
        if (response != ChannelResponse.ok) {
          debugPrint('ChatCubit: typing broadcast was not acknowledged');
        }
      }).catchError((Object error) {
        debugPrint('ChatCubit: typing broadcast failed: $error');
      }),
    );
  }

  void _handleTypingBroadcast(
    Map<String, dynamic> payload,
    String conversationId,
    String me,
  ) {
    if (isClosed ||
        !_isForeground ||
        _activeConversationId != conversationId ||
        SupabaseService.currentUserId != me) {
      return;
    }
    // Realtime client versions may expose the broadcast body directly or
    // under `payload`; accepting both keeps presence compatible across SDK
    // upgrades without weakening the participant-only channel policy.
    final eventPayload = payload['payload'] is Map
        ? Map<String, dynamic>.from(payload['payload'] as Map)
        : payload;
    if (eventPayload['user_id'] == me) return;
    final isTyping = eventPayload['is_typing'] == true;
    _remoteTypingExpiryTimer?.cancel();
    _setRemoteTyping(conversationId, isTyping);
    if (isTyping) {
      _remoteTypingExpiryTimer = Timer(
        _remoteTypingExpiry,
        () => _setRemoteTyping(conversationId, false),
      );
    }
  }

  void _setRemoteTyping(String conversationId, bool isTyping) {
    if (isClosed) return;
    final next = Set<String>.from(state.typingConversationIds);
    isTyping ? next.add(conversationId) : next.remove(conversationId);
    if (setEquals(next, state.typingConversationIds)) return;
    emit(state.copyWith(typingConversationIds: next));
  }

  void _handleMessageRealtime(PostgresChangePayload payload, String me) {
    if (isClosed || !_isForeground || SupabaseService.currentUserId != me) {
      return;
    }
    final record = payload.newRecord;
    final matchId = record['match_id'] as String?;
    if (matchId == null || matchId != _activeConversationId) {
      return;
    }

    if (payload.eventType == PostgresChangeEvent.insert) {
      // The HTTP page may predate this event. Arrange a trailing read rather
      // than losing the event when a discontinuous history window is reset.
      if (_messageLoadsInFlight.contains(matchId)) {
        _pendingMessageReloads.add(matchId);
      }
      _appendMessage(
        matchId,
        _messageFromRow(record, me),
        incrementUnread: false,
      );
      if (record['receiver_id'] == me) {
        unawaited(markRead(matchId));
      }
      return;
    }

    if (payload.eventType == PostgresChangeEvent.update) {
      final messageId = record['id'] as String?;
      if (messageId == null) return;
      final status = _messageStatusFromRow(record, record['sender_id'] == me);
      _updateMessageStatus(matchId, messageId, status);
      return;
    }

    unawaited(loadMessages(matchId));
  }

  void _disposeRealtime() {
    _liveRecovery?.dispose();
    _liveRecovery = null;
    if (_localTypingActive) _sendTypingBroadcast(false);
    _localTypingIdleTimer?.cancel();
    _remoteTypingExpiryTimer?.cancel();
    _localTypingIdleTimer = null;
    _remoteTypingExpiryTimer = null;
    _localTypingActive = false;
    _lastTypingBroadcastAt = null;
    if (_activeConversationId != null) {
      _setRemoteTyping(_activeConversationId!, false);
    }
    final channel = _activeChatSubscription;
    // removeChannel also disconnects the transport when this was its last
    // channel. unsubscribe alone leaves an idle quota-consuming socket open.
    if (channel != null) {
      unawaited(SupabaseService.client
          .removeChannel(channel)
          .catchError((Object _) => 'error'));
    }
    _activeChatSubscription = null;
    _realtimeUserId = null;
    _activeConversationId = null;
  }

  @override
  Future<void> close() {
    _inboxReconcileTimer?.cancel();
    _disposeRealtime();
    return super.close();
  }

  Conversation _conversationFromInbox(
    Map<String, dynamic> row,
    String me,
    Map<String, String> photoUrls,
  ) {
    final lastMessageId = row['last_message_id']?.toString();
    final lastMessage = lastMessageId == null
        ? null
        : ChatMessage(
            id: lastMessageId,
            text: row['last_message_content'] as String? ?? '',
            sentAt:
                _parseDate(row['last_message_created_at']) ?? DateTime.now(),
            isMe: row['last_message_sender_id'] == me,
            status: row['last_message_read_at'] != null
                ? MessageStatus.read
                : (row['last_message_sender_id'] == me
                    ? MessageStatus.sent
                    : MessageStatus.delivered),
          );

    final status = row['match_status'] as String? ?? 'active';
    final matchClosed = status == 'closed' ||
        status == 'expired' ||
        status == 'blocked' ||
        status == 'reported' ||
        row['member_unavailable'] == true;
    return Conversation(
      id: row['match_id'].toString(),
      matchName: row['other_first_name'] as String? ?? 'Member',
      matchLastInitial: row['other_last_initial'] as String? ?? '',
      messages: lastMessage == null ? const [] : [lastMessage],
      // A closed or blocked conversation cannot continue, so its leftover
      // unread messages no longer count towards badges.
      unreadCount:
          matchClosed ? 0 : (row['unread_count'] as num?)?.toInt() ?? 0,
      matchId: row['match_id'].toString(),
      otherUserId: row['other_user_id']?.toString(),
      photoUrl: photoUrls[row['other_user_id']?.toString()],
      isMatchClosed: matchClosed,
      memberUnavailable: row['member_unavailable'] == true,
      closureMessage: row['closure_reason'] as String?,
      closedByMe: row['closed_by'] == null ? null : row['closed_by'] == me,
      contentLocked: row['content_locked'] == true,
    );
  }

  Future<Map<String, String>> _loadConversationPhotoUrls(
    List<Map<String, dynamic>> inboxRows,
  ) async {
    final ownerIds = inboxRows
        .where((row) => row['member_unavailable'] != true)
        .map((row) => row['other_user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ownerIds.isEmpty) return const {};
    try {
      return await ProfilePhotoService.instance.getAuthorizedPhotoUrls(
        ownerUserIds: ownerIds,
      );
    } catch (error) {
      // A photo must never prevent a conversation from opening.
      debugPrint('ChatCubit: Error loading conversation photos: $error');
      return const {};
    }
  }

  ChatMessage _messageFromRow(Map<String, dynamic> row, String me) {
    final isMe = row['sender_id'] == me;
    return ChatMessage(
      id: row['id'].toString(),
      text: row['content'] as String? ?? '',
      sentAt: _parseDate(row['created_at']) ?? DateTime.now(),
      isMe: isMe,
      status: _messageStatusFromRow(row, isMe),
      sentByGuardian: row['sent_by_guardian'] == true,
    );
  }

  MessageStatus _messageStatusFromRow(Map<String, dynamic> row, bool isMe) {
    if (row['read_at'] != null) return MessageStatus.read;
    if (row['delivered_at'] != null) return MessageStatus.delivered;
    final rawStatus = row['status'] as String?;
    if (rawStatus == 'failed') return MessageStatus.failed;
    if (rawStatus == 'queued') return MessageStatus.queued;
    return isMe ? MessageStatus.sent : MessageStatus.delivered;
  }

  void _appendMessage(
    String convId,
    ChatMessage msg, {
    bool incrementUnread = true,
  }) {
    if (isClosed) return;
    final updated = state.conversations.map((c) {
      if (c.id != convId) return c;
      final alreadyPresent = c.messages.any((m) => m.id == msg.id);
      return c.copyWith(
        messages: _mergeMessagesById(c.messages, [msg]),
        unreadCount: incrementUnread && !msg.isMe && !alreadyPresent
            ? c.unreadCount + 1
            : c.unreadCount,
      );
    }).toList();
    emit(state.copyWith(conversations: updated));
  }

  void _replaceQueuedMessage(
    String convId,
    String tempMsgId,
    ChatMessage realMessage,
  ) {
    if (isClosed) return;
    final updated = state.conversations.map((c) {
      if (c.id != convId) return c;
      final withoutTemp = c.messages
          .where((m) => m.id != tempMsgId && m.id != realMessage.id)
          .toList();
      return c.copyWith(
          messages: _mergeMessagesById(withoutTemp, [realMessage]));
    }).toList();
    emit(state.copyWith(conversations: updated));
  }

  void _updateMessageStatus(String convId, String msgId, MessageStatus status) {
    if (isClosed) return;
    final updated = state.conversations.map((c) {
      if (c.id != convId) return c;
      final msgs = c.messages.map((m) {
        if (m.id != msgId) return m;
        return m.copyWith(status: status);
      }).toList();
      return c.copyWith(messages: msgs);
    }).toList();
    emit(state.copyWith(conversations: updated));
  }

  List<ChatMessage> _mergeMessagesById(
    List<ChatMessage> current,
    List<ChatMessage> incoming,
  ) =>
      mergeChatMessagesById(current, incoming);

  List<Conversation> _mergeLoadedConversations(
    List<Conversation> current,
    List<Conversation> loaded,
  ) {
    final currentById = {for (final c in current) c.id: c};
    final loadedIds = loaded.map((c) => c.id).toSet();
    return [
      for (final fresh in loaded)
        _mergeConversation(currentById[fresh.id], fresh),
      for (final existing in current)
        if (!loadedIds.contains(existing.id)) existing,
    ];
  }

  Conversation _mergeConversation(Conversation? current, Conversation loaded) {
    if (current == null) return loaded;
    if (loaded.contentLocked) {
      return loaded.copyWith(messages: const <ChatMessage>[]);
    }
    return loaded.copyWith(
      messages: _mergeMessagesById(current.messages, loaded.messages),
      unreadCount: loaded.unreadCount,
      isMatchClosed: loaded.isMatchClosed,
      closureMessage: loaded.closureMessage,
    );
  }

  bool _isCurrentLoad(int version) => !isClosed && version == _loadVersion;

  bool _conversationExists(String id) =>
      state.conversations.any((c) => c.id == id);

  Conversation? _findConversation(String id) {
    final matches = state.conversations.where((c) => c.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  List<Map<String, dynamic>> _asRows(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    if (value is Map) return [Map<String, dynamic>.from(value)];
    return const [];
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  bool _isSafetyBlock(Object error) =>
      error.toString().contains('Message blocked by safety rules');
}
