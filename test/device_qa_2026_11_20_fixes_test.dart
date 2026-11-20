// Fixes from the release-APK device test of 20 Nov 2026
// (docs/device_test_checklist_2026-11-20.md).
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/block_report/block_report_state.dart';
import 'package:silarah/core/utils/notification_deep_link.dart';
import 'package:silarah/features/home/widgets/discovery_filter_sheet.dart';
import 'package:silarah/l10n/ui_copy.dart';
import 'package:silarah/l10n/ui_copy_supplement.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('filter chips show labels, not stored values', () {
    expect(discoveryFacetLabel('shia'), 'Shia');
    expect(discoveryFacetLabel('sunni'), 'Sunni');
    expect(discoveryFacetLabel('prefer_not_to_say'), 'Prefer not to say');
    expect(discoveryFacetLabel('joint'), 'Joint');
    final bar = read('lib/features/home/widgets/discovery_filter_bar.dart');
    expect(bar, contains('discoveryFacetLabel(f.sect!)'));
    expect(bar, contains('discoveryFacetLabel(f.familyType!)'));
  });

  test('Latin-only text keeps its punctuation in Arabic and Urdu layouts', () {
    expect(UiText.needsLtrRun('Khatun K.', TextDirection.rtl), isTrue);
    expect(UiText.needsLtrRun('Khatun K.', TextDirection.ltr), isFalse);
    // Arabic or mixed text is left to the normal bidi algorithm.
    expect(UiText.needsLtrRun('عبدالله ع.', TextDirection.rtl), isFalse);
    expect(UiText.needsLtrRun('اشتراك Premium', TextDirection.rtl), isFalse);
    expect(UiText.needsLtrRun('25', TextDirection.rtl), isFalse);
    // It stays where the RTL layout placed it.
    expect(UiText.mirroredAlign(null), TextAlign.right);
    expect(UiText.mirroredAlign(TextAlign.start), TextAlign.right);
    expect(UiText.mirroredAlign(TextAlign.end), TextAlign.left);
    expect(UiText.mirroredAlign(TextAlign.center), TextAlign.center);
  });

  testWidgets('a Latin name renders left to right inside an RTL layout',
      (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.rtl,
      child: UiText.verbatim('Khatun K.'),
    ));
    final text = tester.widget<Text>(find.text('Khatun K.'));
    expect(text.textDirection, TextDirection.ltr);
    expect(text.textAlign, TextAlign.right);
  });

  test('guardian message notifications open the Guardian dashboard', () {
    expect(
      notificationDestinationPath(
        type: 'guardian_message_mirror',
        deepLink: 'silarah://chat/620208e9-8eae-4d28-9052-ed201116cc69',
      ),
      '/guardian-dashboard',
    );
    expect(
      notificationDestinationPath(
        type: 'guardian_message_mirror',
        deepLink: 'silarah://guardian-dashboard',
      ),
      '/guardian-dashboard',
    );
    // Members still open their own chat.
    expect(
      notificationDestinationPath(
        type: 'new_message',
        deepLink: 'silarah://chat/620208e9-8eae-4d28-9052-ed201116cc69',
      ),
      '/chat/620208e9-8eae-4d28-9052-ed201116cc69',
    );
    final migration =
        read('supabase/migrations/319_guardian_mirror_notification_link.sql');
    expect(migration, contains("'silarah://guardian-dashboard'"));
  });

  test('message reports appear in Report History with their own reason', () {
    final entry = ReportEntry(
      reportId: 'r1',
      reportedUserId: 'u1',
      reportedName: 'Qatest',
      reason: ReportReason.other,
      submittedAt: DateTime(2026, 11, 20),
      isMessageReport: true,
      messageReasonLabel:
          ReportEntry.messageReasonLabels['contact_sharing'],
    );
    expect(entry.reasonLabel, 'Phone, social, or link sharing');
    final cubit = read('lib/core/cubits/block_report/block_report_cubit.dart');
    expect(cubit, contains(".from('message_reports')"));
    // A dismissed message report reopens the chat, so it never hides the
    // member the way a profile report does.
    final messageLoop = cubit.substring(
        cubit.indexOf('// Message reports do not hide the member'));
    expect(messageLoop.substring(0, messageLoop.indexOf('reportHistory.sort')),
        isNot(contains('hiddenIds.add')));
  });

  test('a server Premium grant unlocks an open chat without a restart', () {
    final screen = read('lib/features/home/screens/chat_screen.dart');
    final authorize = screen.substring(
      screen.indexOf('Future<void> _authorizeAndOpen()'),
      screen.indexOf('bool _hasConversation('),
    );
    expect(authorize, contains('_cachedConversationLocked(conversationId)'));
    expect(authorize, contains('refreshForEntitlementChange()'));
    expect(authorize, contains('refreshEntitlement()'));
    final cubit = read('lib/core/cubits/chat/chat_cubit.dart');
    final markRead = cubit.substring(
      cubit.indexOf('Future<void> markRead('),
      cubit.indexOf("'mark_chat_read'"),
    );
    expect(markRead, contains('contentLocked == true) return;'));
  });

  test('a refused message goes back to the composer, never to a retry', () {
    final cubit = read('lib/core/cubits/chat/chat_cubit.dart');
    expect(cubit, contains('String? takeRefusedDraft()'));
    final refuse = cubit.substring(
      cubit.indexOf('void _refuseForSafety('),
      cubit.indexOf('String? takeRefusedDraft()'),
    );
    expect(refuse, contains('m.id != localMessage.id'));
    expect(refuse, isNot(contains('MessageStatus.failed')));
    final screen = read('lib/features/home/screens/chat_screen.dart');
    expect(screen, contains('_chatCubit.takeRefusedDraft()'));
  });

  test('reporting a message reloads the chat into its closed state', () {
    final cubit = read('lib/core/cubits/chat/chat_cubit.dart');
    final report = cubit.substring(
      cubit.indexOf('Future<bool> reportMessage('),
      cubit.indexOf('Future<bool> blockUser('),
    );
    expect(report, contains('loadConversations(showLoading: false, force: true)'));
    final screen = read('lib/features/home/screens/chat_screen.dart');
    expect(screen, contains("reportClosure = 'message_report_submitted'"));
    expect(screen,
        contains('You reported a message. This chat is closed while Silarah reviews it.'));
    // The reported member is never told who closed the chat.
    final list = read('lib/features/home/screens/chat_list_screen.dart');
    expect(list, contains('!reportedClosure'));
  });

  test('members who are Guardians can always get back to their Home', () {
    final dashboard =
        read('lib/features/home/screens/guardian_dashboard_screen.dart');
    expect(dashboard, contains('bool get _isMemberGuardian'));
    expect(dashboard, contains('onPopInvokedWithResult'));
    expect(dashboard, contains("router.go('\${AppRoutes.home}?tab=3')"));
  });

  test('free Profile Views shows the weekly count it promises', () {
    final screen = read('lib/features/home/screens/profile_views_screen.dart');
    expect(screen, contains('activitySummary()'));
    expect(screen, contains('weeklyViewerCount: _weeklyViewerCount'));
  });

  test('profile text contact details are refused on the server too', () {
    final migration = read(
        'supabase/migrations/318_spelled_phone_numbers_and_profile_text_safety.sql');
    expect(migration, contains('CREATE TRIGGER trg_enforce_profile_public_text'));
    expect(migration, contains('public.text_has_spelled_phone_number(v_norm)'));
    final writer = read('lib/core/services/profile_write_service.dart');
    expect(writer, contains("'profile_contact_details_blocked'"));
    expect(
      read('lib/features/home/screens/edit_profile_screen.dart'),
      contains('ProfileWriteService.takeContactDetailsRefusal()'),
    );
  });

  test('photo copy no longer promises reordering', () {
    expect(read('lib/features/home/screens/edit_profile_screen.dart'),
        isNot(contains('Reorder, replace or add photos')));
    for (final locale in supplementalUiCopy.keys) {
      expect(
        supplementalUiCopy[locale]!.containsKey(
            'Replace or add photos. Every new upload runs through the safety scan.'),
        isTrue,
        reason: locale,
      );
    }
  });
}
