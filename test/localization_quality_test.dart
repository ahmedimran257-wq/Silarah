import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/locale/locale_cubit.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';
import 'package:silarah/l10n/ui_copy.dart';
import 'package:silarah/l10n/ui_copy_supplement.dart';

const _completeLocales = {
  'ar',
  'bn',
  'de',
  'en',
  'fr',
  'hi',
  'id',
  'ms',
  'tr',
  'ur',
};

void main() {
  test('only complete production locales are shipped', () {
    final localeCodes = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet();

    expect(localeCodes, _completeLocales);
    expect(LocaleCubit.supportedLanguageCodes, localeCodes);
    expect(Directory('lib/l10n/_phase2_stubs').existsSync(), isFalse);

    final arbFiles = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .map((file) => file.uri.pathSegments.last)
        .toSet();

    expect(
      arbFiles,
      _completeLocales.map((locale) => 'app_$locale.arb').toSet(),
    );
  });

  test('all ARB files contain the same message keys and placeholders', () {
    final english = _messageKeys('lib/l10n/app_en.arb');

    for (final locale in _completeLocales) {
      final path = 'lib/l10n/app_$locale.arb';
      final keys = _messageKeys(path);
      expect(keys.difference(english), isEmpty, reason: path);
      expect(english.difference(keys), isEmpty, reason: path);
      _expectPlaceholdersMatch('lib/l10n/app_en.arb', path);
      _expectNoGeneratorTokens(path);
    }
  });

  test('all statically rendered UI copy is translated in every locale', () {
    final requiredCopy = <String>{
      'ACCOUNT STANDING',
      'Add an approved profile photo before browsing discovery.',
      'All Filters',
      'Account status could not be refreshed.',
      'Check connection',
      'Complete your profile before browsing discovery.',
      'Live in discovery',
      'No internet connection. Connect to open your photo gallery.',
      'No internet connection. Saved content remains available and reconnection is automatic.',
      'No internet connection. Saved profiles remain available and reconnection is automatic.',
      'No internet connection. Showing your last known account status.',
      'Profile not live yet',
      'Please sign in to view discovery profiles.',
      'Profiles are temporarily unavailable. Please try again.',
      'Profiles unavailable',
      'Send Interest Again',
      'Sign in required',
      'Silarah is temporarily unavailable. Saved content remains available and retry is automatic.',
      'Unlock Chat',
      'Unable to load profiles. Please try again.',
      'Your presence on Silarah',
      'Your primary photo must pass the safety scan before discovery.',
      'Your profile must be visible before discovery.',
      "You're offline",
    };
    final directCopy = RegExp(
      r'''(?:UiText|\.uiCopy)\(\s*(["'])(?<text>(?:\\.|(?!\1).)*?)\1''',
      multiLine: true,
      dotAll: true,
    );
    final copyProperty = RegExp(
      r'''(?:label|title|subtitle|body|message|errorMessage|ctaLabel|semanticLabel|hintText|helperText|emptyText|description)\s*:\s*(["'])(?<text>(?:\\.|(?!\1).)*?)\1''',
      multiLine: true,
      dotAll: true,
    );

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      if (normalized.contains('/l10n/') ||
          normalized.endsWith('/language_selection_screen.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final pattern in [directCopy, copyProperty]) {
        for (final match in pattern.allMatches(source)) {
          final value = _decodeDartLiteral(match.namedGroup('text')!);
          if (_isTranslatableUiCopy(value)) requiredCopy.add(value);
        }
      }
    }

    for (final locale in _completeLocales.where((code) => code != 'en')) {
      final missing = requiredCopy
          .where((source) => !UiCopy.hasTranslation(locale, source))
          .toList()
        ..sort();
      expect(missing, isEmpty, reason: '$locale: ${missing.join(' | ')}');
    }
  });

  group('English text that reaches the screen indirectly', () {
    late final _CopyScan scan;
    setUpAll(() => scan = _scanLibForUiCopy());

    test('the scanner resolves ternaries, lists, enums and interpolation', () {
      final probe = _CopyScan();
      _scanSource(probe, r'''
        enum Reason { spam('Looks like spam', 'spam'); const Reason(this.label, this.code); final String label; final String code; }
        Widget a(bool c, Reason r) => Column(children: [
          UiText(c ? 'Ternary one' : 'Ternary two'),
          UiText(c ? foo('not copy') : (c ? 'Nested' : 'Pair')),
          UiText(switch (x) { 'id_value' => 'Switch arm', _ => 'Default arm' }),
          UiText(r.label),
          UiText(local),
          UiText('Report $name'),
          UiText('$age · $city'),
          UiText('https://silarah.com'),
          Semantics(label: c ? 'Loading plans' : 'Plans gone'),
          Tooltip(message: 'Save profile'),
        ]);
        final local = c ? 'Local one' : 'Local two';
        const _reasons = ['Other reason'];
        final rec = ('Rematch in $days days', 1);
        Widget e() => Semantics(label: 'Raw label', child: Text('Raw text'));
        void b() { debugPrint('Never shown to members'); throw StateError('Never shown either'); }
        Widget c() => UiText(reason);
        void d() { state = copyWith(error: 'Prose from a cubit reaches members.'); }
      ''');

      expect(
        probe.required,
        containsAll(<String>{
          'Ternary one',
          'Ternary two',
          'Nested',
          'Pair',
          'Switch arm',
          'Default arm',
          'Looks like spam',
          'Local one',
          'Local two',
          'Loading plans',
          'Plans gone',
          'Save profile',
          'Other reason',
          'Prose from a cubit reaches members.',
        }),
      );
      expect(probe.interpolated, contains('Report \$name'));
      expect(probe.interpolated, contains('Rematch in \$days days'));
      expect(probe.unrouted, containsAll(<String>{'Raw label', 'Raw text'}));
      expect(probe.required, isNot(contains('not copy')));
      expect(probe.required, isNot(contains('id_value')));
      expect(probe.required, isNot(contains('https://silarah.com')));
      expect(probe.required, isNot(contains('Never shown to members')));
      expect(probe.required, isNot(contains('Never shown either')));
      expect(probe.required, isNot(contains('spam')));
      expect(probe.interpolated, isNot(contains('\$age · \$city')));
    });

    test('literals in ternaries, enums, const lists and states are translated',
        () {
      for (final locale in _completeLocales.where((code) => code != 'en')) {
        final missing = scan.required
            .where((source) => !UiCopy.hasTranslation(locale, source))
            .toList()
          ..sort();
        expect(
          missing,
          isEmpty,
          reason: '$locale (${missing.length}):\n${missing.join('\n')}',
        );
      }
    });

    test('catalog keys are never built by interpolation', () {
      final sorted = scan.interpolated.toList()..sort();
      expect(
        sorted,
        isEmpty,
        reason: 'A catalog key cannot contain a runtime value, so this text '
            'never translates. Use a {placeholder} key with uiCopyWith:\n'
            '${sorted.join('\n')}',
      );
    });

    test('Text, Semantics and Tooltip never show a literal directly', () {
      final sorted = scan.unrouted.toList()..sort();
      expect(
        sorted,
        isEmpty,
        reason: 'Wrap these with context.uiCopy or use UiText:\n'
            '${sorted.join('\n')}',
      );
    });

    test('{placeholders} in catalog keys survive translation', () {
      final placeholder = RegExp(r'\{[A-Za-z_][A-Za-z0-9_]*\}');
      Set<String> names(String text) =>
          placeholder.allMatches(text).map((m) => m.group(0)!).toSet();
      for (final locale in _completeLocales.where((code) => code != 'en')) {
        supplementalUiCopy[locale]!.forEach((source, translated) {
          expect(names(translated), names(source),
              reason: '$locale: $source -> $translated');
        });
      }
    });
  });

  test('supplemental UI catalog is complete and contains no batch markers', () {
    final expectedKeys = supplementalUiCopy['ar']!.keys.toSet();
    for (final locale in _completeLocales.where((code) => code != 'en')) {
      expect(supplementalUiCopy[locale]?.keys.toSet(), expectedKeys,
          reason: locale);
    }
    final source = File('lib/l10n/ui_copy_supplement.dart').readAsStringSync();
    expect(source, isNot(contains('ZZZSILARAH')));
    expect(source, isNot(contains('__PH')));
    expect(source, isNot(contains('PLACEHOLDER')));
  });
}

