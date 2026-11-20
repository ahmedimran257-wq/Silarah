import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/utils/content_filter.dart';

void main() {
  group('ContentFilter Tests', () {
    test('Clean text passes validation', () {
      expect(ContentFilter.hasViolation('Hello, I am looking for a partner.'),
          isFalse);
      expect(
          ContentFilter.validate('Hello, I am looking for a partner.'), isNull);
    });

    test('Standard phone numbers fail validation', () {
      expect(ContentFilter.hasViolation('My number is +1234567890'), isTrue);
      expect(ContentFilter.hasViolation('Call me at 07123456789'), isTrue);
    });

    test('Dot-separated phone numbers fail validation (A3.1)', () {
      expect(ContentFilter.hasViolation('Reach me at 555.123.4567'), isTrue);
      expect(ContentFilter.validate('Reach me at 555.123.4567'),
          equals('Phone numbers cannot be shared here.'));
    });

    test('Short phone numbers fail validation (A3.1)', () {
      expect(ContentFilter.hasViolation('call me 555 1234'), isTrue);
      expect(ContentFilter.validate('call me 555 1234'),
          equals('Phone numbers cannot be shared here.'));
    });

    // Mirrors migration 318 (public.text_has_spelled_phone_number).
    test('Spelled-out phone numbers fail validation in every script', () {
      const spelled = [
        'nine eight seven six five four three two one zero',
        'Nine, Eight, Seven, Six, Five, Four, Three, Two, One, Zero',
        '98765 four three two one zero',
        '9876 5 4321 zero',
        'nine eight double seven six five four three two one',
        'call me nau aath saat chhe paanch chaar teen do ek shunya',
        'تسعة ثمانية سبعة ستة خمسة أربعة ثلاثة اثنان واحد صفر',
        'نو آٹھ سات چھ پانچ چار تین دو ایک صفر',
        'नौ आठ सात छह पांच चार तीन दो एक शून्य',
        'নয় আট সাত ছয় পাঁচ চার তিন দুই এক শূন্য',
      ];
      for (final text in spelled) {
        expect(ContentFilter.hasSpelledPhoneNumber(text), isTrue,
            reason: text);
        expect(ContentFilter.validate(text),
            equals('Phone numbers cannot be shared here.'),
            reason: text);
      }
    });

    test('Ordinary numbers in words, salaries and dates stay allowed', () {
      const clean = [
        'My salary is 12,00,000-15,00,000 and I have one brother',
        'I was born in 1995, have two sisters and one brother',
        'Five prayers a day, one two three times I read Quran',
        'We are nine siblings, eight live in Kurnool',
        'I want to do it, no problem, sat at home with tin of tea',
        'B.Tech from JNTU, 2018 batch, earning 8 LPA',
      ];
      for (final text in clean) {
        expect(ContentFilter.hasSpelledPhoneNumber(text), isFalse,
            reason: text);
      }
    });

    test('Bare website hosts fail validation, degrees do not', () {
      expect(ContentFilter.validate('Engineer at infosys.com'),
          equals('External links cannot be shared here.'));
      expect(ContentFilter.validate('message me on wa.me'),
          equals('External links cannot be shared here.'));
      expect(ContentFilter.validate('B.Com graduate, M.Tech student'), isNull);
    });

    test('Redaction replaces phone numbers correctly', () {
      const text = 'My number is 555.123.4567 and my friend is at 555 1234';
      final redacted = ContentFilter.redact(text);
      expect(redacted, contains('[contact info removed]'));
      expect(redacted.contains('555.123.4567'), isFalse);
      expect(redacted.contains('555 1234'), isFalse);
    });
  });
}
