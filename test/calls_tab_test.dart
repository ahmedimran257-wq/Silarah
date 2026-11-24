// Calls tab, tab names, the calling gate and "How calling works"
// (docs/voice_calling_spec.md 12.5, 12.6, 13).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/core/cubits/chat/chat_cubit.dart';
import 'package:silarah/core/cubits/interests/interests_cubit.dart';
import 'package:silarah/core/router/home_tab.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/features/calls/call_api.dart';
import 'package:silarah/features/calls/call_controller.dart';
import 'package:silarah/features/calls/call_log.dart';
import 'package:silarah/features/calls/call_log_controller.dart';
import 'package:silarah/features/calls/calling_rules.dart';
import 'package:silarah/features/calls/calls_hub.dart';
import 'package:silarah/features/calls/screens/calls_tab_screen.dart';
import 'package:silarah/features/calls/screens/call_screen.dart';
import 'package:silarah/features/calls/widgets/call_return_bar.dart';
import 'package:silarah/features/calls/widgets/calling_guide_sheet.dart';
import 'package:silarah/features/calls/widgets/calls_tab_widgets.dart';
import 'package:silarah/features/home/screens/subscription_screen.dart';
import 'package:silarah/features/home/widgets/silarah_bottom_nav.dart';
import 'package:silarah/l10n/calling_ui_copy.dart';
import 'package:silarah/l10n/ui_copy.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

const _locales = ['en', 'ar', 'bn', 'de', 'fr', 'hi', 'id', 'ms', 'tr', 'ur'];

CallingRules _rules({bool on = true, int limit = 3, int included = 30}) => CallingRules.fromJson({
      'calls_enabled': on,
      'unanswered_call_limit': limit,
      'included_minutes': included,
      'included_period_days': 30,
      'max_call_minutes': 60,
      'ring_seconds': 30,
      'max_pack_refunds': 2,
      'min_minutes_to_call': 1,
      'plan_min_lead_minutes': 10,
      'plan_max_days_ahead': 7,
      'plan_window_minutes': 30,
      'plan_reminder_minutes': 5,
      'plan_max_open': 5,
      'plan_max_per_chat_day': 3,
      'log_retention_months': 12,
    })!;

Map<String, Object?> _row(
  String id,
  DateTime at, {
  String other = 'u1',
  String name = 'Abdul',
  String direction = 'incoming',
  String outcome = 'answered',
  int? talk,
  int? used,
  bool unavailable = false,
  bool unseen = false,
}) =>
    {
      'request_id': id,
      'created_at': at.toUtc().toIso8601String(),
      'direction': direction,
      'outcome': outcome,
      'talk_seconds': talk,
      'minutes_used': used,
      'match_id': 'm-$other',
      'other_user_id': unavailable ? null : other,
      'other_first_name': unavailable ? 'Silarah member' : name,
      'other_last_name': unavailable ? '' : 'A',
      'member_unavailable': unavailable,
      'unseen': unseen,
    };

