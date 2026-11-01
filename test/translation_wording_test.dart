import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against wording errors that slipped through machine translation:
/// generator tags shown instead of the app name, the old app name, and the
/// word for bank interest (riba) used where members "send an interest".
void main() {
  final catalogs = _languageCatalogs();

  test('catalogs were found for every shipped language', () {
    expect(catalogs.keys.toSet(),
        {'ar', 'bn', 'de', 'fr', 'hi', 'id', 'ms', 'tr', 'ur'});
  });

  test('no translation-tool tags are shown instead of text', () {
    // e.g. <brand0/>, <marque0/>, <ब्रांड0/>
    final tag = RegExp(r'<[^\s<>/]+\d+/>');
    for (final entry in catalogs.entries) {
      for (final text in entry.value) {
        expect(tag.hasMatch(text), isFalse,
            reason: '${entry.key}: ${tag.firstMatch(text)?.group(0)}');
      }
    }
  });

  test('the app name is spelled Silarah everywhere', () {
    final wrong = RegExp(
      r'Mithaq|MİTHAQ|MITHAQ|ميثاق|मिथाक|মিথা|Silaraa|Silara(?![h])|SILARA(?![H])',
    );
    for (final entry in catalogs.entries) {
      for (final text in entry.value) {
        expect(wrong.hasMatch(text), isFalse,
            reason: '${entry.key}: ${wrong.firstMatch(text)?.group(0)}');
      }
    }
  });

  test('"interest" in a person is never translated as bank interest', () {
    final bankInterest = <String, RegExp>{
      'ar': RegExp('الفائدة'),
      'bn': RegExp(r'সুদ(?:ের| |$)'),
      'de': RegExp('Zinsen'),
      'hi': RegExp('ब्याज'),
      'ms': RegExp('[Ff]aedah'),
      'tr': RegExp('[Ff]aiz'),
      'ur': RegExp(r'(?:^|[\s"])سود(?:[\s۔؟"]|$)'),
    };
    for (final entry in bankInterest.entries) {
      for (final text in catalogs[entry.key]!) {
        expect(entry.value.hasMatch(text), isFalse,
            reason: '${entry.key}: $text');
      }
    }
  });

  test('Arabic never calls a marriage match a sports match', () {
    final sportsMatch = RegExp('مبارا|مباري');
    for (final text in catalogs['ar']!) {
      expect(sportsMatch.hasMatch(text), isFalse, reason: text);
    }
  });
}

/// Every translated string, grouped by language, from the ARB files and the
/// English-keyed Dart copy maps. Dart values are read line by line, which is
/// enough for the token checks above.
Map<String, List<String>> _languageCatalogs() {
  final catalogs = <String, List<String>>{};
  for (final file in Directory('lib/l10n').listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    final lines = file.readAsLinesSync();
    final arb = RegExp(r'^app_([a-z]{2})\.arb$').firstMatch(name);
    if (arb != null) {
      final language = arb.group(1)!;
      if (language == 'en') continue;
      catalogs.putIfAbsent(language, () => []).addAll(lines);
      continue;
    }
    if (!name.endsWith('.dart')) continue;
    final blockStart = RegExp(r"^ {2,4}'([a-z]{2})': \{$");
    String? language;
    for (final line in lines) {
      final start = blockStart.firstMatch(line);
      if (start != null) {
        language = start.group(1) == 'en' ? null : start.group(1);
        continue;
      }
      if (language != null) {
        // Only the translated value: drop an English key on the same line.
        final value = line.contains("': '") || line.contains("': \"")
            ? line.substring(line.indexOf("': ") + 3)
            : line;
        catalogs.putIfAbsent(language, () => []).add(value);
      }
    }
  }
  return catalogs;
}
