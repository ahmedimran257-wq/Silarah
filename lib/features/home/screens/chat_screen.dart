// SILARAH — Individual Chat Screen
//   • Three-dot menu → "End Match" option
//   • _EndMatchSheet: 5 pre-written Islamic closure messages
//   • Closed conversation shows banner + disables input
import 'package:silarah/l10n/ui_copy.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/cubits/chat/chat_cubit.dart';
import '../../../core/cubits/chat/chat_state.dart';
import '../../../core/cubits/discovery/discovery_feed_cubit.dart';
import '../../../core/cubits/interests/interests_cubit.dart';
import '../../../core/cubits/notifications/notifications_cubit.dart';
import '../../../core/cubits/subscription/subscription_cubit.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/notification_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_curves.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations/silarah_motion.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/loaders/silarah_blur_image.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import '../../../core/widgets/overlays/silarah_dialog.dart';
import 'paywall_gate_screen.dart';
import 'profile_route_screen.dart';

/// G12: Profile-aware openers — include the match's name.
List<String> _buildOpeners(String name) => [
      'Assalamu Alaikum $name! I came across your profile and was genuinely impressed. May I introduce myself?',
      'Bismillah. Your profile caught my attention, $name. I would love to learn more about you.',
      'Assalamu Alaikum $name. I believe we share similar values. Would you be open to getting to know each other?',
      'Assalamu Alaikum $name! Your dedication to deen resonated with me. May Allah bless this conversation with goodness.',
    ];

