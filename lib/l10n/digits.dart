// Numbers in the member's script. Pure Dart: the call notifications use it in
// the background isolate too.

/// Languages whose numbers are shown in their own digits. Arabic shows every
/// number as ٠١٢٣٤٥٦٧٨٩ (owner's rule, 25 Nov 2026); other languages keep the
/// digits as written.
const nativeDigitLanguages = {'ar'};

const _arabicIndicZero = 0x0660;
const _arabicDecimalSeparator = '٫'; // ٫
const _arabicThousandsSeparator = '٬'; // ٬

// A number on its own: digits, with "." or "," only between digits. Digits
// that are part of a word, an email, a link or a code are not numbers to the
// reader and stay as written: "imran8341", "v1.0", "silarah.com/p/12",
// "#3a", "privacy-reference-123".
final _number = RegExp(
  r'(?<![A-Za-z0-9@/\\_#.&=?])(?<![A-Za-z]-)[0-9]+(?:[.,][0-9]+)*(?![A-Za-z0-9@/\\_])(?!-[A-Za-z])',
);

/// [text] with its numbers in [languageCode]'s digits: in Arabic "72" is
/// "٧٢", "9:30" is "٩:٣٠", "12.5" is "١٢٫٥" and "1,299" is "١٬٢٩٩". Unchanged in
/// every other language.
String localizeDigits(String text, String languageCode) {
  if (!nativeDigitLanguages.contains(languageCode)) return text;
  return text.replaceAllMapped(_number, (match) {
    final number = match[0]!;
    final out = StringBuffer();
    for (final unit in number.codeUnits) {
      if (unit >= 0x30 && unit <= 0x39) {
        out.writeCharCode(_arabicIndicZero + unit - 0x30);
      } else {
        out.write(unit == 0x2E ? _arabicDecimalSeparator : _arabicThousandsSeparator);
      }
    }
    return out.toString();
  });
}
