import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Leaving Edit Profile with unsaved edits used to drop them silently. These
// contracts keep the "Discard changes?" prompt wired to every way out.
void main() {
  final source = File('lib/features/home/screens/edit_profile_screen.dart')
      .readAsStringSync();

  test('system back and the back gesture ask before dropping edits', () {
    expect(source, contains('PopScope('));
    expect(source, contains('canPop: _isSaving || !_hasUnsavedChanges'));
    expect(source, contains('_confirmLeave();'));
  });

  test('the on-screen back arrow goes through the same check', () {
    expect(source, contains('onTap: () => Navigator.maybePop(context)'));
    expect(source, isNot(contains('onTap: () => Navigator.pop(context),')));
  });

  test('every editable field and the location count as a change', () {
    for (final field in [
      '_firstNameCtrl',
      '_lastNameCtrl',
      '_professionCtrl',
      '_bioCtrl',
      '_sect',
      '_deenLevel',
      '_praysFive',
      '_hijabStyle',
      '_beardStyle',
      '_educationLabel',
      '_familyType',
      '_siblingCount',
      '_parentsStatus',
      '_marriageTimeline',
      '_willingToRelocate',
      '_partnerAgeMin',
      '_partnerAgeMax',
      '_openToDivorced',
      '_openToWidowed',
      '_openToHasChildren',
      '_openToDiaspora',
      '_interests',
    ]) {
      final snapshot = RegExp(
        r'String _editableSnapshot\(\) => \[(.*?)\]\.join',
        dotAll: true,
      ).firstMatch(source)!.group(1)!;
      expect(snapshot, contains(field), reason: field);
    }
    expect(source, contains('_locationChanged || _editableSnapshot()'));
  });

  test('saving still closes the screen without a prompt', () {
    expect(source, contains('Navigator.pop(context, true);'));
  });
}