// ---------------------------------------------------------------------------
// Scanner for copy the two regular expressions above cannot see.
//
// A regular expression only sees a literal placed directly after `UiText(` or
// `uiCopy(`. Real screens pick their text with ternaries, switch expressions,
// local variables, enum fields, record fields and const lists, and cubits
// hand finished sentences to the screen through state. This tokenises each
// source file, so comments and string contents cannot confuse it, then walks
// the expression behind every point where text reaches a member.
// ---------------------------------------------------------------------------

/// Files whose literals are not catalog copy: authored proper nouns (country,
/// community, sect and language names), or the official policy text that is
/// published in English and carries its own notice saying so.
const _scanExcludedFiles = <String>{
  'lib/core/data/country_communities_data.dart',
  'lib/core/data/country_data.dart',
  'lib/core/data/country_languages_data.dart',
  'lib/core/data/country_sects_data.dart',
  'lib/core/legal/legal_documents.dart',
  'lib/core/utils/perf_log.dart',
  'lib/features/onboarding/screens/language_selection_screen.dart',
};

/// Sect and school names: authored proper nouns, shown as written.
final _authoredName = RegExp(r'^(?:Sufi|Bohra|Ismaili) \(');

/// Strings the scanner sees that deliberately stay out of the catalog.
const _notCatalogCopy = <String>{
  // Brand names.
  'Silarah',
  'Silarah Premium',

  // Native language names and authored sect and school names.
  'Bahasa Indonesia',
  'Bahasa Melayu',
  'Ahle Hadith',
  'Ahle Sunnat',
  'Ahmadiyya Muslim',
  'Alawi / Alevi',
  'Gülen Movement',
  'Hanafi (traditional)',
  'Ithna Ashari (Twelver)',
  'Jamiat Ulema-e-Hind',
  'Muslim Brotherhood',
  'Nahdlatul Ulama',
  'Progressive Muslim',
  'Tablighi Jamaat',
  'Traditional Sunni',

  // Painted on the launch animation beside its Arabic form.
  'Assalamu Alaikum',

  // Shown when the app itself failed, with no Localizations above them.
  'Something went wrong',
  'This screen update was interrupted. Go back once and reopen it.',
  'Silarah could not start',
  'This build is missing required service configuration. Please reinstall it using the approved build script.',

  // Prefilled support emails, which Silarah staff read.
  'Help with my Silarah account',
  'Tell us what happened and what you expected instead. A screenshot helps.',
  'Safety concern on Silarah',
  'Tell us what happened, who was involved if you know, and when. If anyone is in immediate danger, contact local emergency services first.',
  'Formal grievance',
  'Describe your grievance and the outcome you are asking for. We acknowledge every grievance within 24 hours.',
  'Assalamu alaikum Silarah team,',
  'Please never send OTP codes, passwords or card details.',

  // Contents of the personal data archive, built without a screen.
  'All currently accessible profile photos were included.',
  'My Silarah data export',
  'Private account archive. Store it securely and share it only with people you trust.',
};