// Pre-written Islamic closure messages
const _kClosureMessages = [
  'Assalamu Alaikum. After thoughtful reflection, I feel this may not be the right match for us. I sincerely wish you all the best and pray that Allah blesses you with a wonderful partner. JazakAllah khair.',
  'Assalamu Alaikum. I wanted to be honest and respectful with you. I do not think we are the right match, but I pray that Allah opens better doors for you. Wishing you all the best.',
  'Assalamu Alaikum. After sincere consideration, I feel we may not be compatible. I hope you find someone truly right for you. May Allah make it easy for you. JazakAllah khair for your time.',
  'Assalamu Alaikum. I have reflected on our conversations and feel it is best to close this match at this time. I have nothing but respect for you and I make dua that Allah blesses you with the best.',
  'Assalamu Alaikum. I wanted to be transparent with you rather than fade away. I do not see this progressing further, but I truly appreciate your time and wish you every happiness. May Allah bless you.',
];

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  late final ChatCubit _chatCubit;
  bool _canSend = false;
  final Set<String> _freshMessageIds = {};
  final Set<String> _knownMessageIds = {};
  bool _messageSnapshotReady = false;
  ChatAccessDecision? _accessDecision;
  bool _profileOpening = false;
  int _openGeneration = 0;
  StreamSubscription<NotificationsState>? _notificationsSubscription;

  // A store purchase reaches the server through the RevenueCat webhook a few
  // seconds later; until then the server still says subscription_required.
  static const _maxActivationAttempts = 20;
  Timer? _activationRetry;
  int _activationAttempts = 0;

  bool get _storePurchaseActive =>
      context.read<SubscriptionCubit>().state.isSubscribed;

  bool get _activationSlow => _activationAttempts >= _maxActivationAttempts;

  bool _showSuggestedOpeners = true;
  late final AnimationController _openersAnim;
  late final Animation<double> _openersSize;

  void _close() {
    popOrGoToFallback(GoRouter.of(context), '${AppRoutes.home}?tab=2');
  }

  @override
  void initState() {
    super.initState();
    _chatCubit = context.read<ChatCubit>();
    _openersAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _openersSize =
        CurvedAnimation(parent: _openersAnim, curve: Curves.easeInOut);
    _inputCtrl.addListener(_handleComposerChanged);
    _scrollCtrl.addListener(_handleScroll);
    _watchNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authorizeAndOpen();
    });
  }

  /// A message that arrives in the open chat is read as it lands, so its
  /// notification must not stay on the bell.
  void _watchNotifications() {
    try {
      final notifications = context.read<NotificationsCubit>();
      _notificationsSubscription = notifications.stream.listen((_) {
        notifications.markHandled(
          (n) =>
              n.type == 'new_message' &&
              _chatCubit.isViewingConversationLink(n.deepLink),
        );
      });
    } catch (_) {
      // Embedded or test hosts may not provide notifications.
    }
  }

  Future<void> _authorizeAndOpen() async {
    if (!mounted) return;
    final generation = ++_openGeneration;
    final conversationId = widget.conversationId;
    final decision = await _chatCubit.checkChatAccess(conversationId);
    if (!mounted || generation != _openGeneration) return;
    setState(() => _accessDecision = decision);
    if (decision.reason == ChatAccessReason.subscriptionRequired &&
        _storePurchaseActive) {
      _scheduleActivationRetry();
      return;
    }
    _activationAttempts = 0;
    if (!decision.allowed) return;
    await _chatCubit.loadMessages(conversationId, activate: true);
    if (!mounted || generation != _openGeneration) return;
    await _chatCubit.markRead(conversationId);
    if (!mounted || generation != _openGeneration) return;
    final matchId = _chatCubit.state.conversations
        .where((c) => c.id == conversationId)
        .firstOrNull
        ?.matchId;
    final links = {
      'silarah://chat/$conversationId',
      if (matchId != null) 'silarah://chat/$matchId',
    };
    try {
      context.read<NotificationsCubit>().markHandled(
            (n) =>
                n.type == 'new_message' && links.contains(n.deepLink?.trim()),
          );
    } catch (_) {
      // Embedded or test hosts may not provide notifications.
    }
    _scrollToBottom();
    await _loadOpenersDismissed();
  }

  void _scheduleActivationRetry() {
    if (_activationSlow) return;
    _activationRetry?.cancel();
    _activationRetry = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _activationAttempts++);
      _authorizeAndOpen();
    });
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId == widget.conversationId) return;
    _chatCubit.updateTyping(oldWidget.conversationId, isTyping: false);
    _chatCubit.leaveConversation(oldWidget.conversationId);
    _messageSnapshotReady = false;
    _accessDecision = null;
    _freshMessageIds.clear();
    _knownMessageIds.clear();
    _authorizeAndOpen();
  }

  void _handleComposerChanged() {
    final can = _inputCtrl.text.trim().isNotEmpty;
    if (can != _canSend && mounted) setState(() => _canSend = can);
    if (_accessDecision?.allowed != true) return;
    _chatCubit.updateTyping(widget.conversationId, isTyping: can);
  }

  void _handleScroll() {
    if (!_scrollCtrl.hasClients || _scrollCtrl.position.pixels > 48) return;
    _chatCubit.loadMessages(widget.conversationId, older: true);
  }

  Future<void> _loadOpenersDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed =
        prefs.getBool('openers_dismissed_${widget.conversationId}') ?? false;
    if (!mounted) return;
    if (dismissed) {
      setState(() => _showSuggestedOpeners = false);
      _openersAnim.value = 0.0;
    }
  }

  Future<void> _dismissOpeners() async {
    if (!_showSuggestedOpeners) return;
    await _openersAnim.reverse();
    if (!mounted) return;
    setState(() => _showSuggestedOpeners = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('openers_dismissed_${widget.conversationId}', true);
  }

  @override
  void dispose() {
    _activationRetry?.cancel();
    _notificationsSubscription?.cancel();
    _openGeneration++;
    _chatCubit.updateTyping(widget.conversationId, isTyping: false);
    _chatCubit.leaveConversation(widget.conversationId);
    _scrollCtrl.removeListener(_handleScroll);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _openersAnim.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        if (animated) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: AppDimensions.durationTransition,
            curve: Curves.easeOut,
          );
        } else {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    _chatCubit.updateTyping(widget.conversationId, isTyping: false);
    HapticFeedback.selectionClick();
    _dismissOpeners();
    final sent = await context
        .read<ChatCubit>()
        .sendMessage(widget.conversationId, text);
    if (!mounted) return;
    if (!sent) _showMessageSendFailure();
    _scrollToBottom(animated: true);
  }

  Future<void> _openMatchProfile(Conversation conversation) async {
    if (_profileOpening) return;
    final profileId = conversation.otherUserId?.trim();
    if (profileId == null || profileId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UiText(
            context.uiCopy('This profile is unavailable right now.'),
            style: TextStyle(
              color: AppColors.readableOn(AppColors.surfaceGlassHover),
            ),
          ),
          backgroundColor: AppColors.surfaceGlassHover,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            side: BorderSide(color: AppColors.cardBorder),
          ),
        ),
      );
      return;
    }

    _profileOpening = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProfileRouteScreen(profileIdentifier: profileId),
        ),
      );
    } finally {
      _profileOpening = false;
    }
  }

  Future<void> _retryMessage(ChatMessage message) async {
    HapticFeedback.selectionClick();
    final sent = await _chatCubit.retryMessage(
      widget.conversationId,
      message.id,
    );
    if (!mounted) return;
    if (!sent) _showMessageSendFailure();
  }

  void _showMessageSendFailure() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            side: BorderSide(color: AppColors.softCoral),
          ),
          content: Row(
            children: [
              Icon(Icons.sync_problem_rounded,
                  color: AppColors.softCoral, size: 20),
              const SizedBox(width: AppDimensions.space10),
              Expanded(
                child: UiText(
                  context.uiCopy(
                      'Message not sent. Tap the alert beside it to retry.'),
                  style: AppTypography.captionMedium.copyWith(
                    color: AppColors.readableOn(AppColors.surfaceElevated),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _useOpener(String text) {
    _inputCtrl.text = text;
    _inputCtrl.selection =
        TextSelection.fromPosition(TextPosition(offset: text.length));
    setState(() => _canSend = true);
    _dismissOpeners();
  }

  void _showEndMatchSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showSilarahBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EndMatchSheet(
        onConfirm: (message) async {
          final chatCubit = context.read<ChatCubit>();
          final interestsCubit = context.read<InterestsCubit>();
          final discoveryCubit = context.read<DiscoveryFeedCubit>();
          final closed =
              await chatCubit.closeMatch(widget.conversationId, message);
          if (!mounted || !closed) return false;
          interestsCubit.markMatchClosed(widget.conversationId);
          await discoveryCubit.refreshIfChanged(forceCheck: true);
          if (!mounted) return false;
          _scrollToBottom(animated: true);
          return true;
        },
      ),
    );
  }

  void _showBlockDialog(BuildContext context, String name) {
    HapticFeedback.mediumImpact();
    showSilarahDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        title:
            UiText(context.uiBlockTitle(name), style: AppTypography.bodyMedium),
        content: UiText(
          context
              .uiCopy('This closes the match and prevents further messages.'),
          style: AppTypography.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: UiText(context.uiCopy('Cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<ChatCubit>().blockUser(
                    widget.conversationId,
                    reason: 'blocked_from_chat',
                  );
              if (!context.mounted) return;
              Navigator.maybePop(context);
            },
            child: UiText(
              context.uiCopy('Block'),
              style: AppTypography.button.copyWith(color: AppColors.softCoral),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteChatDialog() async {
    final confirmed = await showSilarahDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: UiText(context.uiCopy('Delete this chat?'),
            style: AppTypography.bodyMedium),
        content: UiText(
          context.uiCopy(
              'This removes the conversation only from your inbox. The other person keeps their copy, and safety records are retained.'),
          style: AppTypography.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: UiText(context.uiCopy('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: UiText(
              context.uiCopy('Delete chat'),
              style: AppTypography.button.copyWith(color: AppColors.softCoral),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final hidden =
        await context.read<ChatCubit>().hideConversation(widget.conversationId);
    if (!mounted) return;
    if (hidden) navigator.pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: UiText(hidden
            ? 'Chat removed from your inbox.'
            : 'Unable to delete this chat. Please try again.'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _showReportSheet(BuildContext context, ChatMessage message) {
    if (message.isMe) return;
    HapticFeedback.mediumImpact();
    showSilarahBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportMessageSheet(
        onReport: (reason) async {
          Navigator.pop(context);
          await context.read<ChatCubit>().reportMessage(
                widget.conversationId,
                message.id,
                reason,
              );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    UiText(context.uiCopy('Message reported for review.'))),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final access = _accessDecision;
    if (access == null) {
      return Scaffold(
        backgroundColor: AppColors.obsidianNight,
        body: const Center(child: SilarahPulseLoader(label: 'Securing chat')),
      );
    }
    if (!access.allowed) {
      return _ChatAccessGate(
        decision: access,
        activating: access.reason == ChatAccessReason.subscriptionRequired &&
            _storePurchaseActive,
        activationSlow: _activationSlow,
        onRetry: _authorizeAndOpen,
        onViewPlans: () => PaywallGateSheet.show(context),
        onBack: _close,
      );
    }

    return BlocConsumer<ChatCubit, ChatState>(
      listenWhen: (prev, curr) {
        final prevConv = prev.conversations
            .where((c) => c.id == widget.conversationId)
            .firstOrNull;
        final currConv = curr.conversations
            .where((c) => c.id == widget.conversationId)
            .firstOrNull;
        return prevConv?.messages.length != currConv?.messages.length;
      },
      listener: (_, state) {
        final conv = state.conversations
            .where((c) => c.id == widget.conversationId)
            .firstOrNull;
        if (conv == null) return;
        final currentIds = conv.messages.map((message) => message.id).toSet();
        if (_messageSnapshotReady) {
          final incoming = currentIds.difference(_knownMessageIds);
          if (incoming.length <= 3) _freshMessageIds.addAll(incoming);
        } else {
          _messageSnapshotReady = true;
        }
        _knownMessageIds
          ..clear()
          ..addAll(currentIds);

        final nearBottom = !_scrollCtrl.hasClients ||
            _scrollCtrl.position.maxScrollExtent - _scrollCtrl.position.pixels <
                180;
        final newestIsMine = conv.messages.lastOrNull?.isMe == true;
        if (nearBottom || newestIsMine) _scrollToBottom(animated: true);
      },
      builder: (context, state) {
        final conv = state.conversations
            .where((c) => c.id == widget.conversationId)
            .firstOrNull;

        if (conv == null) {
          return Scaffold(
            backgroundColor: AppColors.obsidianNight,
            body:
                const Center(child: SilarahPulseLoader(label: 'Opening chat')),
          );
        }

        if (conv.contentLocked) {
          return _ChatAccessGate(
            decision: const ChatAccessDecision(
              ChatAccessReason.subscriptionRequired,
            ),
            activating: _storePurchaseActive,
            activationSlow: _activationSlow,
            onRetry: _authorizeAndOpen,
            onViewPlans: () => PaywallGateSheet.show(context),
            onBack: _close,
          );
        }

        final hasMessages = conv.messages.isNotEmpty;
        final isClosed = conv.isMatchClosed;
        final isTyping = state.isUserTyping(widget.conversationId) && !isClosed;
        if (!_messageSnapshotReady && hasMessages) {
          _messageSnapshotReady = true;
          _knownMessageIds.addAll(conv.messages.map((message) => message.id));
        }

        return Scaffold(
          // Let the platform apply the authoritative IME inset. The previous
          // custom spring padding could lag behind fast keyboard transitions
          // and leave the composer underneath the keyboard.
          resizeToAvoidBottomInset: true,
          backgroundColor: AppColors.obsidianNight,
          appBar: _ChatAppBar(
            displayName: conv.displayName,
            firstName: conv.matchName,
            photoUrl: conv.photoUrl,
            isClosed: isClosed,
            isTyping: isTyping,
            onOpenProfile: () => _openMatchProfile(conv),
            onEndMatch: () => _showEndMatchSheet(context),
            onBlock: () => _showBlockDialog(context, conv.matchName),
            onDelete: _showDeleteChatDialog,
            onBack: _close,
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                // Closed match banner
                if (isClosed)
                  _ClosedBanner(
                    name: conv.matchName,
                    closedByMe: conv.closedByMe,
                    memberUnavailable: conv.memberUnavailable,
                  ),

                // Suspended banner
                if (state.isSuspended)
                  _SuspendedBanner(
                      suspendedUntil: state.messagingSuspendedUntil),

                // Messages
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: hasMessages
                            ? ListView.builder(
                                controller: _scrollCtrl,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDimensions.space16,
                                  vertical: AppDimensions.space12,
                                ),
                                itemCount: conv.messages.length,
                                itemBuilder: (_, i) {
                                  final msg = conv.messages[i];
                                  final prev =
                                      i > 0 ? conv.messages[i - 1] : null;
                                  final sameAsPrev =
                                      prev != null && prev.isMe == msg.isMe;
                                  return _MessageArrival(
                                    key: ValueKey('message_${msg.id}'),
                                    animate: _freshMessageIds.remove(msg.id),
                                    isMine: msg.isMe,
                                    child: _MessageBubble(
                                      message: msg,
                                      sameAsPrev: sameAsPrev,
                                      onTap: () => context
                                          .read<ChatCubit>()
                                          .toggleTimestamp(
                                              widget.conversationId, msg.id),
                                      onLongPress: () =>
                                          msg.status == MessageStatus.failed
                                              ? _retryMessage(msg)
                                              : _showReportSheet(context, msg),
                                      onRetry:
                                          msg.status == MessageStatus.failed
                                              ? () => _retryMessage(msg)
                                              : null,
                                    ),
                                  );
                                },
                              )
                            : _SuggestedOpenersArea(
                                showOpeners: _showSuggestedOpeners,
                                sizeAnim: _openersSize,
                                onSelect: _useOpener,
                                matchName: conv.matchName,
                              ),
                      ),
                      _TypingPresenceBar(
                        visible: isTyping,
                        name: conv.matchName,
                      ),
                    ],
                  ),
                ),

                // Input bar (hidden when closed or suspended)
                if (state.isSuspended)
                  _SuspendedInputBar(
                      suspendedUntil: state.messagingSuspendedUntil)
                else if (!isClosed)
                  _InputBar(
                      controller: _inputCtrl,
                      canSend: _canSend,
                      onSend: _sendMessage)
                else
                  _ClosedInputBar(),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Closed Banner
class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner({
    required this.name,
    required this.closedByMe,
    required this.memberUnavailable,
  });
  final String name;
  final bool? closedByMe;
  final bool memberUnavailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space12,
      ),
      color: AppColors.softCoral.withValues(alpha: 0.1),
      child: Row(children: [
        Icon(Icons.lock_outline_rounded, color: AppColors.softCoral, size: 16),
        const SizedBox(width: AppDimensions.space8),
        Expanded(
            child: UiText(
          memberUnavailable
              ? context.uiCopy('This profile is unavailable right now.')
              : context.uiCopyWith(
                  switch (closedByMe) {
                    true => 'You ended this match.',
                    false => '$name ended this match.',
                    null => 'This match has ended.',
                  }
                      .replaceFirst(RegExp('^${RegExp.escape(name)} ended'),
                          '{name} ended'),
                  {'name': name},
                ),
          style: AppTypography.caption.copyWith(color: AppColors.softCoral),
        )),
      ]),
    );
  }
}

// Closed Input Replacement
class _ClosedInputBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.space16,
        AppDimensions.space12,
        AppDimensions.space16,
        AppDimensions.space12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.obsidianNight,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Center(
          child: UiText(
        context.uiCopy('This conversation is closed'),
        style: AppTypography.caption,
      )),
    );
  }
}

// Suspended Banner
class _SuspendedBanner extends StatelessWidget {
  const _SuspendedBanner({required this.suspendedUntil});
  final DateTime? suspendedUntil;

  @override
  Widget build(BuildContext context) {
    final diff = suspendedUntil != null
        ? suspendedUntil!.difference(DateTime.now())
        : Duration.zero;
    final hours = diff.inHours.clamp(0, 24);
    final minutes = diff.inMinutes % 60;
    final remainingStr = hours > 0
        ? context.uiCopyWith(
            hours == 1 ? '{count} hour' : '{count} hours', {'count': hours})
        : context.uiCopyWith(
            minutes == 1 ? '{count} minute' : '{count} minutes',
            {'count': minutes});

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space12,
      ),
      color: AppColors.softCoral.withValues(alpha: 0.1),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, color: AppColors.softCoral, size: 16),
        const SizedBox(width: AppDimensions.space8),
        Expanded(
            child: UiText(
          context.uiCopyWith(
            'Messaging suspended for violating community guidelines. Unlocks in {time}.',
            {'time': remainingStr},
          ),
          style: AppTypography.caption.copyWith(color: AppColors.softCoral),
        )),
      ]),
    );
  }
}

