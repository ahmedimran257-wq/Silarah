import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/legal/legal_documents.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('location permission and privacy text both say approximate', () {
    final manifest = _read('android/app/src/main/AndroidManifest.xml');
    final location = _read('lib/core/services/location_service.dart');
    final dataSafety = _read('release/data-safety.md');
    final app = LegalDocuments.privacy.sections.map((s) => s.body).join(' ');
    final html = _read('site/privacy/index.html');

    expect(manifest, contains('android.permission.ACCESS_COARSE_LOCATION'));
    expect(
        manifest, isNot(contains('android.permission.ACCESS_FINE_LOCATION')));
    expect(location, contains('LocationAccuracy.low'));
    for (final copy in [app, html]) {
      expect(copy, contains('Approximate device location is requested only'));
      expect(copy, isNot(contains('Precise')));
    }
    expect(dataSafety, contains('| Approximate location |'));
    expect(dataSafety, isNot(contains('precise device location optional')));
  });

  test('public privacy policy names Play Integrity like the app does', () {
    final app = LegalDocuments.privacy.sections.map((s) => s.body).join(' ');
    final html = _read('site/privacy/index.html');
    const disclosure = 'Google Firebase for Play Integrity-backed App Check';
    expect(app, contains(disclosure));
    expect(html, contains(disclosure));
  });

  test('data safety lists sensitive profile data under its own type', () {
    final dataSafety = _read('release/data-safety.md');
    for (final type in [
      '| Political or religious beliefs |',
      '| Race and ethnicity |',
      '| Other financial info |',
    ]) {
      expect(dataSafety, contains(type));
    }
  });

  test('store and site filter claims match the filter sheet', () {
    final sheet =
        _read('lib/features/home/widgets/discovery_filter_sheet.dart');
    expect(sheet, isNot(contains("label: 'MARRIAGE TIMELINE'")));
    expect(sheet, isNot(contains("label: 'PROFESSION'")));

    final english = _read('release/play-store/listing-en-US.md');
    expect(english, isNot(contains('education and marriage intentions')));
    expect(english, isNot(contains('with distance search')));
    expect(english, contains('Premium adds state, city, distance'));

    expect(_read('site/index.html'), isNot(contains('education, profession')));
    expect(
      _read('site/muslim-matrimony-bengaluru/index.html'),
      isNot(contains('career and relocation filters')),
    );
  });

  test('paywall does not promise a search ranking it does not give', () {
    final paywall = _read('lib/features/home/screens/subscription_screen.dart');
    expect(paywall, isNot(contains('Priority in search results')));
    expect(paywall, contains("tooltip: context.uiCopy('Back')"));
  });

  test('delete confirmation always shows the word it accepts', () {
    final screen =
        _read('lib/features/home/screens/delete_account_screen.dart');
    expect(screen, contains("ctrl.text.trim() == 'DELETE'"));
    expect(screen, contains("labelText: 'DELETE'"));
    expect(screen, contains("hintText: 'DELETE'"));
    expect(screen, isNot(contains("uiCopy('Type DELETE here')")));
  });

  test('delete screen is honest about retention and readable on coral', () {
    final screen =
        _read('lib/features/home/screens/delete_account_screen.dart');
    expect(screen, contains('some for 180 days or longer'));
    expect(screen, isNot(contains('All matches, messages, and profile data')));
    expect(screen, isNot(contains('Colors.white')));
    expect(screen, contains('AppColors.readableOn(AppColors.softCoral)'));
    expect(screen, contains("label: context.uiCopy('Back')"));
  });

  test('report sheet does not promise absolute anonymity', () {
    final sheet = _read('lib/features/home/widgets/report_bottom_sheet.dart');
    expect(sheet, isNot(contains('Your report is anonymous')));
    expect(sheet, contains('who reported them'));
  });

  test('safety page and reviewer path match the app', () {
    final safety = _read('site/safety/index.html');
    expect(safety, isNot(contains('conversation menu')));
    expect(safety, isNot(contains('identity badges')));
    expect(safety, contains('long-press one of their messages'));
    expect(
      _read('release/reviewer-instructions.md'),
      contains('**Legal:** Profile → Settings → Legal.'),
    );
  });
}