Widget _app(Widget child, {String locale = 'en', double textScale = 1, GlobalKey? captureKey}) => MaterialApp(
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
      ],
      builder: (context, app) {
        final scaled = MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: app!,
        );
        return captureKey == null ? scaled : RepaintBoundary(key: captureKey, child: scaled);
      },
      home: Scaffold(backgroundColor: AppColors.obsidianNight, body: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('tabs by name (12.5)', () {
    test('names and the old numbers both open the right tab', () {
      expect(HomeTab.parse('calls'), HomeTab.calls);
      expect(HomeTab.parse('chats'), HomeTab.chats);
      expect(HomeTab.parse('3'), HomeTab.profile, reason: 'stored links: 3 = Profile');
      expect(HomeTab.parse('2'), HomeTab.chats);
      expect(HomeTab.parse('4'), isNull);
      expect(HomeTab.parse('nonsense'), isNull);
      expect(HomeTab.calls.path, '/home?tab=calls');
    });
  });

  group('right-to-left copy keeps inserted values in their own direction', () {
    Future<BuildContext> contextFor(WidgetTester tester, String locale) async {
      late BuildContext captured;
      await tester.pumpWidget(_app(Builder(builder: (context) {
        captured = context;
        return const SizedBox.shrink();
      }), locale: locale));
      return captured;
    }

    testWidgets('Urdu: "Today، 10:30 AM" with the time isolated, never "AM 10:30"', (tester) async {
      final context = await contextFor(tester, 'ur');
      final at = DateTime(2026, 11, 24, 10, 30);
      final label = planTimeLabel(context, at, DateTime(2026, 11, 24, 10));
      expect(label, contains('،'), reason: 'the Urdu comma');
      expect(label, contains(isolateBidi('10:30 AM')));
      expect(context.uiCopyWith('You can call again after {time}.', {'time': '10:30 AM'}),
          contains(isolateBidi('10:30 AM')));
    });

    testWidgets('left-to-right copy is unchanged', (tester) async {
      final context = await contextFor(tester, 'en');
      final at = DateTime(2026, 11, 24, 10, 30);
      expect(planTimeLabel(context, at, DateTime(2026, 11, 24, 10)), 'Today, 10:30 AM');
      expect(context.uiCopyWith('You can call again after {time}.', {'time': '10:30 AM'}),
          'You can call again after 10:30 AM.');
    });
  });

  group('history grouping (12.5.5)', () {
    final now = DateTime(2026, 11, 22, 18);
    List<CallLogEntry> entries(List<Map<String, Object?>> rows) =>
        rows.map(CallLogEntry.fromJson).whereType<CallLogEntry>().toList();

    test('consecutive calls with one person on one day collapse with a count', () {
      final sections = groupCallLog(
        entries([
          _row('a', DateTime(2026, 11, 22, 17), outcome: 'missed'),
          _row('b', DateTime(2026, 11, 22, 16), outcome: 'missed'),
          _row('c', DateTime(2026, 11, 22, 15), other: 'u2', name: 'Bilal'),
          _row('d', DateTime(2026, 11, 22, 14)),
        ]),
        now: now,
      );
      expect(sections, hasLength(1));
      expect(sections.single.kind, CallDayKind.today);
      expect(sections.single.rows.map((r) => r.count), [2, 1, 1]);
      expect(sections.single.rows.first.anyMissed, isTrue);
    });

    test('days split rows: Today, Yesterday, this week, earlier', () {
      final sections = groupCallLog(
        entries([
          _row('a', DateTime(2026, 11, 22, 9)),
          _row('b', DateTime(2026, 11, 21, 23)),
          _row('c', DateTime(2026, 11, 18, 9)),
          _row('d', DateTime(2026, 11, 2, 9)),
        ]),
        now: now,
      );
      expect(sections.map((s) => s.kind),
          [CallDayKind.today, CallDayKind.yesterday, CallDayKind.thisWeek, CallDayKind.earlier]);
    });

    test('unavailable members never collapse and show no name', () {
      final list = entries([
        _row('a', DateTime(2026, 11, 22, 17), unavailable: true),
        _row('b', DateTime(2026, 11, 22, 16), unavailable: true),
      ]);
      expect(groupCallLog(list, now: now).single.rows, hasLength(2));
      expect(list.first.otherUserId, isNull);
      expect(list.first.memberUnavailable, isTrue);
    });
  });

  group('planned calls (13)', () {
    final at = DateTime(2026, 11, 22, 20);
    CallPlan plan(String action) => CallPlan.fromJson({
          'id': 'p1',
          'match_id': 'm1',
          'planned_for': at.toUtc().toIso8601String(),
          'status': 'accepted',
          'open': true,
          'i_proposed': false,
          'other_user_id': 'u1',
          'other_first_name': 'Aisha',
          'other_last_name': '',
          'member_unavailable': false,
          'action': action,
        })!;

    test('the call window opens 5 minutes before for the member who may call', () {
      final p = plan('wait_for_time');
      final before = at.subtract(const Duration(minutes: 6));
      final inside = at.subtract(const Duration(minutes: 4));
      expect(p.actionNow(premium: true, female: false, now: before), CallPlanAction.waitForTime);
      expect(p.actionNow(premium: true, female: false, now: inside), CallPlanAction.call);
      expect(p.actionNow(premium: false, female: false, now: inside), CallPlanAction.paywall);
      expect(p.actionNow(premium: false, female: true, now: inside), CallPlanAction.waitForCall);
    });
  });

  group('one source of numbers (12.6)', () {
    test('every guide line fills all its numbers from the server rules', () {
      final values = _rules().copyValues;
      for (final section in callingGuideSections) {
        for (final line in section.lines) {
          for (final ph in RegExp(r'\{([a-z_]+)\}').allMatches(line)) {
            expect(values.containsKey(ph.group(1)), isTrue, reason: '$line: ${ph.group(0)}');
          }
        }
      }
    });

    test('every guide line exists in every language with the same numbers', () {
      for (final code in callingUiCopy.keys) {
        for (final section in callingGuideSections) {
          for (final source in [section.title, ...section.lines]) {
            final translated = callingUiCopy[code]![source];
            expect(translated, isNotNull, reason: '$code: $source');
            for (final ph in RegExp(r'\{[a-z_]+\}').allMatches(source)) {
              expect(translated, contains(ph.group(0)), reason: '$code: $source');
            }
          }
        }
      }
    });

    testWidgets('the guide shows the server\'s numbers, not fixed ones', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      CallsHub.instance.rules.value = _rules(limit: 4, included: 45);
      addTearDown(() => CallsHub.instance.rules.value = null);
      await tester.pumpWidget(_app(const CallingGuideButton()));
      await tester.tap(find.byType(CallingGuideButton));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('4 times without an answer'), findsOneWidget);
      expect(find.textContaining('45 call minutes every 30 days'), findsOneWidget);
    });
  });

  group('Premium screen lists calling only while it is on (12.6)', () {
    for (final code in _locales) {
      for (final female in [false, true]) {
        testWidgets('$code, ${female ? 'women' : 'men'}', (tester) async {
          CallsHub.instance.rules.value = _rules(on: false, included: 45);
          addTearDown(() => CallsHub.instance.rules.value = null);
          await tester.pumpWidget(_app(
            SingleChildScrollView(child: PremiumIncludedFeatures(isFemale: female)),
            locale: code,
          ));
          expect(find.byIcon(Icons.call_outlined), findsNothing, reason: 'switch off: unchanged');
          CallsHub.instance.rules.value = _rules(included: 45);
          await tester.pump();
          expect(find.byIcon(Icons.call_outlined), findsOneWidget);
          final label = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join('\n');
          expect(label, contains('45'), reason: 'minutes come from the server');
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('bottom bar', () {
    for (final code in _locales) {
      testWidgets('five tabs fit 360 dp ($code)', (tester) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => InterestsCubit()),
            BlocProvider(create: (_) => ChatCubit()),
          ],
          child: _app(
            Align(
              alignment: Alignment.bottomCenter,
              child: SilarahBottomNav(
                tabs: HomeTab.values,
                current: HomeTab.calls,
                onTabSelected: (_) {},
              ),
            ),
            locale: code,
          ),
        ));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.call_rounded), findsOneWidget);
      });
    }
  });

  group('Calls tab', () {
    final now = DateTime.now();
    Future<CallsHub> pump(WidgetTester tester, List<Map<String, Object?>> rows,
        {String locale = 'en', TextDirection? direction, double textScale = 1, GlobalKey? captureKey}) async {
      final api = CallApi(
        invoke: (_) async => const {},
        rpc: (name, params) async => switch (name) {
          'get_my_call_log' => rows,
          'get_my_call_plans' => const [],
          _ => null,
        },
      );
      final hub = CallsHub(api: api)
        ..rules.value = _rules()
        ..overview = CallOverview.fromJson(const {
          'calls_enabled': true,
          'premium': true,
          'female': false,
          'included_minutes': 22,
          'included_granted': 30,
          'pack_minutes': 50,
          'available_minutes': 72,
          'can_buy_packs': true,
          'month_talk_seconds': 8100,
          'unseen_missed': 2,
          'plans': [],
        });
      final controller = CallLogController(api: api, photos: (_) async => const {});
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(
        CallsTabScreen(controller: controller, hub: hub),
        locale: locale,
        textScale: textScale,
        captureKey: captureKey,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      return hub;
    }

    testWidgets('minutes, monthly talk time, day groups and collapsed rows', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, [
        _row('a', now, outcome: 'missed', unseen: true),
        _row('b', now.subtract(const Duration(minutes: 1)), outcome: 'missed', unseen: true),
        _row('c', now.subtract(const Duration(minutes: 2)),
            other: 'u2', name: 'Bilal', direction: 'outgoing', talk: 125, used: 3),
      ]);
      expect(find.text('72'), findsOneWidget, reason: 'available minutes');
      expect(find.textContaining('You talked 2 h 15 m this month'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.textContaining('Abdul A. (2)'), findsOneWidget);
      expect(find.textContaining('2:05'), findsOneWidget);
      expect(find.textContaining('3 min used'), findsOneWidget);
      final missedName = tester.widget<Text>(find.textContaining('Abdul A. (2)'));
      expect(missedName.style?.color, AppColors.softCoral, reason: 'missed in the error colour');
    });

    testWidgets('a collapsed row is coloured by the call it shows, the latest', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, [
        // Latest: answered incoming; earlier the same day: a missed call.
        _row('a', now, talk: 77, used: 2),
        _row('b', now.subtract(const Duration(minutes: 1)), outcome: 'missed'),
        // Latest: an outgoing call they did not answer.
        _row('c', now.subtract(const Duration(minutes: 2)), other: 'u2', name: 'Bilal', direction: 'outgoing',
            outcome: 'missed'),
        _row('d', now.subtract(const Duration(minutes: 3)), other: 'u2', name: 'Bilal', outcome: 'missed'),
      ]);
      final answered = tester.widget<Text>(find.textContaining('Abdul A. (2)'));
      expect(answered.style?.color, isNot(AppColors.softCoral), reason: 'shows "Incoming · 1:17"');
      final noAnswer = tester.widget<Text>(find.textContaining('Bilal A. (2)'));
      expect(noAnswer.style?.color, isNot(AppColors.softCoral), reason: 'shows "No answer" on my own call');
    });

    testWidgets('someone who blocked me: "Member unavailable", no photo, no call back', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, [
        _row('a', now, other: 'u9', direction: 'outgoing', outcome: 'answered', talk: 90, used: 2, unavailable: true),
        _row('b', now.subtract(const Duration(hours: 1)), other: 'u2', name: 'Bilal', direction: 'outgoing',
            outcome: 'answered', talk: 60, used: 1),
      ]);
      expect(find.textContaining('Member unavailable'), findsOneWidget);
      expect(find.textContaining('Silarah member'), findsNothing);
      expect(find.byIcon(Icons.call_outlined), findsOneWidget, reason: 'only the available member has a call-back button');
    });

    testWidgets('empty history explains itself', (tester) async {
      await pump(tester, const []);
      expect(find.text('Your calls will appear here'), findsOneWidget);
    });

    // Gate 13: the largest system font (Android's 200%) at 360 dp, in every
    // language. The bottom bar ignores font scaling; the tab's content scales.
    for (final code in _locales) {
      testWidgets('largest font at 360 dp ($code)', (tester) async {
        tester.view.physicalSize = const Size(360, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pump(tester, [
          _row('a', now, outcome: 'missed', name: 'Abdulrahman Mohammed Al-Farouqi', unseen: true),
          _row('b', now.subtract(const Duration(minutes: 5)),
              other: 'u2', name: 'Bilal', direction: 'outgoing', talk: 3599, used: 60),
          _row('c', now.subtract(const Duration(days: 1)), unavailable: true),
        ], locale: code, textScale: 2);
        expect(tester.takeException(), isNull);
        expect(find.byType(CallsTabScreen), findsOneWidget);
      });
    }

    testWidgets('screenshots for the gate 13 record', (tester) async {
      final output = Platform.environment['SILARAH_CALLS_CAPTURE'];
      if (output == null) return;
      await tester.runAsync(() async {
        for (final family in ['Inter', 'PlayfairDisplay']) {
          await (FontLoader(family)..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
        }
        await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
            .load();
      });
      Future<void> shot(String name, {required String locale, double textScale = 1}) async {
        final capture = GlobalKey();
        tester.view.physicalSize = const Size(360, 1500);
        tester.view.devicePixelRatio = 1;
        await pump(tester, [
          _row('a', now, outcome: 'missed', name: 'Abdulrahman', unseen: true),
          _row('b', now.subtract(const Duration(minutes: 5)),
              other: 'u2', name: 'Bilal', direction: 'outgoing', talk: 125, used: 3),
          _row('c', now.subtract(const Duration(days: 1)), unavailable: true),
        ], locale: locale, textScale: textScale, captureKey: capture);
        expect(tester.takeException(), isNull);
        final boundary = capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$output/$name.png').writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      addTearDown(tester.view.reset);
      addTearDown(() => AppColors.activate(SilarahThemeMode.values.first));
      for (final mode in SilarahThemeMode.values) {
        AppColors.activate(mode);
        await shot('theme_${mode.name}', locale: 'en');
      }
      AppColors.activate(SilarahThemeMode.values.first);
      // Latin-script languages: the test renderer has their glyphs.
      for (final code in ['en', 'de', 'fr', 'id', 'ms', 'tr']) {
        await shot('font200_$code', locale: code, textScale: 2);
      }
    });

    for (final mode in SilarahThemeMode.values) {
      for (final code in ['en', 'ar', 'ur']) {
        testWidgets('renders in ${mode.name} ($code)', (tester) async {
          AppColors.activate(mode);
          addTearDown(() => AppColors.activate(SilarahThemeMode.values.first));
          tester.view.physicalSize = const Size(360, 1400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await pump(tester, [
            _row('a', now, outcome: 'missed', name: 'Abdulrahman Mohammed Al-Farouqi'),
            _row('b', now.subtract(const Duration(days: 1)), unavailable: true),
          ], locale: code);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('return-to-call bar (12.1)', () {
    test('shows for a ringing-out, connecting or live call off the call screen only', () {
      final call = CallController(api: CallApi(invoke: (_) async => const {}, rpc: (_, __) async => null));
      expect(CallReturnBarHost.showsFor(call, screenOpen: false), isFalse, reason: 'idle');
      for (final phase in [CallPhase.outgoing, CallPhase.connecting, CallPhase.active]) {
        call.phase = phase;
        expect(CallReturnBarHost.showsFor(call, screenOpen: false), isTrue, reason: '$phase');
        expect(CallReturnBarHost.showsFor(call, screenOpen: true), isFalse, reason: '$phase on screen');
      }
      call.phase = CallPhase.incoming;
      expect(CallReturnBarHost.showsFor(call, screenOpen: false), isFalse, reason: 'the ring has its own screen');
    });

    testWidgets('the app below keeps its state when the bar appears', (tester) async {
      final call = CallController(api: CallApi(invoke: (_) async => const {}, rpc: (_, __) async => null));
      final key = GlobalKey<_CounterState>();
      await tester.pumpWidget(_app(CallReturnBarHost(
        controller: call,
        onOpenCall: () {},
        child: _Counter(key: key),
      )));
      key.currentState!.value = 7;
      call
        ..phase = CallPhase.outgoing
        ..otherName = 'Aisha';
      // Any change the bar listens to redraws it.
      CallScreen.openCount.value++;
      CallScreen.openCount.value--;
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Aisha · Calling'), findsOneWidget);
      expect(key.currentState!.value, 7);
    });
  });

  group('minutes card copy uses the server numbers', () {
    testWidgets('free member: included minutes from the rules', (tester) async {
      await tester.pumpWidget(_app(CallMinutesCard(
        overview: CallOverview.fromJson(const {'premium': false, 'female': true, 'plans': []}),
        includedMinutes: 45,
        onTopUp: () {},
        onPremium: () {},
      )));
      expect(find.textContaining('45 minutes every month'), findsOneWidget);
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int value = 0;

  @override
  Widget build(BuildContext context) => Text('$value');
}