// Suspended Input Replacement
class _SuspendedInputBar extends StatelessWidget {
  const _SuspendedInputBar({required this.suspendedUntil});
  final DateTime? suspendedUntil;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.space16,
        AppDimensions.space12,
        AppDimensions.space16,
        AppDimensions.space12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.obsidianNight,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Center(
          child: UiText(
        context.uiCopy('Messaging is temporarily suspended'),
        style: AppTypography.caption,
      )),
    );
  }
}

// End Match Bottom Sheet
class _EndMatchSheet extends StatefulWidget {
  const _EndMatchSheet({required this.onConfirm});
  final Future<bool> Function(String) onConfirm;

  @override
  State<_EndMatchSheet> createState() => _EndMatchSheetState();
}

class _EndMatchSheetState extends State<_EndMatchSheet> {
  int? _selected;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final confirmBackground = AppColors.softCoral.withValues(alpha: 0.9);
    final disabledBackground = AppColors.surfaceGlassHover;
    return Container(
      margin: const EdgeInsets.all(AppDimensions.space16),
      padding: const EdgeInsets.all(AppDimensions.space24),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: AppDimensions.space20),
          UiText(context.uiCopy('End this match'),
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.pearlWhite)),
          const SizedBox(height: AppDimensions.space6),
          UiText(
            context.uiCopy(
                'Choose a respectful message to close this conversation. The other person will be notified.'),
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppDimensions.space16),
          ..._kClosureMessages.asMap().entries.map((entry) {
            final i = entry.key;
            final msg = entry.value;
            final sel = _selected == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space8),
              child: GestureDetector(
                onTap: () => setState(() => _selected = sel ? null : i),
                child: AnimatedContainer(
                  duration: AppDimensions.durationTransition,
                  padding: const EdgeInsets.all(AppDimensions.space12),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.champagneGold.withValues(alpha: 0.08)
                        : AppColors.surfaceGlass,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(
                      color:
                          sel ? AppColors.champagneGold : AppColors.cardBorder,
                      width: sel
                          ? AppDimensions.borderFocus
                          : AppDimensions.borderThin,
                    ),
                  ),
                  child: UiText(
                    msg,
                    style: AppTypography.caption.copyWith(
                      color: sel ? AppColors.pearlWhite : AppColors.slateMist,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: AppDimensions.space16),
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeight,
            child: ElevatedButton(
              onPressed: _selected != null && !_submitting
                  ? () async {
                      setState(() => _submitting = true);
                      final closed =
                          await widget.onConfirm(_kClosureMessages[_selected!]);
                      if (!context.mounted) return;
                      if (closed) {
                        Navigator.pop(context);
                        return;
                      }
                      setState(() => _submitting = false);
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(SnackBar(
                          content: UiText(context.uiCopy(
                            'Could not end this match. Check your connection and retry.',
                          )),
                        ));
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmBackground,
                foregroundColor: AppColors.readableOn(confirmBackground),
                disabledBackgroundColor: disabledBackground,
                disabledForegroundColor:
                    AppColors.readableOn(disabledBackground),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton)),
                elevation: 0,
              ),
              child: _submitting
                  ? SilarahActivityIndicator(
                      size: 22,
                      color: AppColors.readableOn(confirmBackground),
                    )
                  : UiText(
                      context.uiCopy('Send & End Match'),
                      style: AppTypography.button.copyWith(
                        color: _selected != null
                            ? AppColors.readableOn(confirmBackground)
                            : AppColors.readableOn(disabledBackground),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeightSmall,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.cardBorder),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton)),
              ),
              onPressed: () => Navigator.pop(context),
              child: UiText(context.uiCopy('Cancel'),
                  style: AppTypography.button
                      .copyWith(color: AppColors.slateMist)),
            ),
          ),
        ],
      ),
    );
  }
}