/// Interpolated text that deliberately stays out of the catalog.
const _notCatalogTemplates = <String>{
  // Rewritten to its {name} catalog key before it is shown.
  r'$name ended this match.',

  // Never shown: the error's own text, an unused method, and archive contents.
  r'Auth profile hydration failed: $cause',
  r'Join Silarah — the most trusted Muslim matrimony app. '
      r'Use my referral code: $code'
      '\n\n'
      r'Download: ${PublicSiteLinks.origin}',
  r'Photo slot ${entry.key + 1} could not be added.',

  // In a prefilled support email, which Silarah staff read.
  r'Member reference: ${memberId.substring(0, 8)}',

  // Opening messages: the chosen text is sent as written to the other member,
  // so translating it here would change what is delivered.
  r'Assalamu Alaikum $name! I came across your profile and was genuinely impressed. May I introduce myself?',
  r'Bismillah. Your profile caught my attention, $name. I would love to learn more about you.',
  r'Assalamu Alaikum $name. I believe we share similar values. Would you be open to getting to know each other?',
  r'Assalamu Alaikum $name! Your dedication to deen resonated with me. May Allah bless this conversation with goodness.',
};

/// Named arguments that carry member-visible text.
const _copyArguments = <String>{
  'actionLabel',
  'answer',
  'body',
  'closureMessage',
  'confirmLabel',
  'ctaLabel',
  'description',
  'detail',
  'emptyText',
  'error',
  'errorMessage',
  'errorText',
  'headerTitle',
  'helperText',
  'hint',
  'hintText',
  'label',
  'labelText',
  'message',
  'question',
  'semanticLabel',
  'semanticsLabel',
  'status',
  'subtitle',
  'successMessage',
  'syncError',
  'title',
  'tooltip',
};

