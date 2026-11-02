import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Realtime connections count against the plan's concurrent-connection
  // limit (200 on Free, 500 on Pro). Live channels exist only on screens
  // that need them, and each is removed when the screen is left: removing
  // the last channel also closes the shared socket, while unsubscribe alone
  // would leave an idle connection open.
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  String rel(File file) => file.path.replaceAll(r'\', '/');

  test('only screens that need live updates open realtime channels', () {
    const allowed = {
      'lib/core/cubits/chat/chat_cubit.dart',
      'lib/core/services/wali_mode_service.dart',
      'lib/features/home/screens/photo_access_requests_screen.dart',
    };
    final opening = dartFiles
        .where((file) => file.readAsStringSync().contains('.channel('))
        .map(rel)
        .toSet();
    expect(opening.difference(allowed), isEmpty,
        reason: 'New realtime channel: add it here only if the screen '
            'cannot use push or an on-demand refresh, and remove it on exit.');
  });

  test('every realtime channel is removed, not just unsubscribed', () {
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      if (!source.contains('.channel(')) continue;
      expect(source, contains('removeChannel('),
          reason: '${rel(file)} opens a channel without removeChannel');
    }
  });

  test('no always-on table streams', () {
    // .stream() keeps a realtime subscription open for the widget's life.
    for (final file in dartFiles) {
      expect(file.readAsStringSync(), isNot(contains('.stream(primaryKey')),
          reason: '${rel(file)} uses an always-on table stream');
    }
  });
}