// Suggested Openers Area
class _ReportMessageSheet extends StatelessWidget {
  const _ReportMessageSheet({required this.onReport});
  final ValueChanged<String> onReport;

  @override
  Widget build(BuildContext context) {
    const reasons = [
      ('harassment', 'Harassment or pressure'),
      ('contact_sharing', 'Phone, social, or link sharing'),
      ('scam', 'Scam or suspicious request'),
      ('inappropriate', 'Inappropriate message'),
      ('other', 'Other safety concern'),
    ];

    return Container(
      margin: const EdgeInsets.all(AppDimensions.space16),
      padding: const EdgeInsets.all(AppDimensions.space24),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UiText(context.uiCopy('Report message'),
              style: AppTypography.bodyMedium),
          const SizedBox(height: AppDimensions.space6),
          UiText(
            'Reports are reviewed by Silarah safety staff.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppDimensions.space16),
          for (final reason in reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space8),
              child: GestureDetector(
                onTap: () => onReport(reason.$1),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space14,
                    vertical: AppDimensions.space12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: UiText(reason.$2, style: AppTypography.body),
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeightSmall,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.cardBorder),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: UiText(
                context.uiCopy('Cancel'),
                style:
                    AppTypography.button.copyWith(color: AppColors.slateMist),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedOpenersArea extends StatelessWidget {
  const _SuggestedOpenersArea({
    required this.showOpeners,
    required this.sizeAnim,
    required this.onSelect,
    required this.matchName,
  });
  final bool showOpeners;
  final Animation<double> sizeAnim;
  final ValueChanged<String> onSelect;
  final String matchName;

  @override
  Widget build(BuildContext context) {
    final openers = _buildOpeners(matchName);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        UiText(context.uiCopy('Begin with Bismillah'),
            style: AppTypography.tagline),
        const SizedBox(height: AppDimensions.space20),
        SilarahSizeReveal(
          factor: sizeAnim,
          child: SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
              itemCount: openers.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppDimensions.space12),
              itemBuilder: (_, i) => _OpenerCard(
                text: openers[i],
                onSelect: () => onSelect(openers[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// AppBar
class _ChatAccessGate extends StatelessWidget {
  const _ChatAccessGate({
    required this.decision,
    required this.onRetry,
    required this.onViewPlans,
    required this.onBack,
    this.activating = false,
    this.activationSlow = false,
  });

  final ChatAccessDecision decision;

  /// The store reports an active purchase the server has not recorded yet.
  final bool activating;
  final bool activationSlow;
  final VoidCallback onRetry;
  final VoidCallback onViewPlans;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final needsPremium = decision.requiresSubscription && !activating;
    final returnsToInbox = decision.reason == ChatAccessReason.notFound ||
        decision.reason == ChatAccessReason.closed ||
        decision.reason == ChatAccessReason.accountRestricted;
    final (title, body, icon) = switch (decision.reason) {
      ChatAccessReason.subscriptionRequired when activating => (
          'Activating your Premium',
          activationSlow
              ? 'This is taking longer than usual. Tap Refresh access, or restore your purchase from the Premium screen.'
              : 'Google Play confirmed your purchase. Messaging opens in a few seconds.',
          Icons.hourglass_top_rounded,
        ),
      ChatAccessReason.subscriptionRequired => (
          'Messaging with Premium',
          'Men unlock conversations with Silarah Premium. Your existing matches stay safely here.',
          Icons.lock_outline_rounded,
        ),
      ChatAccessReason.suspended => (
          'Messaging temporarily restricted',
          'This account cannot send messages right now. Review your account status for details.',
          Icons.shield_outlined,
        ),
      ChatAccessReason.guardianApprovalRequired => (
          'Waiting for Guardian approval',
          'An active Guardian must approve this match before messaging opens. Your match remains safely saved.',
          Icons.family_restroom_rounded,
        ),
      ChatAccessReason.closed => (
          'Conversation ended',
          'This match is no longer open for messaging.',
          Icons.forum_outlined,
        ),
      ChatAccessReason.notFound => (
          'Conversation no longer available',
          'This notification belongs to a conversation that has been removed. Your other messages are still available.',
          Icons.forum_outlined,
        ),
      ChatAccessReason.accountRestricted => (
          'Messaging unavailable',
          'Messaging is unavailable for this account. Open Help & Support if you believe this is a mistake.',
          Icons.shield_outlined,
        ),
      _ => (
          'Unable to open chat',
          'We could not securely verify access. Check your connection and try again.',
          Icons.sync_problem_rounded,
        ),
    };

    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: AppColors.obsidianNight,
        leading: IconButton(
          tooltip: context.uiCopy('Back'),
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.champagneGold.withValues(alpha: 0.09),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusCard),
                      border: Border.all(color: AppColors.goldBorder),
                    ),
                    child: Icon(icon, color: AppColors.champagneGold, size: 26),
                  ),
                  const SizedBox(height: AppDimensions.space20),
                  UiText(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTypography.screenTitle.copyWith(fontSize: 23),
                  ),
                  const SizedBox(height: AppDimensions.space10),
                  UiText(
                    body,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMuted.copyWith(height: 1.55),
                  ),
                  const SizedBox(height: AppDimensions.space24),
                  SilarahPressable(
                    semanticLabel: needsPremium
                        ? 'View Premium'
                        : returnsToInbox
                            ? 'Back to messages'
                            : activating
                                ? 'Refresh access'
                                : 'Try again',
                    onTap: needsPremium
                        ? onViewPlans
                        : returnsToInbox
                            ? onBack
                            : onRetry,
                    child: Container(
                      width: double.infinity,
                      height: AppDimensions.buttonHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.champagneGold,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusButton),
                      ),
                      child: UiText(
                        needsPremium
                            ? 'View Premium'
                            : returnsToInbox
                                ? 'Back to messages'
                                : activating
                                    ? 'Refresh access'
                                    : 'Try again',
                        style: AppTypography.button,
                      ),
                    ),
                  ),
                  if (needsPremium) ...[
                    const SizedBox(height: AppDimensions.space8),
                    TextButton(
                      onPressed: onRetry,
                      child: UiText(
                        context.uiCopy('Refresh access'),
                        style: AppTypography.bodyMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({
    required this.displayName,
    required this.firstName,
    required this.photoUrl,
    required this.isClosed,
    required this.isTyping,
    required this.onOpenProfile,
    required this.onEndMatch,
    required this.onBlock,
    required this.onDelete,
    required this.onBack,
  });
  final String displayName;
  final String firstName;
  final String? photoUrl;
  final bool isClosed;
  final bool isTyping;
  final VoidCallback onOpenProfile;
  final VoidCallback onEndMatch;
  final VoidCallback onBlock;
  final VoidCallback onDelete;
  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: AppColors.obsidianNight,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(children: [
        Semantics(
          button: true,
          label: context.uiCopy('Back'),
          child: GestureDetector(
            onTap: onBack,
            child: Container(
              margin: const EdgeInsets.all(AppDimensions.space8),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cardBorder)),
              child: Icon(Icons.arrow_back_rounded,
                  color: AppColors.pearlWhite,
                  size: AppDimensions.iconSizeMedium),
            ),
          ),
        ),
        Expanded(
          child: Semantics(
            button: true,
            label: context.uiOpenProfile(displayName),
            child: SilarahPressable(
              onTap: onOpenProfile,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: 2,
                  end: AppDimensions.space8,
                  top: AppDimensions.space8,
                  bottom: AppDimensions.space8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceGlassHover,
                          border: Border.all(color: AppColors.goldBorder)),
                      child: ClipOval(
                        child: photoUrl == null || photoUrl!.isEmpty
                            ? Icon(Icons.person_outline_rounded,
                                color: AppColors.slateMist, size: 22)
                            : SilarahBlurImage(
                                imageUrl: photoUrl!,
                                width: 40,
                                height: 40,
                              ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                        child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UiText(displayName,
                            style: AppTypography.bodyMedium, maxLines: 1),
                        AnimatedSwitcher(
                          duration: reduceMotion
                              ? Duration.zero
                              : AppDimensions.durationTransition,
                          reverseDuration: reduceMotion
                              ? Duration.zero
                              : AppDimensions.durationTransition,
                          switchInCurve: AppCurves.reveal,
                          switchOutCurve: AppCurves.transition,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.22),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: UiText(
                            isClosed
                                ? 'Match closed'
                                : isTyping
                                    ? context.uiTyping(firstName)
                                    : 'Private conversation',
                            key: ValueKey('${isClosed}_$isTyping'),
                            style: AppTypography.caption.copyWith(
                              fontSize: 11,
                              color: isClosed
                                  ? AppColors.softCoral
                                  : isTyping
                                      ? AppColors.champagneGold
                                      : AppColors.slateMist,
                            ),
                          ),
                        ),
                      ],
                    )),
                  ],
                ),
              ),
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: context.uiCopy('Chat options'),
          icon: Container(
            margin: const EdgeInsets.all(AppDimensions.space8),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardBorder)),
            child: Icon(Icons.more_vert_rounded,
                color: AppColors.slateMist, size: AppDimensions.iconSizeMedium),
          ),
          color: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            side: BorderSide(color: AppColors.cardBorder),
          ),
          itemBuilder: (_) => [
            if (isClosed)
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded,
                      color: AppColors.softCoral, size: 18),
                  const SizedBox(width: AppDimensions.space8),
                  UiText(context.uiCopy('Delete chat'),
                      style: AppTypography.body
                          .copyWith(color: AppColors.softCoral)),
                ]),
              )
            else ...[
              PopupMenuItem<String>(
                value: 'block',
                child: Row(children: [
                  Icon(Icons.block_rounded,
                      color: AppColors.softCoral, size: 18),
                  const SizedBox(width: AppDimensions.space8),
                  UiText(context.uiCopy('Block user'),
                      style: AppTypography.body
                          .copyWith(color: AppColors.softCoral)),
                ]),
              ),
              PopupMenuItem<String>(
                value: 'end',
                child: Row(children: [
                  Icon(Icons.do_not_disturb_on_outlined,
                      color: AppColors.softCoral, size: 18),
                  const SizedBox(width: AppDimensions.space8),
                  UiText(context.uiCopy('End Match'),
                      style: AppTypography.body
                          .copyWith(color: AppColors.softCoral)),
                ]),
              ),
            ],
          ],
          onSelected: (v) {
            if (v == 'block') onBlock();
            if (v == 'end') onEndMatch();
            if (v == 'delete') onDelete();
          },
        )
      ]),
    );
  }
}

