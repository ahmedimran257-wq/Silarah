import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/subscription/subscription_state.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/features/home/widgets/profile_quality_card.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

Widget _host(
  Widget child, {
  bool reduceMotion = false,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    ),
  );
}

class _Calls {
  final steps = <ProfileQualityStep>[];
  int verify = 0;
  int photos = 0;
  int bio = 0;
  int guardian = 0;
}

ProfileQualityCard _card(
  _Calls calls, {
  int score = 83,
  ProfileQualityStep? next = ProfileQualityStep.family,
  bool verified = false,
  int photos = 3,
  int bioLength = 200,
  bool guardian = false,
  bool tips = true,
}) {
  return ProfileQualityCard(
    score: score,
    nextStep: next,
    onNextStep: calls.steps.add,
    avatar: const ColoredBox(color: Colors.transparent),
    name: 'Khatun Khatun',
    subtitle: '25 yrs · Kurnool',
    identityStatus: const Text('identity'),
    tips: tips
        ? ProfileRankTips(
            photoVerified: verified,
            approvedPhotoCount: photos,
            bioLength: bioLength,
            guardianLinked: guardian,
            onVerify: () => calls.verify++,
            onPhotos: () => calls.photos++,
            onBio: () => calls.bio++,
            onGuardian: () => calls.guardian++,
          )
        : null,
  );
}