/// Named arguments and variables that hold lists of member-visible labels.
final _labelListName = RegExp(
  r'^_?(?:labels|optionLabels|options|reasons|features|benefits)$',
  caseSensitive: false,
);

/// Calls whose string arguments are compared, logged or sent somewhere other
/// than the screen. A literal inside one of these is never UI copy.
const _nonUiCalls = <String>{
  'ArgumentError',
  'AssertionError',
  'Exception',
  'FormatException',
  'Key',
  'RegExp',
  'StateError',
  'UnsupportedError',
  'ValueKey',
  'assert',
  'channel',
  'contains',
  'containsKey',
  'debugPrint',
  'endsWith',
  'eq',
  'from',
  'fromEnvironment',
  'getBool',
  'getString',
  'getStringList',
  'hasMatch',
  'insert',
  'invokeMethod',
  'log',
  'neq',
  'or',
  'order',
  'perfMark',
  'print',
  'remove',
  'replaceAll',
  'replaceFirst',
  'rpc',
  'select',
  'setBool',
  'setString',
  'setStringList',
  'split',
  'startsWith',
  'update',
  'upsert',
  'value',
};

class _Token {
  const _Token(this.kind, this.text, this.interpolated);

  final String kind; // 'id', 'str', or 'p'
  final String text;
  final bool interpolated;

  bool get isString => kind == 'str';
  bool isP(String value) => kind == 'p' && text == value;
  bool isId(String value) => kind == 'id' && text == value;
}

class _CopyScan {
  final Set<String> required = {};
  final Set<String> interpolated = {};
  final Set<String> unrouted = {};
}

_CopyScan _scanLibForUiCopy() {
  final scan = _CopyScan();
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final normalized = entity.path.replaceAll('\\', '/');
    if (normalized.contains('/l10n/') ||
        _scanExcludedFiles.contains(normalized)) {
      continue;
    }
    _scanSource(scan, entity.readAsStringSync());
  }
  return scan;
}

