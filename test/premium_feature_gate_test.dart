import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/auth/auth_cubit.dart';
import 'package:silarah/core/cubits/auth/auth_state.dart';
import 'package:silarah/core/cubits/subscription/subscription_state.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/features/home/screens/paywall_gate_screen.dart';

// Women message free, so the messaging paywall never shows to them. Premium
// features (the daily profile limit, the private shortlist, compatibility
// insights) are Premium for everyone, and their gate used to be the same
// silent sheet: a woman tapping "Upgrade Now" got no response at all.
void main() {
  Future<BuildContext> pumpFor(WidgetTester tester, String gender) async {
    AppColors.activate(SilarahThemeMode.ivoryEmerald);
    final auth = _SeededAuthCubit(gender);
    addTearDown(auth.close);
    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: auth,
        child: const MaterialApp(home: Scaffold(body: SizedBox())),
      ),
    );
    return tester.element(find.byType(SizedBox).first);
  }

  testWidgets('a woman sees the Premium sheet for a Premium feature',
      (tester) async {
    final context = await pumpFor(tester, 'female');
    PaywallGateSheet.show(context, gate: PremiumGate.feature);
    await tester.pumpAndSettle();
    expect(find.text('Unlock Silarah Premium'), findsOneWidget);
    expect(find.text('Unlimited profile browsing'), findsOneWidget);
    expect(find.text('Continue your conversation'), findsNothing);
    // Only one Premium sheet may be open at a time; close it so the next
    // test starts clean.
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('a woman never sees the messaging paywall', (tester) async {
    final context = await pumpFor(tester, 'female');
    PaywallGateSheet.show(context);
    await tester.pumpAndSettle();
    expect(find.text('Continue your conversation'), findsNothing);
    expect(find.text('Unlock Silarah Premium'), findsNothing);
  });

  testWidgets('a man still gets the messaging paywall for chat',
      (tester) async {
    final context = await pumpFor(tester, 'male');
    PaywallGateSheet.show(context);
    await tester.pumpAndSettle();
    expect(find.text('Continue your conversation'), findsOneWidget);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
  });

  test('every Premium feature entry uses the feature gate', () {
    String read(String path) => File(path).readAsStringSync();
    final discovery = read('lib/features/home/screens/discovery_feed_screen.dart');
    final detail = read('lib/features/home/screens/profile_detail_screen.dart');
    final viewed = read('lib/features/home/screens/viewed_profiles_screen.dart');
    // Daily view limit: opening a profile, saving a card, and the
    // "Upgrade Now" button.
    expect(
      RegExp(r'PaywallGateSheet\.show\(context, gate: PremiumGate\.feature\)')
          .allMatches(discovery)
          .length,
      3,
    );
    // Private shortlist and compatibility insights.
    expect(
      RegExp(r'PaywallGateSheet\.show\(context, gate: PremiumGate\.feature\)')
          .allMatches(detail)
          .length,
      2,
    );
    expect(viewed, contains('gate: PremiumGate.feature'));
  });

  testWidgets('a man sees the Premium sheet for a Premium feature too',
      (tester) async {
    final context = await pumpFor(tester, 'male');
    PaywallGateSheet.show(context, gate: PremiumGate.feature);
    await tester.pumpAndSettle();
    expect(find.text('Unlock Silarah Premium'), findsOneWidget);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
  });

  group('audit fixes, 19 Nov 2026', () {
    String read(String path) => File(path).readAsStringSync();

    test('the free-messaging check is the same for the label and the sheet',
        () {
      const free = SubscriptionState();
      expect(free.canMessage('female'), isTrue);
      expect(free.canMessage(' Female '), isTrue);
      expect(free.canMessage('male'), isFalse);
      expect(free.canMessage(null), isFalse);
      expect(free.canMessage(''), isFalse);
      const paid = SubscriptionState(status: SubscriptionStatus.active);
      expect(paid.canMessage('male'), isTrue);
    });

    test('only a real daily limit opens the Premium sheet', () {
      final cubit = read('lib/core/cubits/discovery/discovery_feed_cubit.dart');
      expect(cubit, contains('enum ProfileViewResult'));
      expect(cubit, contains('return ProfileViewResult.unavailable;'));
      for (final path in [
        'lib/features/home/screens/discovery_feed_screen.dart',
        'lib/features/home/screens/viewed_profiles_screen.dart',
      ]) {
        final screen = read(path);
        expect(screen, contains('result == ProfileViewResult.limitReached'),
            reason: path);
        expect(screen, contains('result == ProfileViewResult.unavailable'),
            reason: path);
      }
    });

    test('a suspension is never shown as a Premium paywall', () {
      final chat = read('lib/features/home/screens/chat_screen.dart');
      expect(chat, contains('? ChatAccessReason.suspended'));
      expect(chat, contains('activating: !suspended && _storePurchaseActive'));
      final list = read('lib/features/home/screens/chat_list_screen.dart');
      expect(list, contains('messagingSuspended && conversation.contentLocked'));
    });

    test('expired Premium is never shown as a purchase still activating', () {
      final chat = read('lib/features/home/screens/chat_screen.dart');
      expect(chat, contains('subscription.hasPaidPremium &&'));
      expect(chat, contains('expiry.isAfter(DateTime.now())'));
      expect(chat,
          contains('context.read<SubscriptionCubit>().refreshEntitlement()'));
    });

    test('a send refused for Premium or suspension refreshes the lock', () {
      final cubit = read('lib/core/cubits/chat/chat_cubit.dart');
      expect(cubit, contains("error.contains('subscription_required')"));
      expect(cubit, contains("error.contains('messaging_suspended')"));
    });

    test('Discover asks the server before any messaging paywall', () {
      final discovery = read('lib/features/home/screens/discovery_feed_screen.dart');
      expect(discovery,
          contains('onTap: () => openChatForProfile(context, profile.profile)'));
    });

    test('women see unlimited browsing on the plans screen', () {
      final plans = read('lib/features/home/screens/subscription_screen.dart');
      final female = plans.substring(plans.indexOf('_femaleFeatures = ['));
      expect(
        female.substring(0, female.indexOf('];')),
        contains('Unlimited profile browsing'),
      );
    });

    test('saving a Discover card counts as a view; unsaving never does', () {
      final discovery = read('lib/features/home/screens/discovery_feed_screen.dart');
      final save = discovery.substring(
          discovery.indexOf('Future<void> _handleBookmark'));
      final recordAt = save.indexOf('_recordVisibleProfileView(id)');
      final writeAt = save.indexOf('BookmarkService.setSaved');
      expect(save, contains('if (!_bookmarked.contains(id)) {'));
      expect(recordAt, greaterThan(0));
      expect(writeAt, greaterThan(recordAt));
      final pending =
          read('supabase/migrations/309_bookmark_needs_counted_view.sql');
      expect(pending, contains('APPLY TOGETHER WITH THE APP BUILD AFTER 42053'));
    });

    test('Discover is always opposite gender; incognito re-checks Premium',
        () {
      final migration =
          read('supabase/migrations/308_discovery_bookmark_incognito_gaps.sql');
      expect(migration, contains(
          r"AND (v_gender_pref IS NULL OR lower(dp.gender::text) = v_gender_pref)"));
      expect(migration,
          contains('PERFORM private.sync_incognito_entitlement(v_row.user_id);'));
    });

    test('Saved and Viewed profiles know about rematch cooldowns', () {
      final loader = read('lib/core/services/authorized_profile_service.dart');
      expect(loader, contains("'get_prior_match_context'"));
      expect(loader, contains('await _addRelationshipContext(mappedRows);'));
    });

    test('guardian approval is explained wherever a chat is opened', () {
      for (final path in [
        'lib/features/home/screens/chat_list_screen.dart',
        'lib/features/home/screens/interests_screen.dart',
        'lib/features/home/screens/profile_detail_screen.dart',
      ]) {
        expect(read(path), contains('ChatAccessReason.guardianApprovalRequired =>'),
            reason: path);
      }
    });

    test('free women get a Premium invitation worded for them', () {
      final card = read('lib/features/home/widgets/profile_quality_card.dart');
      expect(card,
          contains("'Unlimited browsing, private shortlist and profile boosts'"));
    });

    test('guardians read exactly what their member may read', () {
      final migration =
          read('supabase/migrations/307_paywall_gender_gaps.sql');
      expect(migration, contains('public.can_read_guardian_mirror(match_id)'));
      expect(migration,
          contains("= 'female'\n           OR public.has_active_premium(ward.id)"));
      expect(migration, contains('OR v_content_locked THEN NULL'));
      expect(migration, contains("l.action_type = \\'test_premium_revoked\\'"));
      final guardian =
          read('lib/features/home/screens/guardian_dashboard_screen.dart');
      expect(guardian, contains('WaliModeService.needsWardPremium(error)'));
    });
  });
}

class _SeededAuthCubit extends AuthCubit {
  _SeededAuthCubit(String gender) {
    emit(AuthAuthenticated(
      userId: 'test-user',
      onboardingStep: 4,
      gender: gender,
      onboardingCompleted: true,
    ));
  }
}