// Opener Card
class _OpenerCard extends StatelessWidget {
  const _OpenerCard({required this.text, required this.onSelect});
  final String text;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelect();
      },
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(AppDimensions.space14),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: UiText(text,
            style: AppTypography.bio.copyWith(fontSize: 13),
            maxLines: 4,
            overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

// Live message motion & typing presence
class _MessageArrival extends StatelessWidget {
  const _MessageArrival({
    super.key,
    required this.animate,
    required this.isMine,
    required this.child,
  });

  final bool animate;
  final bool isMine;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldAnimate = animate && !reduceMotion;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: shouldAnimate ? 0 : 1, end: 1),
      duration:
          shouldAnimate ? const Duration(milliseconds: 360) : Duration.zero,
      curve: AppCurves.reveal,
      child: child,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(
          (isMine ? 1 : -1) * (1 - value) * 18,
          (1 - value) * 10,
        ),
        child: Opacity(opacity: value, child: child),
      ),
    );
  }
}

class _TypingPresenceBar extends StatefulWidget {
  const _TypingPresenceBar({required this.visible, required this.name});

  final bool visible;
  final String name;

  @override
  State<_TypingPresenceBar> createState() => _TypingPresenceBarState();
}

class _TypingPresenceBarState extends State<_TypingPresenceBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _TypingPresenceBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.visible && !_reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: widget.visible ? context.uiTyping(widget.name) : null,
      child: AnimatedSwitcher(
        duration:
            _reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
        switchInCurve: AppCurves.reveal,
        switchOutCurve: AppCurves.transition,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SilarahSizeReveal(
            factor: animation,
            child: child,
          ),
        ),
        child: widget.visible
            ? Padding(
                key: const ValueKey('typing_presence'),
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.space16,
                  AppDimensions.space4,
                  AppDimensions.space16,
                  AppDimensions.space8,
                ),
                child: Row(
                  children: [
                    Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGlassHover,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (_, __) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(3, (index) {
                            final wave = _reduceMotion
                                ? 0.5
                                : (math.sin(
                                          (_controller.value * math.pi * 2) -
                                              (index * 0.8),
                                        ) +
                                        1) /
                                    2;
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: Container(
                                width: 5 + wave * 2,
                                height: 5 + wave * 2,
                                decoration: BoxDecoration(
                                  color: AppColors.champagneGold.withValues(
                                    alpha: 0.42 + wave * 0.58,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space8),
                    UiText(
                      context.uiTyping(widget.name),
                      style: AppTypography.chatTimestamp.copyWith(
                        color: AppColors.champagneGold,
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(key: ValueKey('typing_presence_hidden')),
      ),
    );
  }
}

// Message bubble
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.sameAsPrev,
    required this.onTap,
    required this.onLongPress,
    this.onRetry,
  });
  final ChatMessage message;
  final bool sameAsPrev;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;

    // Only the first bubble of a run carries the tail corner, so consecutive
    // messages read as one grouped thought.
    const round = Radius.circular(18);
    final tail = sameAsPrev ? round : const Radius.circular(6);
    final radius = BorderRadiusDirectional.only(
      topStart: isMe ? round : tail,
      topEnd: isMe ? tail : round,
      bottomStart: round,
      bottomEnd: round,
    );
    final fill = isMe ? AppColors.champagneGold : AppColors.surfaceElevated;

    return Padding(
      padding: EdgeInsets.only(
          top: sameAsPrev ? AppDimensions.space4 : AppDimensions.space12,
          bottom: AppDimensions.space2),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // §3.2: Guardian message indicator
          if (message.sentByGuardian)
            Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.supervisor_account_outlined,
                      color: AppColors.champagneGold.withValues(alpha: 0.7),
                      size: 12),
                  const SizedBox(width: 3),
                  UiText(context.uiCopy('Sent by Guardian'),
                      style: AppTypography.chatTimestamp.copyWith(
                        color: AppColors.champagneGold.withValues(alpha: 0.7),
                        fontSize: 10,
                      )),
                ],
              ),
            ),
          GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.space14,
                        vertical: AppDimensions.space10),
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: radius,
                      border: isMe
                          ? null
                          : Border.all(color: AppColors.cardBorder, width: 0.8),
                    ),
                    child: UiText(
                      message.text,
                      style: isMe
                          ? AppTypography.chatMessage
                              .copyWith(color: AppColors.readableOn(fill))
                          : AppTypography.chatMessage,
                    ),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: AppDimensions.space4),
                  _StatusIcon(status: message.status, onRetry: onRetry)
                ],
              ],
            ),
          ),
          AnimatedSize(
            duration: AppDimensions.durationTransition,
            child: message.isTimestampVisible
                ? Padding(
                    padding: const EdgeInsets.only(
                        top: AppDimensions.space4,
                        left: AppDimensions.space4,
                        right: AppDimensions.space4),
                    child: UiText(_formatTime(context, message.sentAt),
                        style: AppTypography.chatTimestamp),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _formatTime(BuildContext context, DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return '$h:$m';
    if (diff.inDays == 1) return context.uiYesterdayTime('$h:$m');
    return '${dt.day}/${dt.month} $h:$m';
  }
}

// Message status icon
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, this.onRetry});
  final MessageStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.queued:
        return Icon(Icons.access_time_rounded,
            color: AppColors.slateMist, size: 12);
      case MessageStatus.sent:
        return Icon(Icons.check_rounded, color: AppColors.slateMist, size: 12);
      case MessageStatus.delivered:
        return Icon(Icons.done_all_rounded,
            color: AppColors.slateMist, size: 12);
      case MessageStatus.read:
        return Icon(Icons.done_all_rounded,
            color: AppColors.champagneGold, size: 12);
      case MessageStatus.failed:
        return Semantics(
          button: true,
          label: context.uiCopy('Message failed. Tap to retry.'),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRetry,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.sync_problem_rounded,
                  color: AppColors.softCoral, size: 16),
            ),
          ),
        );
    }
  }
}