void _scanSource(_CopyScan scan, String source) {
  final tokens = _tokenize(source);

  void record(_Token token) {
    if (token.interpolated) {
      if (_hasEnglishOutsideInterpolation(token.text) &&
          !_notCatalogTemplates.contains(token.text)) {
        scan.interpolated.add(token.text);
      }
      return;
    }
    final value = token.text;
    if (_isTranslatableUiCopy(value) &&
        !_looksLikeNonCopy(value) &&
        !_notCatalogCopy.contains(value) &&
        !_authoredName.hasMatch(value)) {
      scan.required.add(value);
    }
  }

  // Every declaration in the file, so `UiText(label)` can see what `label` is.
  final assignedTo = <String, List<int>>{};
  for (var i = 0; i + 1 < tokens.length; i++) {
    if (tokens[i].kind != 'id') continue;
    final next = tokens[i + 1];
    if (next.isP('=') || next.isP('=>') || next.isP('??=')) {
      (assignedTo[tokens[i].text] ??= []).add(i + 2);
    }
  }

  void resolve(String name, Set<String> seen) {
    if (!seen.add(name)) return;
    for (final start in assignedTo[name] ?? const <int>[]) {
      for (final token in _literalsOfExpression(tokens, start)) {
        record(token);
      }
    }
  }

  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];

    // A plain Text, Semantics label or tooltip shows a literal as written.
    if (token.isId('Text') && _at(tokens, i + 1, '(')) {
      for (final literal in _literalsOfExpression(tokens, i + 2)) {
        if (_isTranslatableUiCopy(literal.text) &&
            !_looksLikeNonCopy(literal.text) &&
            !_notCatalogCopy.contains(literal.text)) {
          scan.unrouted.add(literal.text);
        }
      }
    }
    if ((token.isId('Semantics') || token.isId('Tooltip')) &&
        _at(tokens, i + 1, '(')) {
      final close = _matching(tokens, i + 1);
      var depth = 0;
      for (var j = i + 2; j < close; j++) {
        final inner = tokens[j];
        if (inner.isP('(') || inner.isP('[') || inner.isP('{')) depth++;
        if (inner.isP(')') || inner.isP(']') || inner.isP('}')) depth--;
        if (depth == 0 &&
            (inner.isId('label') || inner.isId('message')) &&
            _at(tokens, j + 1, ':')) {
          for (final literal in _literalsOfExpression(tokens, j + 2)) {
            if (_isTranslatableUiCopy(literal.text) &&
                !_looksLikeNonCopy(literal.text) &&
                !_notCatalogCopy.contains(literal.text)) {
              scan.unrouted.add(literal.text);
            }
          }
        }
      }
    }

    // UiText(expr), x.uiCopy(expr), x.uiCopyWith(expr)
    final isUiText = token.isId('UiText') && _at(tokens, i + 1, '(');
    final isUiCopy = (token.isId('uiCopy') || token.isId('uiCopyWith')) &&
        i > 0 &&
        tokens[i - 1].isP('.') &&
        _at(tokens, i + 1, '(');
    if (isUiText || isUiCopy) {
      final start = i + 2;
      for (final literal in _literalsOfExpression(tokens, start)) {
        record(literal);
      }
      // UiText(label) or UiText(reason.label): follow the name.
      final names = _soleReference(tokens, start);
      for (final name in names) {
        resolve(name, <String>{});
      }
      continue;
    }

    // UiCopy.localize(context, expr)
    if (token.isId('localize') &&
        i > 1 &&
        tokens[i - 2].isId('UiCopy') &&
        _at(tokens, i + 1, '(')) {
      final comma = _endOfExpression(tokens, i + 2);
      if (comma < tokens.length && tokens[comma].isP(',')) {
        for (final literal in _literalsOfExpression(tokens, comma + 1)) {
          record(literal);
        }
      }
      continue;
    }

    // tooltip: cond ? 'A' : 'B', error: 'Sentence', and so on.
    if (token.kind == 'id' &&
        _copyArguments.contains(token.text) &&
        _at(tokens, i + 1, ':')) {
      for (final literal in _literalsOfExpression(tokens, i + 2)) {
        record(literal);
      }
      continue;
    }

    // Lists of labels, whether named arguments or local constants.
    if (token.kind == 'id' &&
        _labelListName.hasMatch(token.text) &&
        (_at(tokens, i + 1, ':') || _at(tokens, i + 1, '='))) {
      for (final literal in _literalsOfExpression(tokens, i + 2)) {
        record(literal);
      }
      continue;
    }

    // Names of missing fields handed to the validation snackbar.
    if (token.isId('missing') &&
        _at(tokens, i + 1, '.') &&
        i + 3 < tokens.length &&
        tokens[i + 2].isId('add') &&
        _at(tokens, i + 3, '(')) {
      for (final literal in _literalsOfExpression(tokens, i + 4)) {
        record(literal);
      }
      continue;
    }

    // Enum constants holding text: Reason.spam('Looks like spam', 'spam').
    if (token.isId('enum')) {
      _scanEnum(tokens, i, record);
      continue;
    }

    // Anything else that reads as a sentence is member copy unless it sits in
    // a logging, matching or error-throwing call.
    if (token.isString &&
        (_readsAsProse(token) || _isInterpolatedProse(token)) &&
        !_insideNonUiCall(tokens, i)) {
      record(token);
    }
  }
}

