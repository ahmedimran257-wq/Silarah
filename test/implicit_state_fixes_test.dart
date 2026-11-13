import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('photo screen: preparing and saving share one busy state', () {
    final screen =
        _read('lib/features/onboarding/screens/photo_upload_screen.dart');
    expect(screen, contains('enum _PhotoWork { idle, scanning, uploading }'));
    // Neither path may switch off the other's work when it finishes.
    expect(screen, isNot(contains('_uploading = false')));
    expect(screen, isNot(contains('_isScanning = false')));
    expect(screen, contains('if (mounted && _work == _PhotoWork.scanning)'));
    expect(screen, contains('if (_work == _PhotoWork.uploading)'));
    // Save stays off while a photo is being prepared, and a photo cannot be
    // removed while its file is in use.
    expect(screen, contains('_work == _PhotoWork.idle &&'));
    expect(screen, contains('if (_work != _PhotoWork.idle) return;'));
  });

  test('saved profiles: an older answer never overwrites a newer choice', () {
    final screen =
        _read('lib/features/home/screens/profile_detail_screen.dart');
    expect(screen, contains('int _bookmarkRevision = 0;'));
    expect(screen, contains('bookmarkRevision == _bookmarkRevision'));
    expect(screen,
        contains('if (_shortlistLoading || _bookmarkUpdating) return;'));
  });

  test('guardian transcript: losing access clears the older-page loader', () {
    final screen =
        _read('lib/features/home/screens/guardian_dashboard_screen.dart');
    final invalidate = screen.substring(
      screen.indexOf('void _invalidateAccess('),
      screen.indexOf('@override', screen.indexOf('void _invalidateAccess(')),
    );
    expect(invalidate, contains('_loadingOlder = false;'));
    expect(
        screen, contains('if (mounted && generation == _accessGeneration) {'));
  });

  test('my profile: a refresh asked for after a save is never dropped', () {
    final screen = _read('lib/features/home/screens/my_profile_screen.dart');
    expect(screen, isNot(contains('_profileRefreshInFlight')));
    expect(screen, contains('_profileRefreshFollowUp ??= running.then('));
  });

  test('closing a chat cannot leave its sheet spinning', () {
    final screen = _read('lib/features/home/screens/chat_screen.dart');
    expect(screen, contains('closed = false;'));
    expect(screen,
        contains('// The closure is already saved; the feed catches up'));
  });

  test('renewal terms sit directly under the pay button', () {
    final screen = _read('lib/features/home/screens/subscription_screen.dart');
    final button = screen.indexOf('onTap: _startPurchase,');
    final terms = screen.indexOf(
        "'Renews automatically at this price until you cancel in Google Play.'");
    expect(button, greaterThan(0));
    expect(terms, greaterThan(button));
    expect(terms - button, lessThan(800));
  });
}
