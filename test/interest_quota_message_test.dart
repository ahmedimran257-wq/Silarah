import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/interests/interests_cubit.dart';
import 'package:silarah/core/cubits/interests/interests_state.dart';

void main() {
  test('a failed background allowance refresh does not alert the member',
      () async {
    final cubit = InterestsCubit();
    addTearDown(cubit.close);

    // No session in tests, so the server read fails like an offline moment.
    await cubit.refreshQuota();

    expect(cubit.state.quotaUnavailable, isTrue);
    expect(cubit.state.quotaCheckFailed, isFalse);
  });

  test('a failed check while starting an interest is surfaced once', () async {
    final cubit = InterestsCubit();
    addTearDown(cubit.close);

    final allowed = await cubit.canStartInterest();

    expect(allowed, isFalse);
    expect(cubit.state.quotaCheckFailed, isTrue);

    cubit.clearQuotaUnavailable();
    expect(cubit.state.quotaCheckFailed, isFalse);
    expect(cubit.state.quotaUnavailable, isFalse);
  });

  test('home screen alerts only on a member-initiated failed check', () {
    final home = File('lib/features/home/home_screen.dart').readAsStringSync();
    expect(home,
        contains('(!previous.quotaCheckFailed && current.quotaCheckFailed)'));
    expect(
        home,
        isNot(contains(
            '(!previous.quotaUnavailable && current.quotaUnavailable)')));
  });

  test('state equality includes the new flag', () {
    const a = InterestsState();
    final b = a.copyWith(quotaCheckFailed: true);
    expect(a == b, isFalse);
  });
}
