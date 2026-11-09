import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/block_report/block_report_cubit.dart';
import 'package:silarah/core/cubits/block_report/block_report_state.dart';
import 'package:silarah/features/home/widgets/report_bottom_sheet.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

class _FakeSafetyCubit extends BlockReportCubit {
  final List<String> reported = [];
  final List<String> blocked = [];

  @override
  Future<bool> reportUser({
    required String reportedUserId,
    required String reportedName,
    required ReportReason reason,
    String? description,
  }) async {
    reported.add(reportedUserId);
    return true;
  }

  @override
  Future<bool> blockUser({
    required String userId,
    required String name,
    required String lastInitial,
  }) async {
    blocked.add(userId);
    return true;
  }
}

void main() {
  testWidgets('after a report the member can also block from the same sheet',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final cubit = _FakeSafetyCubit();
    bool? sheetResult;
    await tester.pumpWidget(
      BlocProvider<BlockReportCubit>.value(
        value: cubit,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  sheetResult = await ReportBottomSheet.show(
                    context,
                    reportedUserId: 'member-1',
                    reportedName: 'Amina',
                  );
                },
                child: const Text('report'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('report'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fake Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();
    expect(cubit.reported, ['member-1']);

    final alsoBlock = find.byKey(const ValueKey('report-also-block'));
    expect(alsoBlock, findsOneWidget);
    await tester.tap(alsoBlock);
    await tester.pumpAndSettle();

    expect(cubit.blocked, ['member-1']);
    expect(sheetResult, isTrue);
  });

  test('Premium status is inside the profile card; failed renewals stand apart',
      () {
    final source = File('lib/features/home/screens/my_profile_screen.dart')
        .readAsStringSync();
    final statusAt = source.indexOf('const _SubscriptionCard.status()');
    final qualityAt = source.indexOf('// Profile card preview');
    final upgradeAt = source.indexOf('const _SubscriptionCard.upgrade()');
    expect(statusAt, greaterThan(0));
    // The failed-renewal warning sits above the card; the upsell stays lower.
    expect(statusAt, lessThan(qualityAt));
    expect(upgradeAt, greaterThan(qualityAt));
    expect(source, contains('membership: const _PremiumMembership()'));
    // Only the upgrade prompt is hidden for women; paid status is not gendered.
    expect(
      source,
      contains("state.status != SubscriptionStatus.none || gender == 'female'"),
    );
    expect(source, isNot(contains('!state.includesReferral &&')));
  });

  test('push notifications use a monochrome status-bar icon', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest,
        contains('com.google.firebase.messaging.default_notification_icon'));
    expect(manifest, contains('@drawable/ic_stat_silarah'));
    expect(
      File('android/app/src/main/res/drawable/ic_stat_silarah.xml')
          .existsSync(),
      isTrue,
    );
  });
}
