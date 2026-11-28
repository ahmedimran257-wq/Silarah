import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shadowban and profile-photo resilience contracts', () {
    late String migration;
    late String profileScreen;
    late String homeScreen;
    late String banner;
    late String signedUrlFunction;
    late String supabaseService;
    late String authCubit;
    late String photoService;
    late String adminPage;

    setUpAll(() {
      migration = File(
        'supabase/migrations/120_silent_shadowban_and_admin_status.sql',
      ).readAsStringSync();
      profileScreen = File(
        'lib/features/home/screens/my_profile_screen.dart',
      ).readAsStringSync();
      homeScreen = File(
        'lib/features/home/home_screen.dart',
      ).readAsStringSync();
      banner = File(
        'lib/core/widgets/in_app_notification_banner.dart',
      ).readAsStringSync();
      signedUrlFunction = File(
        'supabase/functions/get-signed-url/index.ts',
      ).readAsStringSync();
      supabaseService = File(
        'lib/core/services/supabase_service.dart',
      ).readAsStringSync();
      authCubit = File(
        'lib/core/cubits/auth/auth_cubit.dart',
      ).readAsStringSync();
      photoService = File(
        'lib/core/services/profile_photo_service.dart',
      ).readAsStringSync();
      adminPage = File(
        'admin/src/app/(staff)/users/page.tsx',
      ).readAsStringSync();
    });

    test('shadowban is silent while staff can see and reverse it', () {
      final shadowbanBranch = migration.substring(
        migration.indexOf("ELSIF p_action = 'shadowban'"),
        migration.indexOf("ELSIF p_action = 'ban'"),
      );

      expect(shadowbanBranch, contains('is_shadowbanned = true'));
      expect(shadowbanBranch, isNot(contains('queue_notification')));
      expect(
          migration,
          contains(
              "DELETE FROM public.notifications WHERE type = 'account_limited'"));
      expect(adminPage, contains('user.is_shadowbanned'));
      expect(adminPage, contains('Remove shadowban'));
    });

    test('banner does not require a Navigator overlay', () {
      expect(banner, isNot(contains("tooltip: 'Dismiss'")));
      expect(banner, contains("label: 'Dismiss notification'"));
    });

    test('profile avatar refreshes expired signed URLs', () {
      expect(profileScreen, contains('_recoverPrimaryPhoto'));
      expect(profileScreen, contains('failedUrl != _primaryPhotoUrl'));
      expect(profileScreen, contains('onPhotoLoadFailed'));
      expect(profileScreen, contains('didChangeAppLifecycleState'));
      expect(homeScreen, contains('TickerMode('));
      expect(homeScreen, contains('_profileRefreshToken'));
      expect(homeScreen, contains('MyProfileScreen(refreshToken:'));
      expect(homeScreen, contains('final Map<HomeTab, Widget> _tabCache = {};'));
      expect(homeScreen, contains('_ensureTabBuilt'));
      expect(supabaseService, contains('_isSessionUsable'));
      expect(supabaseService, contains('_minimumSessionValidity'));
      expect(supabaseService, contains('_sessionRecoveryInFlight'));
      expect(authCubit, contains('SupabaseService.recoverSession()'));
      expect(authCubit, contains('Never hydrate the authenticated UI'));
      expect(photoService, contains('currentUserIdOrRefresh()'));
      expect(signedUrlFunction, contains('UPLOAD_URL_EXPIRES_IN = 7200'));
      expect(signedUrlFunction, contains('READ_URL_EXPIRES_IN = 300'));
      expect(signedUrlFunction, contains('.getUser(userToken)'));
      expect(
        signedUrlFunction,
        contains('.select("is_banned, deleted_at")'),
      );
      expect(signedUrlFunction, contains('.select("visibility")'));
      expect(signedUrlFunction, isNot(contains('account_status')));
      expect(
        signedUrlFunction,
        isNot(contains('createClient(SUPABASE_URL, SUPABASE_ANON_KEY')),
      );
    });

    test('upload metadata matches Supabase TTL without verbose media logs', () {
      final verification = File(
        'supabase/functions/photo-verification/index.ts',
      ).readAsStringSync();
      expect(verification, contains('URL_TTL_SECONDS = 7200'));
      expect(signedUrlFunction, isNot(contains('console.log(')));
    });
  });
}