void _scanEnum(
    List<_Token> tokens, int enumIndex, void Function(_Token) record) {
  var i = enumIndex + 1;
  while (i < tokens.length && !tokens[i].isP('{')) {
    i++;
  }
  var depth = 0;
  for (; i < tokens.length; i++) {
    final token = tokens[i];
    if (token.isP('{')) depth++;
    if (token.isP('}') && --depth == 0) return;
    // The constants end at the first `;` at the top level of the enum.
    if (token.isP(';') && depth == 1) return;
    if (token.isString) record(token);
  }
}

bool _at(List<_Token> tokens, int index, String punctuation) =>
    index < tokens.length && tokens[index].isP(punctuation);

/// Index of the token that ends the expression beginning at [start].
int _endOfExpression(List<_Token> tokens, int start) {
  var depth = 0;
  for (var i = start; i < tokens.length; i++) {
    final token = tokens[i];
    if (token.isP('(') || token.isP('[') || token.isP('{')) depth++;
    if (token.isP(')') || token.isP(']') || token.isP('}')) {
      if (depth == 0) return i;
      depth--;
    }
    if (depth == 0 && (token.isP(',') || token.isP(';'))) return i;
  }
  return tokens.length;
}

/// String literals an expression can evaluate to.
///
/// Follows grouping, ternaries, `??`, list and switch arms. Skips arguments of
/// nested calls and operands of comparisons, which are not displayed.
List<_Token> _literalsOfExpression(List<_Token> tokens, int start) {
  final end = _endOfExpression(tokens, start);
  final found = <_Token>[];
  for (var i = start; i < end; i++) {
    final token = tokens[i];

    // Skip the argument list of a call, and an index expression.
    if (token.isP('(') && i > start && _endsCallee(tokens[i - 1])) {
      i = _matching(tokens, i);
      continue;
    }
    if (token.isP('[') && i > start && _endsCallee(tokens[i - 1])) {
      i = _matching(tokens, i);
      continue;
    }

    if (!token.isString) continue;
    final previous = i > start ? tokens[i - 1] : null;
    final next = i + 1 < end ? tokens[i + 1] : null;
    final compared = previous != null &&
        (previous.isP('==') || previous.isP('!=') || previous.isId('case'));
    final isPattern = next != null && (next.isP('=>') || next.isP('=='));
    if (compared || isPattern || (next?.isP('!=') ?? false)) continue;
    found.add(token);
  }
  return found;
}

bool _endsCallee(_Token token) =>
    (token.kind == 'id' && token.text != 'switch' && token.text != 'if') ||
    token.isP('>') ||
    token.isP(')') ||
    token.isP(']');

int _matching(List<_Token> tokens, int open) {
  var depth = 0;
  for (var i = open; i < tokens.length; i++) {
    final token = tokens[i];
    if (token.isP('(') || token.isP('[') || token.isP('{')) depth++;
    if (token.isP(')') || token.isP(']') || token.isP('}')) {
      if (--depth == 0) return i;
    }
  }
  return tokens.length - 1;
}

/// The field or variable name when an argument is only `name` or `a.b.name`.
List<String> _soleReference(List<_Token> tokens, int start) {
  final end = _endOfExpression(tokens, start);
  final parts = tokens.sublist(start, end);
  if (parts.isEmpty) return const [];
  for (var i = 0; i < parts.length; i++) {
    final expected = i.isEven ? parts[i].kind == 'id' : parts[i].isP('.');
    if (!expected) return const [];
  }
  return [parts.last.text];
}

bool _insideNonUiCall(List<_Token> tokens, int index) {
  var depth = 0;
  for (var i = index - 1; i >= 0 && index - i < 80; i--) {
    final token = tokens[i];
    if (token.isP(')') || token.isP(']') || token.isP('}')) depth++;
    if (token.isP('(') || token.isP('[') || token.isP('{')) {
      if (depth > 0) {
        depth--;
      } else if (token.isP('(')) {
        final callee = i > 0 ? tokens[i - 1] : null;
        if (callee == null || callee.kind != 'id') continue;
        if (_nonUiCalls.contains(callee.text)) return true;
        if (i > 1 && tokens[i - 2].isId('throw')) return true;
        return false;
      }
    }
  }
  return false;
}

