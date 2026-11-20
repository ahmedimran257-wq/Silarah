// SILARAH — Content Filter (Shared)
// Detects and redacts contact information, social media handles,
// external links, and phone numbers from user-generated text.
//
// Used in:
//   - Profile/edit surfaces - bio validation
//   • ChatCubit — real-time message filtering (T2)
//   • InterestsCubit — interest note validation (D1)
//
// The server is authoritative (public.chat_safety_check and the profile text
// trigger from migration 318). This filter mirrors its rules so members get
// the explanation before a request is sent, never a vague save failure.
class ContentFilter {
  ContentFilter._();

  // Patterns
  static final _phone = RegExp(r'(\+?\d[\d\s\-\.]{6,}\d)');
  static final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
  static final _url = RegExp(r'(https?://|www\.)\S+', caseSensitive: false);
  static final _social = RegExp(
    r'(@[\w.]+|(?:instagram|insta|snap|snapchat|whatsapp|telegram|'
    r'facebook|fb|twitter|tiktok|linkedin)[\s.:/@]*[\w.]+)',
    caseSensitive: false,
  );

  // Bare hosts such as "infosys.com" or "wa.me". "B.Com", "M.Tech" and other
  // one-letter degree abbreviations are not hosts (same rule as the server).
  static final _bareHost = RegExp(
    r'(?:^|[^a-z0-9@._-])([a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.([a-z]{2,24}))'
    r'(?![a-z0-9-])',
    caseSensitive: false,
  );
  static const _knownTlds = {
    'com', 'net', 'org', 'io', 'in', 'co', 'me', 'app', 'info', 'biz', 'xyz',
    'online', 'site', 'website', 'link', 'ly', 'gg', 'to', 'tv', 'us', 'uk',
    'pk', 'bd', 'lk', 'np', 'af', 'ae', 'sa', 'qa', 'om', 'kw', 'bh', 'my',
    'id', 'tr', 'eg', 'ng', 'ke', 'za', 'ca', 'au', 'de', 'fr', 'ru', 'live',
    'shop', 'store', 'club', 'top', 'page', 'dev', 'ai', 'cc', 'ws', 'ml',
    'tk', 'ga', 'cf', 'gq', 'life', 'world', 'chat', 'social', 'email',
    'cloud', 'tech', 'pro', 'mobi', 'name', 'fm', 'am', 'bio', 'gl', 'su',
    'vip', 'one',
  };
  static const _shortHosts = {
    'x.com', 't.co', 'g.co', 't.me', 'm.me', 'wa.me', 'g.page', 'u.to',
    'v.ht', 'j.mp',
  };

  // Validation (returns error message or null)
  /// Returns a human-readable error message if [text] contains
  /// prohibited contact info, or null if the text is clean.
  static String? validate(String text) {
    if (_phone.hasMatch(text) || hasSpelledPhoneNumber(text)) {
      return 'Phone numbers cannot be shared here.';
    }
    if (_email.hasMatch(text)) {
      return 'Email addresses cannot be shared here.';
    }
    if (_url.hasMatch(text) || _hasBareHost(text)) {
      return 'External links cannot be shared here.';
    }
    if (_social.hasMatch(text)) {
      return 'Social media handles cannot be shared here.';
    }
    return null;
  }

  /// Returns true if [text] contains any prohibited content.
  static bool hasViolation(String text) => validate(text) != null;

  // Redaction (replaces violations inline)
  /// Replaces all detected contact info with `[removed]`.
  /// Safe to call on clean text (no-op).
  static String redact(String text) {
    var result = text;
    result = result.replaceAll(_phone, '[contact info removed]');
    result = result.replaceAll(_email, '[contact info removed]');
    result = result.replaceAll(_url, '[link removed]');
    result = result.replaceAll(_social, '[contact info removed]');
    return result;
  }

  static bool _hasBareHost(String text) {
    for (final match in _bareHost.allMatches(text.toLowerCase())) {
      final host = match.group(1)!;
      final labels = host.split('.');
      if (_shortHosts.contains(host)) return true;
      if (!_knownTlds.contains(labels.last)) continue;
      if (labels.length == 2 && labels.first.length == 1) continue;
      return true;
    }
    return false;
  }

  // Spelled-out phone numbers
  //
  // Mirrors public.text_has_spelled_phone_number (migration 318): number
  // words in English, romanised Hindi/Urdu, Arabic, Urdu, Hindi and Bengali
  // (plus "double 7" / "triple 0") are read as digits. A run is a phone
  // number when it holds 10-13 digits and at least one was written as a
  // word, so salaries ("12,00,000") and dates are never refused.

  static const _mark = '\u0001';
  static const _foldFrom = 'أإآٱةىۀہۃھیےک،؛।';
  static const _foldTo = 'ااااهيههههييك,;.';
  static const _letters =
      r'a-z؀-ۿऀ-ॿঀ-৿';
  static final _hasLetter = RegExp('[a-zA-Z؀-ۿऀ-৿]');
  static final _nativeDigits = {
    for (var i = 0; i < 10; i++) ...{
      String.fromCharCode(0x0660 + i): '$i',
      String.fromCharCode(0x06F0 + i): '$i',
      String.fromCharCode(0x0966 + i): '$i',
      String.fromCharCode(0x09E6 + i): '$i',
    },
  };
  static final _arabicMarks = RegExp('[ً-ٟـ]');

