import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/core/cubits/block_report/block_report_cubit.dart';
import 'package:silarah/core/cubits/interests/interests_cubit.dart';
import 'package:silarah/core/models/discovery_profile.dart';
import 'package:silarah/features/home/screens/profile_detail_screen.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

class _RecordingBlockCubit extends BlockReportCubit {
  final List<String> blocked = [];

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
  const profile = DiscoveryProfile(
    id: '00000000-0000-0000-0000-000000000456',
    firstName: 'Amina',
    lastNameInitial: 'K',
    age: 27,
    cityName: 'Hyderabad',
  );

  Future<_RecordingBlockCubit> openBlockDialog(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final blockCubit = _RecordingBlockCubit();
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => InterestsCubit()),
          BlocProvider<BlockReportCubit>.value(value: blockCubit),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileDetailScreen(
                      profile: profile,
                      heroTag: 'block-test',
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.block_rounded));
    await tester.pumpAndSettle();
    return blockCubit;
  }

  testWidgets('confirming Block in the profile menu blocks the member',
      (tester) async {
    final blockCubit = await openBlockDialog(tester);

    // The sheet is gone; the confirmation dialog is shown.
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(FilledButton),
    ));
    await tester.pumpAndSettle();

    expect(blockCubit.blocked, [profile.id]);
    // The blocked profile leaves the screen.
    expect(find.byType(ProfileDetailScreen), findsNothing);
  });

  testWidgets('cancelling the Block dialog blocks no one', (tester) async {
    final blockCubit = await openBlockDialog(tester);

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextButton),
    ));
    await tester.pumpAndSettle();

    expect(blockCubit.blocked, isEmpty);
    expect(find.byType(ProfileDetailScreen), findsOneWidget);
  });
}
