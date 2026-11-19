import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// App fixes from the third audit (19 Nov 2026). Each guards a scenario that
// hurt real members: shared phones, flaky networks, failed blocks.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('the next account on a phone never inherits the previous one', () {
    final main = read('lib/main.dart');
    expect(main, contains('_onboardingCubit.reset();'));
    expect(main, contains("prefs.remove('user_country_code')"));
    expect(main, contains('prefs.remove(WaliModeService.pendingInvitationKey)'));
    // Every sign-out, including remote ones, retires the push token.
    expect(main, contains('unawaited(FcmService.instance.onUserLogout());'));
    final auth = read('lib/core/cubits/auth/auth_cubit.dart');
    expect(auth, contains('_syncDeviceCountry(authData)'));
    final fcm = read('lib/core/services/fcm_service.dart');
    expect(fcm, contains('await _messaging.deleteToken();'));
    final reminder = read('lib/core/services/policy_reminder_service.dart');
    expect(reminder, contains(r"${SupabaseService.currentUserId ?? 'signed_out'}"));
  });

  test('a failed profile read can never be saved over the real profile', () {
    final writer = read('lib/core/services/profile_write_service.dart');
    expect(writer, contains('throw ProfileLoadException(error);'));
    final cubit = read('lib/core/cubits/onboarding/onboarding_cubit.dart');
    expect(cubit, contains('on ProfileLoadException catch'));
    expect(cubit, contains('if (!_profileLoaded) {'));
    expect(cubit, contains('void reset() {'));
  });

  test('chat block and report say what really happened', () {
    final cubit = read('lib/core/cubits/chat/chat_cubit.dart');
    expect(cubit, contains('Future<bool> reportMessage('));
    expect(cubit, contains('Future<bool> blockUser('));
    final screen = read('lib/features/home/screens/chat_screen.dart');
    expect(screen, contains("'We could not block this member. Please try again.'"));
    expect(screen, contains("'We could not send this report. Please try again.'"));
    expect(screen, contains('_conversationMissing'));
    expect(screen, contains('maxLength: 2000,'));
  });

  test('smaller fixes stay in place', () {
    expect(read('lib/core/cubits/subscription/subscription_cubit.dart'),
        contains('SubscriptionService.instance.retryPricing()'));
    expect(read('lib/features/home/screens/interests_screen.dart'),
        contains('bool _isResponding(String interestId)'));
    expect(read('lib/core/widgets/cards/silarah_profile_card.dart'),
        contains("label == context.uiCopy('Online now')"));
    expect(read('lib/features/onboarding/screens/photo_upload_screen.dart'),
        contains('AppColors.readableOn(background)'));
    expect(read('lib/features/onboarding/screens/basic_identity_screen.dart'),
        contains('DateTime.now().toUtc()'));
    final edit = read('lib/features/home/screens/edit_profile_screen.dart');
    expect(edit, contains('ContentFilter.validate(text)'));
    expect(edit, contains('maxLength: 40,'));
  });

  test('server functions limit abuse', () {
    final location = read('supabase/functions/location-search/index.ts');
    expect(location, contains('"location_search_daily"'));
    expect(location, contains('"location_resolve"'));
    expect(location, contains('account_unavailable'));
    expect(read('supabase/functions/validate-photo-upload/index.ts'),
        contains('account_unavailable'));
    expect(read('supabase/functions/get-signed-url/index.ts'),
        contains('.gte("created_at", since)'));
  });
}