  static const _numberWords = <String, String>{
    // English
    'zero': '0', 'oh': '0', 'one': '1', 'two': '2', 'three': '3',
    'four': '4', 'five': '5', 'six': '6', 'seven': '7', 'eight': '8',
    'nine': '9',
    // Romanised Hindi / Urdu
    'shunya': '0', 'sunya': '0', 'shoonya': '0', 'sifar': '0', 'sifr': '0',
    'ek': '1', 'aik': '1', 'do': '2', 'teen': '3', 'tin': '3', 'char': '4',
    'chaar': '4', 'chār': '4', 'panch': '5', 'paanch': '5', 'paach': '5',
    'chhe': '6', 'chhah': '6', 'chhai': '6', 'che': '6', 'chah': '6',
    'cheh': '6', 'saat': '7', 'sat': '7', 'aath': '8', 'aat': '8',
    'aanth': '8', 'nau': '9', 'nao': '9', 'no': '9',
    // Arabic
    'صفر': '0', 'واحد': '1', 'واحده': '1', 'اثنان': '2', 'اثنين': '2',
    'اثنتان': '2', 'ثلاثه': '3', 'ثلاث': '3', 'اربعه': '4', 'اربع': '4',
    'خمسه': '5', 'خمس': '5', 'سته': '6', 'ست': '6', 'سبعه': '7', 'سبع': '7',
    'ثمانيه': '8', 'ثماني': '8', 'ثمان': '8', 'تسعه': '9', 'تسع': '9',
    // Urdu
    'ایک': '1', 'دو': '2', 'تین': '3', 'چار': '4', 'پانچ': '5', 'چھ': '6',
    'چھی': '6', 'سات': '7', 'آٹھ': '8', 'اٹھ': '8', 'نو': '9',
    // Hindi (Devanagari)
    'शून्य': '0', 'सिफ़र': '0', 'एक': '1', 'दो': '2', 'तीन': '3',
    'चार': '4', 'पांच': '5', 'पाँच': '5', 'छह': '6', 'छः': '6', 'छे': '6',
    'सात': '7', 'आठ': '8', 'नौ': '9',
    // Bengali; ya-nukta precomposed (U+09DF) and decomposed (U+09AF U+09BC)
    'শূন্য': '0', 'এক': '1', 'দুই': '2', 'তিন': '3', 'চার': '4',
    'পাঁচ': '5', 'ছয়': '6', 'ছয়': '6',
    'সাত': '7', 'আট': '8', 'নয়': '9', 'নয়': '9',
  };

  static String _fold(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final folded = _foldFrom.indexOf(char);
      buffer.write(
        folded >= 0 ? _foldTo[folded] : (_nativeDigits[char] ?? char),
      );
    }
    return buffer.toString();
  }

  static final Map<String, String> _foldedWords = {
    for (final entry in _numberWords.entries) _fold(entry.key): entry.value,
  };

  static final RegExp _wordPattern = () {
    final words = _foldedWords.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final alternation = words.map(RegExp.escape).join('|');
    return RegExp(
      '(^|[^$_letters])($alternation)(?=[^$_letters]|\$)',
      unicode: true,
    );
  }();

  static final _repeat = RegExp(
    '(^|[^$_letters])(double|dabal|dubal|triple|tripal|tribal)\\s+(\\S+)',
    unicode: true,
  );
  static final _commaAfterWord = RegExp('($_mark[0-9])\\s*,\\s*');
  static final _commaBeforeWord = RegExp('([0-9])\\s*,\\s*($_mark)');
  static final _andBetweenWords = RegExp(
    '($_mark[0-9])\\s+(and|aur|और|و|اور|এবং)\\s+($_mark)',
    unicode: true,
  );
  static final _run = RegExp(
    '($_mark?[0-9](?:[\\s/_.()+*#:;|~=–—-]{0,2}$_mark?[0-9])+)',
  );

  /// True when [text] spells a 10-13 digit phone number with number words,
  /// alone or mixed with digits.
  static bool hasSpelledPhoneNumber(String text) {
    if (!_hasLetter.hasMatch(text)) return false;
    var value = _fold(text.toLowerCase()).replaceAll(_arabicMarks, '');

    value = value.replaceAllMapped(_repeat, (m) {
      final token = m.group(3)!;
      final times = m.group(2)!.startsWith('d') ? 2 : 3;
      return '${m.group(1)}${List.filled(times, token).join(' ')}';
    });
    value = value.replaceAllMapped(
      _wordPattern,
      (m) => '${m.group(1)}$_mark${_foldedWords[m.group(2)]}',
    );
    if (!value.contains(_mark)) return false;

    value = value
        .replaceAllMapped(_commaAfterWord, (m) => '${m.group(1)} ')
        .replaceAllMapped(
            _commaBeforeWord, (m) => '${m.group(1)} ${m.group(2)}')
        .replaceAllMapped(
            _andBetweenWords, (m) => '${m.group(1)} ${m.group(3)}');

    for (final match in _run.allMatches(value)) {
      final run = match.group(1)!;
      if (!run.contains(_mark)) continue;
      final digits = run.replaceAll(RegExp(r'[^0-9]'), '').length;
      if (digits >= 10 && digits <= 13) return true;
    }
    return false;
  }
}