bool _isInterpolatedProse(_Token token) {
  if (!token.interpolated) return false;
  final stripped = _stripInterpolation(token.text).trim();
  return RegExp(r'[A-Za-z]{2,}\s+[A-Za-z]{2,}').hasMatch(stripped);
}

String _stripInterpolation(String value) => value
    .replaceAll(RegExp(r'\$\{[^}]*\}+'), ' ')
    .replaceAll(RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*'), ' ');

bool _readsAsProse(_Token token) {
  final value = token.text;
  if (token.interpolated) return false;
  if (!RegExp(r'^[A-Z]').hasMatch(value)) return false;
  if (!value.contains(' ') || !RegExp(r'[a-z]').hasMatch(value)) return false;
  if (value.contains('_') || value.contains('://')) return false;
  return RegExp(r'[a-z]{2,}\s+\S').hasMatch(value);
}

/// True for ids, routes, column lists, formats and other strings that merely
/// happen to contain letters.
bool _looksLikeNonCopy(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return true;
  if (trimmed.contains('://') || trimmed.startsWith('/')) return true;
  if (RegExp(r'^[^@\s]+@[^@\s]+$').hasMatch(trimmed)) return true; // an email
  if (trimmed.startsWith('assets/') || trimmed.startsWith('package:')) {
    return true;
  }
  if (RegExp(r'^[a-z0-9_.\-:/,]+$').hasMatch(trimmed)) return true;
  if (RegExp(r'^[A-Z0-9_]+$').hasMatch(trimmed)) return true; // CONSTANT_ID
  if (RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(trimmed)) return true; // camelId
  return false;
}

/// True when text remains once the runtime values are removed, meaning English
/// words are being glued to data outside the catalog.
bool _hasEnglishOutsideInterpolation(String value) {
  final stripped = _stripInterpolation(value);
  if (stripped.contains('://') || stripped.contains('@')) return false;
  final words = RegExp(r'[A-Za-z]{2,}')
      .allMatches(stripped)
      .map((match) => match.group(0)!)
      .where((word) => !const {
            'cm',
            'km',
            'ft',
            'in',
            'Silarah',
            'Premium',
          }.contains(word));
  return words.isNotEmpty;
}

List<_Token> _tokenize(String source) {
  final tokens = <_Token>[];
  final idStart = RegExp(r'[A-Za-z_$]');
  final idPart = RegExp(r'[A-Za-z0-9_$]');
  const operators = ['??=', '==', '!=', '??', '?.', '=>', '<=', '>='];
  var i = 0;
  while (i < source.length) {
    final char = source[i];
    if (char.trim().isEmpty) {
      i++;
    } else if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      i = end < 0 ? source.length : end;
    } else if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      i = end < 0 ? source.length : end + 2;
    } else if (char == "'" || char == '"' || _isRawStringAt(source, i)) {
      final (text, end, interpolated) = _readString(source, i);
      if (tokens.isNotEmpty && tokens.last.isString) {
        final previous = tokens.removeLast();
        tokens.add(_Token('str', previous.text + text,
            previous.interpolated || interpolated));
      } else {
        tokens.add(_Token('str', text, interpolated));
      }
      i = end;
    } else if (idStart.hasMatch(char)) {
      final start = i;
      while (i < source.length && idPart.hasMatch(source[i])) {
        i++;
      }
      tokens.add(_Token('id', source.substring(start, i), false));
    } else {
      final operator = operators.firstWhere(
        (candidate) => source.startsWith(candidate, i),
        orElse: () => char,
      );
      tokens.add(_Token('p', operator, false));
      i += operator.length;
    }
  }
  return tokens;
}

bool _isRawStringAt(String source, int index) =>
    source[index] == 'r' &&
    index + 1 < source.length &&
    (source[index + 1] == "'" || source[index + 1] == '"') &&
    (index == 0 || !RegExp(r'[A-Za-z0-9_$]').hasMatch(source[index - 1]));

