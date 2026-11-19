import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Rules from the second privacy and Premium audit (19 Nov 2026). Each was
// proven on production with rollback tests; these keep them from regressing.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('310 privacy', () {
    final sql = read('supabase/migrations/310_privacy_leaks_second_audit.sql');

    test('no distance leaves the server and positions stay coarse', () {
      expect(sql, contains('r.is_verified, NULL::double precision,'));
      expect(sql, contains('round(p_latitude::numeric, 1)'));
      expect(sql, contains('greatest(v_max_distance_km, 10)'));
      // PostGIS lives in public on this project.
      expect(sql, isNot(contains('extensions.ST_')));
    });

    test('last active is kept to 5-minute steps', () {
      expect(RegExp(r"date_bin\(\\'00:05:00\\'").allMatches(sql).length, 2);
    });

    test('viewers, photos and requests respect blocks, incognito, standing',
        () {
      for (final fn in [
        'get_my_profile_viewers',
        'get_my_profile_view_summary',
      ]) {
        final body = sql.substring(sql.indexOf('FUNCTION public.$fn'));
        expect(body.substring(0, body.indexOf(r'$function$;')),
            contains('private.can_access_incognito_profile'),
            reason: fn);
      }
      final photo = sql.substring(sql.indexOf('FUNCTION public.can_view_photo'));
      expect(photo, contains('private.can_access_incognito_profile(p_viewer'));
      expect(photo, contains('owner_account.deleted_at IS NULL'));
      expect(sql, contains("p.proname IN ('get_guardian_dashboard', 'search_profiles_by_name_city')"));
    });
  });

  group('311 interests and messaging', () {
    final sql = read('supabase/migrations/311_interest_and_messaging_rules.sql');

    test('introductions are always between a man and a woman', () {
      expect(sql, contains('FUNCTION private.is_marriage_pair'));
      expect(RegExp(r'private\.is_marriage_pair\(').allMatches(sql).length,
          greaterThanOrEqualTo(3));
    });

    test('suspended members cannot chat; banned senders cannot be accepted',
        () {
      expect(sql, contains("p.visibility IN ('suspended', 'deactivated')"));
      expect(sql, contains("RAISE EXCEPTION 'account_restricted'"));
      expect(sql, contains("p.visibility NOT IN ('suspended', 'deactivated')"));
    });

    test('declines pause, notes are screened, blocks do not refund', () {
      expect(sql, contains("'interest_declined_cooldown'"));
      expect(sql, contains('public.chat_safety_check(v_note)'));
      expect(sql, contains("SET status = 'closed'"));
      expect(sql, isNot(contains('DELETE FROM public.interests')));
    });

    test('referral replies never name the referrer', () {
      final apply = sql.substring(sql.indexOf('FUNCTION public.apply_referral_code'));
      expect(apply.substring(0, apply.indexOf(r'$function$;')),
          isNot(contains("'referrer_id'")));
      expect(sql, contains("'referral_apply', v_referred_id, 10, 3600"));
    });
  });
}
