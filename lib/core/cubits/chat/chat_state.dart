// SILARAH — Chat State
//
//   • Conversations list sorted by newest message
//   • Unread count per conversation
//   • Messages: sent (gold-tinted right) / received (surface left)
//   • Message status: queued | sent | delivered | read
//   • Timestamps hidden by default; revealed on tap
//   • Respectful closure: isMatchClosed + closureMessage per conversation
import 'package:equatable/equatable.dart';

// Message status
enum MessageStatus { queued, sent, delivered, read, failed }

// Message
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.sentAt,
    required this.isMe,
    this.status = MessageStatus.sent,
    this.isTimestampVisible = false,
    this.sentByGuardian = false,
    this.operationId,
  });

  final String id;
  final String? operationId;
  final String text;
  final DateTime sentAt;
  final bool isMe; // true = sent by current user
  final MessageStatus status;
  final bool isTimestampVisible;
  final bool sentByGuardian; // §3.2: true when guardian sent this message

  ChatMessage copyWith({
    MessageStatus? status,
    bool? isTimestampVisible,
  }) {
    return ChatMessage(
      id: id,
      operationId: operationId,
      text: text,
      sentAt: sentAt,
      isMe: isMe,
      status: status ?? this.status,
      isTimestampVisible: isTimestampVisible ?? this.isTimestampVisible,
      sentByGuardian: sentByGuardian,
    );
  }

  @override
  List<Object?> get props => [
        id,
        operationId,
        text,
        sentAt,
        isMe,
        status,
        isTimestampVisible,
        sentByGuardian,
      ];
}

// Conversation
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.matchName,
    required this.matchLastInitial,
    required this.messages,
    this.unreadCount = 0,
    this.matchId,
    this.otherUserId,
    this.photoUrl,
    this.isMatchClosed = false,
    this.closureMessage,
    this.closedByMe,
    this.contentLocked = false,
    this.memberUnavailable = false,
  });

  final String id;
  final String matchName; // First name only
  final String matchLastInitial;
  final List<ChatMessage> messages;
  final int unreadCount;
  final String? matchId;
  final String? otherUserId;
  final String? photoUrl;
  final bool isMatchClosed; // true when respectful closure sent
  final String? closureMessage; // the pre-written closing message
  final bool? closedByMe; // null for automatic expiry / legacy rows
  final bool contentLocked; // authoritative server-side Premium read gate
  final bool memberUnavailable; // neutral read-only moderation/deletion state

  String get displayName {
    final surname = matchLastInitial.trim();
    return surname.isEmpty ? matchName.trim() : '${matchName.trim()} $surname';
  }

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  String get lastMessagePreview {
    if (memberUnavailable) return 'This profile is unavailable right now.';
    if (contentLocked) return 'Unlock Premium to read messages';
    final m = lastMessage;
    if (m == null) return 'Say Assalamu Alaikum!';
    return m.text.length > 50 ? '${m.text.substring(0, 50)}…' : m.text;
  }

  String get lastMessageTime {
    final m = lastMessage;
    if (m == null) return '';
    final diff = DateTime.now().difference(m.sentAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Conversation copyWith({
    List<ChatMessage>? messages,
    int? unreadCount,
    bool? isMatchClosed,
    String? closureMessage,
    String? photoUrl,
    bool? closedByMe,
    bool? contentLocked,
    bool? memberUnavailable,
  }) {
    return Conversation(
      id: id,
      matchName: matchName,
      matchLastInitial: matchLastInitial,
      messages: messages ?? this.messages,
      unreadCount: unreadCount ?? this.unreadCount,
      matchId: matchId,
      otherUserId: otherUserId,
      photoUrl: photoUrl ?? this.photoUrl,
      isMatchClosed: isMatchClosed ?? this.isMatchClosed,
      closureMessage: closureMessage ?? this.closureMessage,
      closedByMe: closedByMe ?? this.closedByMe,
      contentLocked: contentLocked ?? this.contentLocked,
      memberUnavailable: memberUnavailable ?? this.memberUnavailable,
    );
  }

  @override
  List<Object?> get props => [
        id,
        matchName,
        matchLastInitial,
        messages,
        unreadCount,
        matchId,
        otherUserId,
        photoUrl,
        isMatchClosed,
        closureMessage,
        closedByMe,
        contentLocked,
        memberUnavailable,
      ];
}

// Chat State
class ChatState extends Equatable {
  const ChatState({
    this.conversations = const [],
    this.isLoading = false,
    this.violationCounts = const {},
    this.typingConversationIds = const {},
    this.messagingSuspendedUntil,
  });

  final List<Conversation> conversations;
  final bool isLoading;
  final Map<String, int> violationCounts;

  /// Conversation ids whose other participant has sent a live typing signal.
  /// This state is intentionally transient and is never persisted.
  final Set<String> typingConversationIds;
  final DateTime? messagingSuspendedUntil;

  int get totalUnread => conversations.fold(0, (sum, c) => sum + c.unreadCount);

  bool get isSuspended =>
      messagingSuspendedUntil != null &&
      messagingSuspendedUntil!.isAfter(DateTime.now());

  bool isUserTyping(String conversationId) =>
      typingConversationIds.contains(conversationId);

  /// Returns only the current writable match cycle for a member. A pair can
  /// have multiple historical conversations after a respectful rematch, so a
  /// closed cycle must never win merely because it was already cached.
  Conversation? activeConversationWith(String otherUserId) {
    final normalizedUserId = otherUserId.trim();
    if (normalizedUserId.isEmpty) return null;
    for (final conversation in conversations) {
      if (conversation.otherUserId == normalizedUserId &&
          !conversation.isMatchClosed) {
        return conversation;
      }
    }
    return null;
  }

  /// Sorted: open conversations before ended ones, then newest message first.
  /// A just-made match has no messages yet; without the open-first rule it
  /// sank below months-old ended conversations.
  List<Conversation> get sortedConversations {
    final sorted = List<Conversation>.from(conversations);
    sorted.sort((a, b) {
      if (a.isMatchClosed != b.isMatchClosed) {
        return a.isMatchClosed ? 1 : -1;
      }
      final aTime = a.lastMessage?.sentAt ?? DateTime(0);
      final bTime = b.lastMessage?.sentAt ?? DateTime(0);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  ChatState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
    Map<String, int>? violationCounts,
    Set<String>? typingConversationIds,
    DateTime? messagingSuspendedUntil,
    bool clearMessagingSuspendedUntil = false,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      violationCounts: violationCounts ?? this.violationCounts,
      typingConversationIds:
          typingConversationIds ?? this.typingConversationIds,
      messagingSuspendedUntil: clearMessagingSuspendedUntil
          ? null
          : (messagingSuspendedUntil ?? this.messagingSuspendedUntil),
    );
  }

  @override
  List<Object?> get props => [
        conversations,
        isLoading,
        violationCounts,
        typingConversationIds,
        messagingSuspendedUntil,
      ];
}
