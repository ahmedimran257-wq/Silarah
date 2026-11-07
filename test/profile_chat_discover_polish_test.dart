import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/discovery/discovery_feed_cubit.dart';

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  test('closed or blocked conversations add nothing to unread badges', () {
    final chat = _read('lib/core/cubits/chat/chat_cubit.dart');
    expect(chat, contains("matchClosed ? 0 : (row['unread_count']"));
    // A local block clears the count straight away too.
    expect(
      chat,
      contains('isMatchClosed: true,\n        unreadCount: 0,'),
    );
  });

  test(
      'a failed profile refresh is explained and retried, not shown as '
      '"add a photo"', () {
    final profile = _read('lib/features/home/screens/my_profile_screen.dart');
    expect(profile, contains('_ProfileRefreshNotice('));
    expect(
        profile, contains('nextStep: _photoCountKnown ? result.next : null'));
    expect(profile, isNot(contains('setState(() => _approvedPhotoCount = 0)')));
    expect(profile, contains('_profileRetryTimer = Timer('));
  });

  test('a new match unlocks locked photos already in the Discover feed', () {
    final screen =
        _read('lib/features/home/screens/discovery_feed_screen.dart');
    expect(screen, contains('revealPhotosForMatches(ids)'));
  });

  test('photo reveal is a no-op without matches', () async {
    final cubit = DiscoveryFeedCubit();
    addTearDown(cubit.close);
    final before = cubit.state;
    await cubit.revealPhotosForMatches(const {});
    await cubit.revealPhotosForMatches(const {'someone'});
    expect(cubit.state, before);
  });
}