void main() {
  setUp(() => AppColors.activate(SilarahThemeMode.ivoryEmerald));
  tearDown(() => AppColors.activate(SilarahThemeMode.ivoryEmerald));

  void useTallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(412, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  test('completeness steps keep their order and points sum to 100', () {
    expect(
      ProfileQualityStep.values.fold<int>(0, (sum, s) => sum + s.points),
      100,
    );
    expect(ProfileQualityStep.values.first, ProfileQualityStep.photo);
    expect(ProfileQualityStep.family.points, 10);
    expect(
      ProfileQualityStep.values.where((s) => s.opensPhotos),
      [ProfileQualityStep.photo, ProfileQualityStep.secondPhoto],
    );
  });

  testWidgets('ring counts up to the score and the next step adds points',
      (tester) async {
    useTallPhone(tester);
    final calls = _Calls();
    await tester.pumpWidget(_host(_card(calls)));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('83%'), findsNothing, reason: 'still counting up');

    await tester.pumpAndSettle();
    expect(find.text('83%'), findsOneWidget);
    expect(find.text('Khatun Khatun'), findsOneWidget);
    expect(find.text('Add family background'), findsOneWidget);
    expect(find.text('Next step · reach 93%'), findsOneWidget);
    expect(find.text('+10%'), findsOneWidget);
    expect(find.textContaining('Almost there'), findsOneWidget);
    expect(find.bySemanticsLabel('Profile 83% complete'), findsOneWidget);

    await tester.tap(find.text('Add family background'));
    expect(calls.steps, [ProfileQualityStep.family]);
  });

  testWidgets('each checklist row opens the screen that fixes it',
      (tester) async {
    useTallPhone(tester);
    final calls = _Calls();
    await tester.pumpWidget(_host(_card(calls)));
    await tester.pumpAndSettle();

    expect(
        find.text('What helps you appear higher in Discover'), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget, reason: 'only the bio is done');
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('A trusted face earns more replies'), findsOneWidget);

    await tester.tap(find.text('Verified profile photo'));
    await tester.tap(find.text('Up to 4 approved photos'));
    await tester.tap(find.text('A bio of a few lines'));
    await tester.tap(find.text('Guardian linked'));
    expect(
      [calls.verify, calls.photos, calls.bio, calls.guardian],
      [1, 1, 1, 1],
    );
  });

  testWidgets('the checklist waits for verification status', (tester) async {
    useTallPhone(tester);
    await tester.pumpWidget(_host(_card(_Calls(), tips: false)));
    await tester.pumpAndSettle();
    expect(find.text('What helps you appear higher in Discover'), findsNothing);
    expect(find.text('Add family background'), findsOneWidget);
  });

  testWidgets('a complete profile gets a calm celebration, not a next step',
      (tester) async {
    useTallPhone(tester);
    await tester.pumpWidget(_host(_card(
      _Calls(),
      score: 100,
      next: null,
      verified: true,
      photos: 4,
      guardian: true,
    )));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Your profile is complete'), findsOneWidget);
    expect(find.textContaining('Next step'), findsNothing);
    expect(find.text('4/4'), findsOneWidget);
    expect(find.text('Done'), findsNWidgets(4));
    expect(tester.binding.hasScheduledFrame, isFalse,
        reason: 'the light sweep plays once, never loops');
  });

  testWidgets('a new score animates on from the old one', (tester) async {
    useTallPhone(tester);
    final calls = _Calls();
    await tester.pumpWidget(_host(_card(calls)));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_host(
        _card(calls, score: 93, next: ProfileQualityStep.partnerPreferences)));
    await tester.pump(const Duration(milliseconds: 16));
    final mid = tester
        .widgetList<Text>(find.textContaining('%'))
        .map((t) => t.data)
        .whereType<String>()
        .firstWhere((s) => RegExp(r'^\d+%$').hasMatch(s));
    expect(int.parse(mid.replaceAll('%', '')), inInclusiveRange(83, 93));

    await tester.pumpAndSettle();
    expect(find.text('93%'), findsOneWidget);
    expect(find.text('Set partner preferences'), findsOneWidget);
  });

  testWidgets('reduce motion shows the final state on the first frame',
      (tester) async {
    useTallPhone(tester);
    await tester.pumpWidget(_host(_card(_Calls()), reduceMotion: true));
    await tester.pump();
    expect(find.text('83%'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('copy is localized', (tester) async {
    useTallPhone(tester);
    await tester.pumpWidget(_host(_card(_Calls()), locale: const Locale('hi')));
    await tester.pumpAndSettle();
    expect(find.text('पारिवारिक पृष्ठभूमि जोड़ें'), findsOneWidget);
    expect(find.text('अगला कदम · 93% तक पहुँचें'), findsOneWidget);
  });

  for (final mode in [
    SilarahThemeMode.ivoryEmerald,
    SilarahThemeMode.roseMarigold,
    SilarahThemeMode.oled,
  ]) {
    testWidgets('lays out on a narrow phone in ${mode.name}', (tester) async {
      AppColors.activate(mode);
      tester.view.physicalSize = const Size(360, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(_card(_Calls())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ProfileQualityCard), findsOneWidget);
    });
  }

  test('the Profile tab routes every action where it led before', () {
    final screen = File('lib/features/home/screens/my_profile_screen.dart')
        .readAsStringSync();
    expect(screen, contains('ProfileQualityCard('));
    expect(
      screen,
      contains('step.opensPhotos ? onManagePhotos() : onEditProfile()'),
    );
    expect(screen, contains('onManagePhotos: _openManagePhotos'));
    expect(screen, contains('onEditProfile: _openEditProfile'));
    expect(screen, contains('onGuardian: _openGuardianSettings'));
    expect(screen, contains('onVerify: onVerify'));
    expect(screen, isNot(contains('to reach \${score')));
  });

  group('ProfileMembershipStrip', () {
    testWidgets('shows the date and opens the manage action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        ProfileMembershipStrip(
          detail: 'Renews 9 Nov 2026',
          actionLabel: 'Manage or cancel',
          onTap: () => taps++,
        ),
        reduceMotion: true,
      ));
      await tester.pump();

      expect(find.text('Silarah Premium'), findsOneWidget);
      expect(find.text('Renews 9 Nov 2026'), findsOneWidget);
      expect(find.text('Manage or cancel'), findsOneWidget);

      await tester.tap(find.text('Manage or cancel'));
      await tester.pump();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long translations do not overflow on a narrow phone',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(
        ProfileMembershipStrip(
          detail: 'Erneuert sich am 29 Nov 2026',
          actionLabel: 'Verwalten oder verlängern',
          onTap: () {},
        ),
        reduceMotion: true,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  test('renewal state can be cleared when the store has no answer', () {
    const renewing = SubscriptionState(willRenew: true);
    expect(renewing.copyWith().willRenew, isTrue);
    expect(renewing.copyWith(willRenew: false).willRenew, isFalse);
    expect(renewing.copyWith(clearWillRenew: true).willRenew, isNull);
  });
}