/// Reads the string starting at [start]; returns text, end index and whether
/// it contains interpolation. Interpolations are kept as written.
(String, int, bool) _readString(String source, int start) {
  var i = start;
  final raw = source[i] == 'r';
  if (raw) i++;
  final quote = source[i];
  final triple = source.startsWith(quote * 3, i);
  final terminator = triple ? quote * 3 : quote;
  i += terminator.length;
  final out = StringBuffer();
  var interpolated = false;
  while (i < source.length) {
    if (source.startsWith(terminator, i)) {
      i += terminator.length;
      break;
    }
    final char = source[i];
    if (char == r'\' && !raw) {
      final next = source[i + 1];
      const escapes = {'n': '\n', 't': '\t', 'r': '\r'};
      if (next == 'u') {
        final braced = source[i + 2] == '{';
        final from = braced ? i + 3 : i + 2;
        final to = braced ? source.indexOf('}', from) : from + 4;
        out.writeCharCode(int.parse(source.substring(from, to), radix: 16));
        i = braced ? to + 1 : to;
        continue;
      }
      out.write(escapes[next] ?? next);
      i += 2;
      continue;
    }
    if (char == r'$' && !raw && i + 1 < source.length) {
      if (source[i + 1] == '{') {
        interpolated = true;
        final end = _endOfInterpolation(source, i);
        out.write(source.substring(i, end));
        i = end;
        continue;
      }
      if (RegExp(r'[A-Za-z_]').hasMatch(source[i + 1])) {
        interpolated = true;
        var end = i + 1;
        while (end < source.length &&
            RegExp(r'[A-Za-z0-9_]').hasMatch(source[end])) {
          end++;
        }
        out.write(source.substring(i, end));
        i = end;
        continue;
      }
    }
    out.write(char);
    i++;
  }
  return (out.toString(), i, interpolated);
}

int _endOfInterpolation(String source, int dollar) {
  var depth = 0;
  var i = dollar + 1;
  while (i < source.length) {
    final char = source[i];
    if (char == "'" || char == '"' || _isRawStringAt(source, i)) {
      final (_, end, _) = _readString(source, i);
      i = end;
      continue;
    }
    if (char == '{') depth++;
    if (char == '}' && --depth == 0) return i + 1;
    i++;
  }
  return source.length;
}

bool _isTranslatableUiCopy(String value) {
  if (value.contains(r'$') || !RegExp(r'[A-Za-z]').hasMatch(value)) {
    return false;
  }
  if (RegExp(r'^\d+(?:\.\d+)?%?$').hasMatch(value.trim())) return false;
  if (value == 'SILARAH' || value.contains('@silarah.com')) return false;
  return value.length <= 500;
}

String _decodeDartLiteral(String value) => value
    .replaceAll(r'\n', '\n')
    .replaceAll(r"\'", "'")
    .replaceAll(r'\"', '"')
    .replaceAll(r'\\', r'\');

Set<String> _messageKeys(String path) {
  final data =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return data.keys.where((key) => !key.startsWith('@')).toSet();
}

void _expectPlaceholdersMatch(String sourcePath, String localePath) {
  final source =
      jsonDecode(File(sourcePath).readAsStringSync()) as Map<String, dynamic>;
  final locale =
      jsonDecode(File(localePath).readAsStringSync()) as Map<String, dynamic>;
  final placeholder = RegExp(r'\{[A-Za-z_][A-Za-z0-9_]*\}');

  for (final entry in source.entries) {
    if (entry.key.startsWith('@')) continue;
    final sourcePlaceholders =
        placeholder.allMatches('${entry.value}').map((m) => m.group(0)).toSet();
    final localePlaceholders = placeholder
        .allMatches('${locale[entry.key]}')
        .map((m) => m.group(0))
        .toSet();
    expect(localePlaceholders, sourcePlaceholders,
        reason: '$localePath:${entry.key}');
  }
}

void _expectNoGeneratorTokens(String localePath) {
  final text = File(localePath).readAsStringSync();
  expect(text.contains('<ph'), isFalse, reason: localePath);
  expect(text.contains('brand0'), isFalse, reason: localePath);
  expect(text.contains('PLACEHOLDER'), isFalse, reason: localePath);
}
