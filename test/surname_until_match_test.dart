import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/utils/member_name.dart';

// Full surnames are shared only with an active match. Everyone else sees an
// initial, written "Abdul A.", and the profile explains why, so members do
// not mistake it for a bug.
void main() {
  group('memberDisplayName', () {
    test('an initial gets a full stop and a capital', () {
      expect(memberDisplayName('Abdul', 'A'), 'Abdul A.');
      expect(memberDisplayName('Fatima', 'k'), 'Fatima K.');
    });

    test('a full surname is written as it is', () {
      expect(memberDisplayName('Abdul', 'Aziz'), 'Abdul Aziz');
    });

    test('a missing surname leaves the first name alone', () {
      expect(memberDisplayName('Abdul', ''), 'Abdul');
      expect(memberDisplayName('  Abdul ', '  '), 'Abdul');
    });

    test('Arabic and Urdu initials work the same way', () {
      expect(memberDisplayName('عبدالله', 'ع'), 'عبدالله ع.');
      expect(isSurnameInitialOnly('ع'), isTrue);
      expect(isSurnameInitialOnly('عزیز'), isFalse);
    });
  });

  test('the profile explains the initial on other members only', () {
    final detail = File('lib/features/home/screens/profile_detail_screen.dart')
        .readAsStringSync();
    expect(detail, contains("'Full surname is shared once you match.'"));
    expect(detail, contains('showSurnameNote: !widget.isOwnProfile'));
    expect(detail, contains('isSurnameInitialOnly(profile.visibleSurname)'));
  });

  test('every reader outside an active match gets the initial', () {
    final migration =
        File('supabase/migrations/306_surname_initial_until_match.sql')
            .readAsStringSync();
    // Discover.
    expect(migration,
        contains("left(COALESCE(p.last_name, ''::text), 1) AS last_name_initial"));
    // Photo access requests.
    expect(migration, contains(r"left(coalesce(p.last_name, \'\'), 1)"));
    // Chat list and guardian dashboard: full surname only while active.
    expect(migration, contains(r"WHEN inbox.match_status = \'active\'"));
    expect(migration, contains(r"WHEN m.status = \'active\' THEN other_p.last_name"));
    // Each edit must match exactly once or the migration stops.
    expect(RegExp('not found exactly once').allMatches(migration).length, 3);
  });
}
