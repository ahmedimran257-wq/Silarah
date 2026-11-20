-- 318: spelled-out phone numbers and server-checked profile text
-- (device test, 20 Nov 2026).
--
-- 1. chat_safety_check counted only digits, so "nine eight seven six five four
--    three two one zero" reached the other member as a clean message, and
--    interest notes (same check) let a number through before any match.
--    Number words are now read as digits in every language the app ships
--    with a number vocabulary: English, romanised Hindi/Urdu, Arabic, Urdu,
--    Hindi (Devanagari) and Bengali, plus "double 7" / "triple 0". Native
--    digits were already folded to 0-9. A run is a phone number when it
--    holds 10 to 13 digits and at least one of them was written as a word;
--    pure digit runs keep the existing rule, so salary figures in the Indian
--    format ("12,00,000-15,00,000") and dates are still never struck.
-- 2. Profile names, profession, community, field of study and bio were
--    checked for contact details only inside the app. A modified app or a
--    direct API call could publish a phone number in a bio that every member
--    (including men without Premium) can read. A trigger now refuses contact
--    details in those columns whenever they change. Existing rows are not
--    touched (none fail the check today).

CREATE OR REPLACE FUNCTION public.text_has_spelled_phone_number(p_text text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  c_mark constant text := chr(1);
  -- A number word must stand alone: anything that is not a Latin, Arabic,
  -- Devanagari or Bengali letter (or the marker) bounds it.
  c_letters constant text := 'a-z' || chr(1536) || '-' || chr(1791)
    || chr(2304) || '-' || chr(2431) || chr(2432) || '-' || chr(2559);
  c_edge constant text := '(^|[^' || c_letters || '])';
  c_next constant text := '(?=[^' || c_letters || ']|$)';
  -- Arabic-script spelling variants (hamza alef, taa marbuta, alef maqsura,
  -- Urdu heh/yeh/keheh) and Arabic/Hindi punctuation fold to one form. The
  -- word list below is folded the same way, so each word is listed once.
  c_fold_from constant text := 'أإآٱةىۀہۃھیےک،؛।';
  c_fold_to constant text := 'ااااهيههههييك,;.';
  v text;
  v_word record;
  v_run text;
  v_digits integer;
BEGIN
  IF p_text IS NULL OR p_text !~ ('[a-zA-Z' || chr(1536) || '-' || chr(1791)
       || chr(2304) || '-' || chr(2559) || ']') THEN
    RETURN false;
  END IF;

  v := lower(normalize(p_text, NFKC));
  -- Fold native digits (Arabic-Indic, Persian, Devanagari, Bengali).
  v := translate(
    v,
    '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹०१२३४५६७८९০১২৩৪৫৬৭৮৯',
    '0123456789012345678901234567890123456789'
  );
  v := translate(v, c_fold_from, c_fold_to);
  -- Strip Arabic short vowels and tatweel.
  v := regexp_replace(v, '[' || chr(1611) || '-' || chr(1631) || chr(1600) || ']', '', 'g');

  -- "double seven" / "triple zero" (common when Indian numbers are read out).
  v := regexp_replace(v, c_edge || '(double|dabal|dubal)[[:space:]]+([^[:space:]]+)',
                      '\1\3 \3', 'g');
  v := regexp_replace(v, c_edge || '(triple|tripal|tribal)[[:space:]]+([^[:space:]]+)',
                      '\1\3 \3 \3', 'g');

  FOR v_word IN
    SELECT DISTINCT translate(w.word, c_fold_from, c_fold_to) AS word, w.digit
    FROM (VALUES
      -- English
      ('zero','0'),('oh','0'),('one','1'),('two','2'),('three','3'),
      ('four','4'),('five','5'),('six','6'),('seven','7'),('eight','8'),
      ('nine','9'),
      -- Romanised Hindi / Urdu
      ('shunya','0'),('sunya','0'),('shoonya','0'),('sifar','0'),('sifr','0'),
      ('ek','1'),('aik','1'),('do','2'),('teen','3'),('tin','3'),
      ('char','4'),('chaar','4'),('chār','4'),('panch','5'),('paanch','5'),
      ('paach','5'),('chhe','6'),('chhah','6'),('chhai','6'),('che','6'),
      ('chah','6'),('cheh','6'),('saat','7'),('sat','7'),('aath','8'),
      ('aat','8'),('aanth','8'),('nau','9'),('nao','9'),('no','9'),
      -- Arabic (after the folding above)
      ('صفر','0'),('واحد','1'),('واحده','1'),('اثنان','2'),('اثنين','2'),
      ('اثنتان','2'),('ثلاثه','3'),('ثلاث','3'),('اربعه','4'),('اربع','4'),
      ('خمسه','5'),('خمس','5'),('سته','6'),('ست','6'),('سبعه','7'),
      ('سبع','7'),('ثمانيه','8'),('ثماني','8'),('ثمان','8'),('تسعه','9'),
      ('تسع','9'),
      -- Urdu (after the folding above)
      ('ايك','1'),('دو','2'),('تين','3'),('چار','4'),('پانچ','5'),
      ('چھ','6'),('چھي','6'),('سات','7'),('آٹھ','8'),('اٹھ','8'),('نو','9'),
      -- Hindi (Devanagari)
      ('शून्य','0'),('सिफ़र','0'),('एक','1'),('दो','2'),('तीन','3'),
      ('चार','4'),('पांच','5'),('पाँच','5'),('छह','6'),('छः','6'),('छे','6'),
      ('सात','7'),('आठ','8'),('नौ','9'),
      -- Bengali (with and without the precomposed ya-nukta)
      ('শূন্য','0'),('এক','1'),('দুই','2'),('তিন','3'),('চার','4'),
      ('পাঁচ','5'),('ছয়','6'),('ছয়','6'),('ছয়','6'),('সাত','7'),('আট','8'),
      ('নয়','9'),('নয়','9')
    ) AS w(word, digit)
    ORDER BY 1 DESC
  LOOP
    v := regexp_replace(
      v,
      c_edge || v_word.word || c_next,
      '\1' || c_mark || v_word.digit,
      'g'
    );
  END LOOP;

  IF position(c_mark in v) = 0 THEN
    RETURN false;
  END IF;

  -- "nine, eight, seven": a comma next to a spelled digit is a separator.
  -- Commas between two written digits keep their meaning (12,00,000).
  v := regexp_replace(v, '(' || c_mark || '[0-9])[[:space:]]*,[[:space:]]*', '\1 ', 'g');
  v := regexp_replace(v, '([0-9])[[:space:]]*,[[:space:]]*(' || c_mark || ')', '\1 \2', 'g');
  -- "and" between spelled digits ("nine and eight") is a separator too.
  v := regexp_replace(
    v,
    '(' || c_mark || '[0-9])[[:space:]]+(and|aur|और|و|اور|এবং)[[:space:]]+(' || c_mark || ')',
    '\1 \3',
    'g'
  );

  FOR v_run IN
    SELECT m[1]
    FROM regexp_matches(
      v,
      '(' || c_mark || '?[0-9](?:[[:space:]/_.()+*#:;|~=–—-]{0,2}' || c_mark || '?[0-9])+)',
      'g'
    ) AS m
  LOOP
    IF position(c_mark in v_run) > 0 THEN
      v_digits := char_length(regexp_replace(v_run, '[^0-9]', '', 'g'));
      IF v_digits BETWEEN 10 AND 13 THEN
        RETURN true;
      END IF;
    END IF;
  END LOOP;

  RETURN false;
END;
$function$;

REVOKE ALL ON FUNCTION public.text_has_spelled_phone_number(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.text_has_spelled_phone_number(text)
  TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.text_has_spelled_phone_number(text) IS
  'True when text spells a 10-13 digit phone number with number words (English, romanised Hindi/Urdu, Arabic, Urdu, Hindi, Bengali), alone or mixed with digits.';

-- chat_safety_check: unchanged from migration 313 except the spelled-number
-- rule right after the digit rule.
DO $migration$
DECLARE
  v_def text;
  v_anchor constant text :=
E'  IF v_lower ~ ''[a-z0-9._%+-]+@[a-z0-9-]+(\\.[a-z0-9-]+)*\\.[a-z]{2,}''';
  v_patch constant text :=
E'  IF public.text_has_spelled_phone_number(v_norm) THEN\n'
  || E'    RETURN QUERY SELECT ''blocked''::text, ''phone_number''::text, v_content;\n'
  || E'    RETURN;\n'
  || E'  END IF;\n\n';
BEGIN
  v_def := pg_get_functiondef('public.chat_safety_check(text)'::regprocedure);
  IF position('text_has_spelled_phone_number' in v_def) > 0 THEN
    RETURN;  -- already applied
  END IF;
  IF (length(v_def) - length(replace(v_def, v_anchor, ''))) / length(v_anchor) <> 1 THEN
    RAISE EXCEPTION 'chat_safety_check: email anchor not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_anchor, v_patch || v_anchor);
END;
$migration$;

-- Profile text visible to other members must not carry contact details.
CREATE OR REPLACE FUNCTION private.enforce_profile_public_text()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_field text;
  v_value text;
  v_check record;
BEGIN
  FOR v_field, v_value IN
    SELECT f.name, f.value
    FROM (VALUES
      ('first_name', NEW.first_name, CASE WHEN TG_OP = 'UPDATE' THEN OLD.first_name END),
      ('last_name', NEW.last_name, CASE WHEN TG_OP = 'UPDATE' THEN OLD.last_name END),
      ('profession', NEW.profession, CASE WHEN TG_OP = 'UPDATE' THEN OLD.profession END),
      ('community', NEW.community, CASE WHEN TG_OP = 'UPDATE' THEN OLD.community END),
      ('field_of_study', NEW.field_of_study, CASE WHEN TG_OP = 'UPDATE' THEN OLD.field_of_study END),
      ('bio', NEW.bio, CASE WHEN TG_OP = 'UPDATE' THEN OLD.bio END)
    ) AS f(name, value, old_value)
    WHERE nullif(btrim(f.value), '') IS NOT NULL
      AND f.value IS DISTINCT FROM f.old_value
  LOOP
    SELECT * INTO v_check FROM public.chat_safety_check(v_value);
    IF v_check.safety_status = 'blocked'
       AND v_check.safety_reason IN ('phone_number', 'email', 'social_media', 'url') THEN
      RAISE EXCEPTION 'profile_contact_details_blocked'
        USING ERRCODE = 'P0001',
              DETAIL = v_field || ':' || v_check.safety_reason;
    END IF;
  END LOOP;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.enforce_profile_public_text() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_enforce_profile_public_text ON public.profiles;
CREATE TRIGGER trg_enforce_profile_public_text
  BEFORE INSERT OR UPDATE OF first_name, last_name, profession, community, field_of_study, bio
  ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION private.enforce_profile_public_text();
