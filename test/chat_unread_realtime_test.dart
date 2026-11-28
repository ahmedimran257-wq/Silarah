import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/chat/chat_state.dart';

void main() {
  test('chat badge totals authoritative per-conversation unread counts', () {
    const state = ChatState(
      conversations: [
        Conversation(
          id: 'match-a',
          matchName: 'Amina',
          matchLastInitial: 'K',
          messages: [],
          unreadCount: 2,
        ),
        Conversation(
          id: 'match-b',
          matchName: 'Sara',
          matchLastInitial: 'M',
          messages: [],
          unreadCount: 1,
        ),
      ],
    );

    expect(state.totalUnread, 3);
  });

  test('chat badge recovers through bounded FCM and resume reconciliation', () {
    final chat =
        File('lib/core/cubits/chat/chat_cubit.dart').readAsStringSync();
    final nav = File(
      'lib/features/home/widgets/silarah_bottom_nav.dart',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(chat, isNot(contains(".channel('chat_inbox:\$me')")));
    expect(chat, contains('_reconcileInboxAndActiveConversation'));
    expect(chat, contains('await loadMessages(activeConversationId)'));

    expect(nav, contains('selector: (state) => state.totalUnread'));
    expect(nav, contains('HomeTab.chats => chatUnread'));

    // Foreground FCM, app resume and both tap paths remain independent
    // recovery signals. ChatCubit coalesces a burst into one reconciliation.
    expect(main, contains('reconcileForegroundPush('));
    expect(main, contains("if (item.type == 'new_message')"));
    expect(main, contains('_notificationRefreshSubscription'));
    expect(main, contains('_chatCubit.scheduleInboxReconciliation()'));
    expect(
      RegExp(r'_chatCubit\.scheduleInboxReconciliation\(\)')
          .allMatches(main)
          .length,
      3,
    );
  });
}