// Input bar
// arrow icon that appears when typing starts."

class _InputBar extends StatefulWidget {
  const _InputBar(
      {required this.controller, required this.canSend, required this.onSend});
  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocus);
  }

  void _handleFocus() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.space16,
        AppDimensions.space12,
        AppDimensions.space16,
        AppDimensions.space12,
      ),
      decoration: BoxDecoration(
        color: AppColors.obsidianNight,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: AnimatedContainer(
            duration:
                reduceMotion ? Duration.zero : AppDimensions.durationTransition,
            curve: AppCurves.transition,
            constraints: const BoxConstraints(minHeight: 46, maxHeight: 120),
            decoration: BoxDecoration(
              color: _focused ? AppColors.inputSurface : AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: _focused ? AppColors.goldBorder : AppColors.cardBorder,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: AppColors.goldGlow,
                        blurRadius: 18,
                        spreadRadius: -6,
                      ),
                    ]
                  : const [],
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              maxLines: null,
              minLines: 1,
              cursorColor: AppColors.champagneGold,
              keyboardAppearance: Brightness.dark,
              textCapitalization: TextCapitalization.sentences,
              style: AppTypography.chatMessage,
              textInputAction: TextInputAction.newline,
              onTapOutside: (_) => _focusNode.unfocus(),
              decoration: InputDecoration(
                hintText: context.uiCopy('Type a message…'),
                hintStyle: AppTypography.inputLabel,
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space16,
                  vertical: AppDimensions.space12,
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration:
              reduceMotion ? Duration.zero : AppDimensions.durationTransition,
          curve: AppCurves.transition,
          child: widget.canSend
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(
                      start: AppDimensions.space10),
                  child: SilarahPressable(
                    semanticLabel: context.uiCopy('Send message'),
                    onTap: widget.onSend,
                    pressedScale: 0.92,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.champagneLight,
                            AppColors.champagneGold,
                            AppColors.antiqueGold,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.goldGlow,
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: AppColors.obsidianNight,
                        size: 23,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}
