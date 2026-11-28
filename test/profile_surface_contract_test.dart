import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('notifications support owned row deletion and clear-all', () {
    final cubit = File(
      'lib/core/cubits/notifications/notifications_cubit.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/home/screens/notifications_screen.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/119_user_notification_deletion.sql',
    ).readAsStringSync();

    expect(cubit, contains('deleteNotification(String id)'));
    expect(cubit, contains('clearAllNotifications()'));
    expect(cubit, contains(".eq('user_id', me)"));
    expect(screen, contains('Dismissible('));
    expect(screen, contains('Clear all notifications'));
    expect(migration, contains('FOR DELETE'));
    expect(migration, contains('user_id = auth.uid()'));
  });

  test('loading and editor surfaces use the current Silarah system', () {
    final loader = File(
      'lib/core/widgets/loaders/silarah_shimmer.dart',
    ).readAsStringSync();
    final editor = File(
      'lib/features/home/screens/edit_profile_screen.dart',
    ).readAsStringSync();
    final filters = File(
      'lib/features/home/widgets/discovery_filter_sheet.dart',
    ).readAsStringSync();

    expect(loader, contains('class SilarahActivityIndicator'));
    expect(loader, contains('class _SilarahActivityPainter'));
    expect(loader, isNot(contains("assets/icon/app_icon.png")));
    expect(loader, isNot(contains("'م'")));
    expect(loader, contains('Preparing profile recommendations'));
    expect(loader, contains('MediaQuery.disableAnimationsOf(context)'));
    final profileLoader = loader.substring(
      loader.indexOf('class SilarahProfileCardShimmer'),
      loader.indexOf('class SilarahConversationShimmer'),
    );
    expect(
      profileLoader,
      contains('SilarahBreathing('),
      reason: 'The discovery card uses restrained local motion.',
    );
    expect(
      profileLoader,
      isNot(contains('SilarahShimmer(')),
      reason: 'A viewport-sized sweep causes a vertical loading artifact.',
    );
    expect(editor, contains('Save changes'));
    expect(editor, contains('Manage your photos'));
    expect(editor, contains('filled: false'));
    expect(filters, contains('filled: false'));
    expect(filters, contains('BorderRadius.circular(999)'));
  });

  test('premium launcher source exists at store resolution', () {
    final icon = File('assets/icon/app_icon.png');
    expect(icon.existsSync(), isTrue);

    final decoded = img.decodePng(icon.readAsBytesSync());
    expect(decoded, isNotNull);
    expect(decoded!.width, 1024);
    expect(decoded.height, 1024);
    expect(decoded.numChannels, greaterThanOrEqualTo(3));
  });
}
