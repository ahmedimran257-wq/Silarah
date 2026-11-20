-- 313: chat, moderation and data-integrity fixes from the server audit.
--
-- Every function below is rewritten from the live production definition
-- (migration 311 state). Signatures and returned fields are unchanged.
--
--  1. close_chat_match: no longer callable by members directly (the app uses
--     send_and_close_match); the closure reason is capped at 500 characters
--     and passes the chat safety check.
--  2. send_and_close_match: a member who may read but not send (Premium
--     needed, guardian approval pending, other member unavailable, messaging
--     suspended, read-only chat) can still end the match. The farewell
--     message is skipped and a fixed neutral closure reason is stored.
--  3. Safety strikes now persist. A blocked member message no longer raises
--     (the raise rolled the strike back); send_chat_message records the strike
--     and returns a normal row (message_id NULL, safety_status 'blocked').
--     The app already treats a missing message_id as "not sent".
--  4. chat_safety_check: NFKC normalisation, invisible-character stripping,
--     native digits, \y word boundaries (\b is a backspace in Postgres),
--     generic bare-domain rule, wa.me / t.me, (at), "at the rate", "dot com",
--     @handles and phone numbers split by separators.
--  5. Reports alert staff once per new report; message reports are rate
--     limited and never reopen a resolved report.
--  6. Dismissing a message report restores the match it closed; dismissed
--     member reports no longer block a future match.
--  7. expire_stale_matches waits for guardian approval and sends nudges
--     through queue_notification only to members who can act on them.
--  8. Deleted or banned members never get pushes; their device tokens are
--     removed when the account is banned or deleted.
--  9. messages_select hides messages the member removed from their inbox.
-- 10. Legacy get_chat_messages (v1) is no longer callable by members.
-- 11. Member and guardian messages share the 2000-character limit with a
--     clear message_too_long error.
-- 12. The unused storage_cleanup_queue is no longer filled and is emptied.
-- 13. Integrity constraints (NOT VALID where old rows may not comply) and
--     staff-reference foreign keys that no longer block deleting a staff
--     login.
-- 14. Photo moderation_status repair; the report-threshold alert fires once.
-- 15. Retention for operational tables.

-- ---------------------------------------------------------------------------
-- 4. Chat safety check (first, because later functions call it)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chat_safety_check(p_content text)
 RETURNS TABLE(safety_status text, safety_reason text, sanitized_content text)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_content text := btrim(coalesce(p_content, ''));
  v_norm text;
  v_lower text;
  v_spaced text;
  v_host text;
  v_labels text[];
  v_tld text;
  v_term record;
  v_run text;
  v_digit_count integer;
  -- Top-level domains that are blocked even in "Word.Word" form.
  c_known_tlds constant text[] := ARRAY[
    'com','net','org','io','in','co','me','app','info','biz','xyz','online',
    'site','website','link','ly','gg','to','tv','us','uk','pk','bd','lk','np',
    'af','ae','sa','qa','om','kw','bh','my','id','tr','eg','ng','ke','za','ca',
    'au','de','fr','ru','live','shop','store','club','top','page','dev','ai',
    'cc','ws','ml','tk','ga','cf','gq','life','world','chat','social','email',
    'cloud','tech','pro','mobi','name','fm','am','bio','gl','su','vip','one'
  ];
  -- Short hosts that share the "one letter + TLD" shape of degree names.
  c_short_hosts constant text[] := ARRAY[
    'x.com','t.co','g.co','t.me','m.me','wa.me','g.page','u.to','v.ht','j.mp'
  ];
  -- "Mr.Khan", "pvt.ltd", "approx.five": abbreviations, not hosts.
  c_abbreviations constant text[] := ARRAY[
    'mr','mrs','ms','dr','st','sr','jr','prof','no','nos','vs','etc','eg','ie',
    'ph','approx','dept','govt','pvt','ltd','hr','hrs','min','max','sec','yr',
    'yrs','ft','km','kg','rs','inr','sq','pg','ug','sh','hz','md','mt'
  ];
BEGIN
  IF char_length(v_content) = 0 THEN
    RETURN QUERY SELECT 'blocked'::text, 'empty'::text, v_content;
    RETURN;
  END IF;

  IF char_length(v_content) > 2000 THEN
    RETURN QUERY SELECT 'blocked'::text, 'too_long'::text, left(v_content, 2000);
    RETURN;
  END IF;

  -- Screening runs on a normalised copy; the stored text stays as written
  -- (NFKC would rewrite Arabic ligatures such as U+FDFA).
  v_norm := normalize(v_content, NFKC);
  v_norm := regexp_replace(
    v_norm, '[­᠎​-‏⁠-⁤﻿]', '', 'g'
  );
  v_norm := translate(
    v_norm,
    '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹०१२३४५६७८९০১২৩৪৫৬৭৮৯',
    '0123456789012345678901234567890123456789'
  );
  v_lower := lower(v_norm);

  -- Phone numbers: a run of digits joined by up to two separators
  -- ("98765 43210", "9/8/7...", "987.654.3210", "+91 (987) 654-3210") that
  -- holds 10 to 13 digits (with or without a country code). Commas are not
  -- separators and longer runs are not phones, so salary figures in the
  -- Indian format ("12,00,000-15,00,000") and date ranges are never treated
  -- as numbers to strike: blocked text now counts toward a suspension.
  FOR v_run IN
    SELECT m[1]
    FROM regexp_matches(
      v_lower,
      '([0-9](?:[[:space:]/_.()+*#:;|~=–—-]{0,2}[0-9])+)',
      'g'
    ) AS m
  LOOP
    v_digit_count := char_length(regexp_replace(v_run, '[^0-9]', '', 'g'));
    IF v_digit_count BETWEEN 10 AND 13 THEN
      RETURN QUERY SELECT 'blocked'::text, 'phone_number'::text, v_content;
      RETURN;
    END IF;
  END LOOP;

  IF v_lower ~ '[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}'
     OR v_lower ~ '@[[:space:]]*(gmail|googlemail|yahoo|ymail|hotmail|outlook|icloud|proton|protonmail|rediffmail|aol)\y'
     OR v_lower ~ '(\(|\[|\{|<)[[:space:]]*at[[:space:]]*(\)|\]|\}|>)'
     OR v_lower ~ '\yat[[:space:]]*the[[:space:]]*rate\y(?![[:space:]]*of\y)' THEN
    RETURN QUERY SELECT 'blocked'::text, 'email'::text, v_content;
    RETURN;
  END IF;

  IF v_lower ~ '\y(wa|t|m)\.me\y'
     OR v_lower ~ '\ywa[[:space:]]*(\.|\ydot\y)[[:space:]]*me\y'
     OR v_lower ~ '(^|[^a-z0-9._%+-])@[a-z0-9._]*[a-z][a-z0-9._]{2,}' THEN
    RETURN QUERY SELECT 'blocked'::text, 'social_media'::text, v_content;
    RETURN;
  END IF;

  IF v_lower ~ '(https?|hxxps?|ftp)[[:space:]]*:[[:space:]]*//'
     OR v_lower ~ '\ywww[[:space:]]*(\.|\ydot\y)'
     OR v_lower ~ '\ydot[[:space:]]*(com|net|org|in|co|me|io|app|info)\y'
     OR v_lower ~ '(\(|\[|\{|<)[[:space:]]*dot[[:space:]]*(\)|\]|\}|>)'
     OR v_lower ~ '[a-z0-9]{2,}([[:space:]]+\.[[:space:]]*|\.[[:space:]]+)(com|net|org|io|app)\y' THEN
    RETURN QUERY SELECT 'blocked'::text, 'url'::text, v_content;
    RETURN;
  END IF;

  -- Bare hosts with a well-known TLD, whatever the letter case.
  FOR v_host IN
    SELECT m[2]
    FROM regexp_matches(
      v_lower,
      '(^|[^a-z0-9@._-])([a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.[a-z]{2,24})(?![a-z0-9-])',
      'g'
    ) AS m
  LOOP
    v_labels := string_to_array(v_host, '.');
    v_tld := v_labels[array_length(v_labels, 1)];
    IF v_host = ANY (c_short_hosts) THEN
      RETURN QUERY SELECT 'blocked'::text, 'url'::text, v_content;
      RETURN;
    END IF;
    IF v_tld = ANY (c_known_tlds)
       AND NOT (
         array_length(v_labels, 1) = 2
         AND char_length(v_labels[1]) = 1   -- B.Com, M.Com, B.Sc
       ) THEN
      RETURN QUERY SELECT 'blocked'::text, 'url'::text, v_content;
      RETURN;
    END IF;
  END LOOP;

  -- Any other TLD (generic rule). "word.Word" is read as a sentence break
  -- with a missing space, and short abbreviations (Mr., e.g., B.Tech) pass.
  v_spaced := lower(regexp_replace(v_norm, '([a-z])\.([A-Z])', '\1. \2', 'g'));
  FOR v_host IN
    SELECT m[2]
    FROM regexp_matches(
      v_spaced,
      '(^|[^a-z0-9@._-])([a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.[a-z]{2,24})(?![a-z0-9-])',
      'g'
    ) AS m
  LOOP
    v_labels := string_to_array(v_host, '.');
    v_tld := v_labels[array_length(v_labels, 1)];
    CONTINUE WHEN v_tld = ANY (c_known_tlds);  -- handled above
    CONTINUE WHEN array_length(v_labels, 1) = 2
      AND (char_length(v_labels[1]) = 1 OR v_labels[1] = ANY (c_abbreviations));
    RETURN QUERY SELECT 'blocked'::text, 'url'::text, v_content;
    RETURN;
  END LOOP;

  FOR v_term IN
    SELECT term, severity, reason
    FROM chat_blocked_terms
    WHERE position(lower(term) in v_lower) > 0
    ORDER BY CASE severity WHEN 'block' THEN 0 ELSE 1 END
  LOOP
    RETURN QUERY SELECT
      CASE WHEN v_term.severity = 'block' THEN 'blocked' ELSE 'flagged' END::text,
      v_term.reason::text,
      v_content;
    RETURN;
  END LOOP;

  RETURN QUERY SELECT 'clean'::text, NULL::text, v_content;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3. Strikes that persist
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_chat_safety_violation(p_user_id uuid, p_reason text, p_content text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_type text;
  v_recent_count int;
  v_excerpt text := left(coalesce(p_content, ''), 500);
BEGIN
  -- Empty or over-long input is a client error, not a safety strike.
  IF p_user_id IS NULL OR coalesce(p_reason, '') IN ('empty', 'too_long') THEN
    RETURN;
  END IF;

  v_type := CASE p_reason
    WHEN 'phone_number' THEN 'phone_number'
    WHEN 'email' THEN 'email'
    WHEN 'url' THEN 'url'
    WHEN 'social_media' THEN 'social_media'
    WHEN 'harassment' THEN 'harassment'
    ELSE 'blocked_term'
  END;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('chat-safety-strike:' || p_user_id::text, 0)
  );

  -- Retrying the same blocked text within 10 minutes is one strike.
  IF NOT EXISTS (
    SELECT 1 FROM public.content_violations cv
    WHERE cv.user_id = p_user_id
      AND cv.violation_type = v_type
      AND cv.original_content IS NOT DISTINCT FROM v_excerpt
      AND cv.created_at >= now() - interval '10 minutes'
  ) THEN
    INSERT INTO public.content_violations(user_id, violation_type, original_content)
    VALUES (p_user_id, v_type, v_excerpt);
  END IF;

  SELECT count(*) INTO v_recent_count
  FROM public.content_violations cv
  WHERE cv.user_id = p_user_id
    AND cv.created_at >= now() - interval '24 hours';

  IF v_recent_count >= 3 THEN
    UPDATE public.users
    SET messaging_suspended_until = greatest(
      coalesce(messaging_suspended_until, now()),
      now() + interval '24 hours'
    )
    WHERE id = p_user_id;
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.send_chat_message(p_match_id uuid, p_content text)
 RETURNS TABLE(message_id uuid, created_at timestamp with time zone, safety_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_match public.matches%rowtype;
  v_receiver uuid;
  v_access record;
  v_check record;
  v_message public.messages%rowtype;
  v_sender_name text;
  v_receiver_wants_push boolean;
BEGIN
  IF char_length(btrim(coalesce(p_content, ''))) = 0 THEN
    RAISE EXCEPTION 'invalid_message' USING ERRCODE = 'P0001';
  END IF;
  IF char_length(btrim(p_content)) > 2000 THEN
    RAISE EXCEPTION 'message_too_long' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_match FROM public.matches
  WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND OR NOT (v_match.user_a = v_me OR v_match.user_b = v_me) THEN
    RAISE EXCEPTION 'Chat not found' USING ERRCODE = 'P0001';
  END IF;
  IF coalesce(v_match.status, 'active') <> 'active' THEN
    RAISE EXCEPTION 'This chat is closed' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_access FROM public.can_open_chat(p_match_id);
  IF v_access.allowed IS DISTINCT FROM true OR v_access.reason <> 'allowed' THEN
    RAISE EXCEPTION '%', coalesce(v_access.reason, 'messaging_unavailable')
      USING ERRCODE = 'P0001';
  END IF;

  v_receiver := CASE WHEN v_match.user_a = v_me
    THEN v_match.user_b ELSE v_match.user_a END;
  PERFORM private.assert_active_member(v_receiver, false);
  IF EXISTS (
    SELECT 1 FROM public.blocks b
    WHERE (b.blocker_id = v_me AND b.blocked_id = v_receiver)
       OR (b.blocker_id = v_receiver AND b.blocked_id = v_me)
  ) THEN
    RAISE EXCEPTION 'This chat is unavailable' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_check FROM public.chat_safety_check(p_content);
  IF v_check.safety_status = 'blocked' THEN
    -- No RAISE here: an error would roll the strike back. The caller gets a
    -- normal row without a message id, which the app shows as "not sent".
    PERFORM public.record_chat_safety_violation(v_me, v_check.safety_reason, p_content);
    RETURN QUERY SELECT NULL::uuid, NULL::timestamptz, 'blocked'::text;
    RETURN;
  END IF;

  INSERT INTO public.messages(
    match_id, sender_id, receiver_id, content, status, safety_status, safety_reason
  ) VALUES (
    p_match_id, v_me, v_receiver, v_check.sanitized_content, 'sent',
    v_check.safety_status, v_check.safety_reason
  ) RETURNING * INTO v_message;

  BEGIN
    SELECT coalesce(np.new_message, true) INTO v_receiver_wants_push
    FROM public.users u
    LEFT JOIN public.notification_prefs np ON np.user_id = u.id
    WHERE u.id = v_receiver;
    IF coalesce(v_receiver_wants_push, true) THEN
      SELECT coalesce(nullif(p.first_name, ''), 'Silarah member')
      INTO v_sender_name FROM public.profiles p WHERE p.user_id = v_me;
      PERFORM public.queue_notification(
        v_receiver, 'new_message', 'New message',
        coalesce(v_sender_name, 'A Silarah member') || ' sent you a message.',
        '/chat/' || p_match_id::text
      );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Message % committed without push enqueue: %', v_message.id, SQLERRM;
  END;

  RETURN QUERY SELECT v_message.id, v_message.created_at, v_message.safety_status;
END;
$function$;

-- 11 + 3: same 2000 limit as the app composer; a blocked member message
-- returns (NULL, NULL, 'blocked') with the strike kept. Guardian sends still
-- raise (see send_guardian_chat_message).
CREATE OR REPLACE FUNCTION public.send_chat_message_idempotent(p_match_id uuid, p_content text, p_operation_id uuid, p_as_guardian boolean DEFAULT false)
 RETURNS TABLE(message_id uuid, created_at timestamp with time zone, safety_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_actor uuid := private.assert_authenticated();
  v_receipt private.chat_send_receipts%ROWTYPE;
  v_message public.messages%ROWTYPE;
  v_id uuid;
  v_status text;
  v_hash bytea;
BEGIN
  PERFORM private.assert_active_member(v_actor, false);
  IF p_operation_id IS NULL OR p_match_id IS NULL OR p_as_guardian IS NULL
     OR char_length(trim(coalesce(p_content, ''))) = 0 THEN
    RAISE EXCEPTION 'invalid_message_request' USING ERRCODE = '22023';
  END IF;
  IF char_length(btrim(p_content)) > 2000 THEN
    RAISE EXCEPTION 'message_too_long' USING ERRCODE = '22023';
  END IF;
  PERFORM private.enforce_member_feature_rate_limit('chat_send_request', v_actor, 120, 60);
  v_hash := pg_catalog.sha256(pg_catalog.convert_to(p_content, 'UTF8'));
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('chat-send:' || v_actor::text || ':' || p_operation_id::text, 0)
  );
  SELECT r.* INTO v_receipt FROM private.chat_send_receipts r
  WHERE r.actor_id = v_actor AND r.operation_id = p_operation_id;
  IF FOUND THEN
    IF v_receipt.match_id <> p_match_id OR v_receipt.content_hash <> v_hash
       OR v_receipt.as_guardian <> p_as_guardian THEN
      RAISE EXCEPTION 'message_request_conflict' USING ERRCODE = '22023';
    END IF;
    -- Return only the original acknowledgement, never resend or disclose text.
    SELECT m.* INTO STRICT v_message FROM public.messages m WHERE m.id = v_receipt.message_id;
  ELSE
    IF p_as_guardian THEN
      v_id := public.send_guardian_chat_message(p_match_id, p_content);
    ELSE
      SELECT sent.message_id, sent.safety_status INTO v_id, v_status
      FROM public.send_chat_message(p_match_id, p_content) sent;
      IF v_id IS NULL THEN
        -- Blocked by the safety rules: the strike is saved, no receipt is
        -- written, so a corrected retry with the same operation id can send.
        RETURN QUERY SELECT NULL::uuid, NULL::timestamptz, coalesce(v_status, 'blocked')::text;
        RETURN;
      END IF;
    END IF;
    SELECT m.* INTO STRICT v_message FROM public.messages m WHERE m.id = v_id;
    INSERT INTO private.chat_send_receipts(actor_id, operation_id, match_id, content_hash, as_guardian, message_id)
    VALUES (v_actor, p_operation_id, p_match_id, v_hash, p_as_guardian, v_message.id);
  END IF;
  RETURN QUERY SELECT v_message.id, v_message.created_at, v_message.safety_status::text;
END;
$function$;

-- 11: 2000-character limit. A blocked guardian message still raises: the
-- guardian screen only learns of a failure through an error, so a silent
-- "blocked" row would look like a sent message there.
CREATE OR REPLACE FUNCTION public.send_guardian_chat_message(p_match_id uuid, p_content text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_guardian uuid := private.assert_authenticated();
  v_match public.matches%ROWTYPE;
  v_ward uuid;
  v_receiver uuid;
  v_message_id uuid;
  v_check record;
BEGIN
  PERFORM private.assert_active_member(v_guardian, false);
  IF char_length(trim(coalesce(p_content, ''))) = 0 THEN
    RAISE EXCEPTION 'invalid_message' USING ERRCODE = 'P0001';
  END IF;
  IF char_length(btrim(p_content)) > 2000 THEN
    RAISE EXCEPTION 'message_too_long' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_match
  FROM public.matches
  WHERE id = p_match_id
  FOR UPDATE;
  IF NOT FOUND OR coalesce(v_match.status, 'active') <> 'active' THEN
    RAISE EXCEPTION 'chat_unavailable' USING ERRCODE = 'P0001';
  END IF;

  SELECT gcm.ward_id INTO v_ward
  FROM public.guardian_chat_mirrors gcm
  WHERE gcm.match_id = p_match_id
    AND gcm.guardian_id = v_guardian
    AND gcm.mode = 'active'
    AND public.is_current_guardian_for_ward(gcm.ward_id, 'active')
  FOR UPDATE;
  IF v_ward IS NULL OR v_ward NOT IN (v_match.user_a, v_match.user_b) THEN
    RAISE EXCEPTION 'guardian_not_authorized' USING ERRCODE = 'P0001';
  END IF;
  IF NOT private.guardian_approvals_complete(p_match_id) THEN
    RAISE EXCEPTION 'guardian_approval_required' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_check FROM public.chat_safety_check(p_content);
  IF v_check.safety_status = 'blocked' THEN
    PERFORM public.record_chat_safety_violation(
      v_guardian,
      v_check.safety_reason,
      p_content
    );
    RAISE EXCEPTION 'Message blocked by safety rules: %', v_check.safety_reason
      USING ERRCODE = 'P0001';
  END IF;

  v_receiver := CASE
    WHEN v_match.user_a = v_ward THEN v_match.user_b
    ELSE v_match.user_a
  END;
  INSERT INTO public.messages(
    match_id, sender_id, receiver_id, content, sent_by_guardian,
    status, safety_status, safety_reason
  )
  VALUES (
    p_match_id, v_ward, v_receiver, v_check.sanitized_content, true,
    'sent', v_check.safety_status, v_check.safety_reason
  )
  RETURNING id INTO v_message_id;
  RETURN v_message_id;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 1 + 2. Ending a match
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.close_chat_match(p_match_id uuid, p_closure_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := auth.uid();
  v_reason text := left(trim(coalesce(p_closure_reason, '')), 500);
  v_safety text;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  IF length(v_reason) < 10 THEN
    RAISE EXCEPTION 'Closure reason is required' USING ERRCODE = 'P0001';
  END IF;

  SELECT check_result.safety_status INTO v_safety
  FROM public.chat_safety_check(v_reason) AS check_result;
  IF v_safety = 'blocked' THEN
    RAISE EXCEPTION 'closure_reason_blocked' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.matches m
  SET status = 'closed',
      closed_by = v_me,
      closed_at = now(),
      closure_reason = v_reason
  WHERE m.id = p_match_id
    AND (m.user_a = v_me OR m.user_b = v_me)
    AND coalesce(m.status, 'active') = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active chat not found' USING ERRCODE = 'P0001';
  END IF;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.close_chat_match(uuid, text) FROM PUBLIC, anon, authenticated;

-- A closure without a farewell message has no message id.
ALTER TABLE private.match_closure_operations ALTER COLUMN message_id DROP NOT NULL;

CREATE OR REPLACE FUNCTION public.send_and_close_match(p_match_id uuid, p_closure_reason text, p_operation_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_message_id uuid;
  v_safety text;
  v_access record;
  v_farewell boolean := true;
  v_existing private.match_closure_operations%ROWTYPE;
  c_neutral_reason constant text := 'This match has been closed.';
BEGIN
  IF p_operation_id IS NULL THEN
    RAISE EXCEPTION 'operation_id_required' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_existing
  FROM private.match_closure_operations operation
  WHERE operation.operation_id = p_operation_id;
  IF FOUND THEN
    IF v_existing.actor_id <> v_me OR v_existing.match_id <> p_match_id THEN
      RAISE EXCEPTION 'operation_id_conflict' USING ERRCODE = 'P0001';
    END IF;
    RETURN jsonb_build_object(
      'closed', true,
      'message_id', v_existing.message_id,
      'replayed', true
    );
  END IF;

  SELECT * INTO v_access FROM public.can_open_chat(p_match_id);
  IF v_access.reason IN (
    'subscription_required', 'guardian_approval_required',
    'member_unavailable_read_only', 'suspended', 'read_only'
  ) THEN
    -- The member may not send, but may always leave: close without the
    -- farewell message and with a fixed neutral reason.
    v_farewell := false;
    PERFORM public.close_chat_match(p_match_id, c_neutral_reason);
  ELSE
    SELECT result.message_id, result.safety_status INTO v_message_id, v_safety
    FROM public.send_chat_message(p_match_id, p_closure_reason) result;
    IF v_message_id IS NULL THEN
      -- The farewell was blocked by the safety rules (strike kept); the match
      -- stays open so the member can pick another message.
      RETURN jsonb_build_object(
        'closed', false,
        'message_id', NULL,
        'replayed', false,
        'safety_status', coalesce(v_safety, 'blocked')
      );
    END IF;
    PERFORM public.close_chat_match(p_match_id, p_closure_reason);
  END IF;

  INSERT INTO private.match_closure_operations(
    operation_id, match_id, actor_id, message_id
  ) VALUES (p_operation_id, p_match_id, v_me, v_message_id);

  RETURN jsonb_build_object(
    'closed', true,
    'message_id', v_message_id,
    'replayed', false,
    'farewell_sent', v_farewell
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5. Reports
-- ---------------------------------------------------------------------------
DO $migration$
DECLARE
  v_def text := replace(
    pg_get_functiondef('public.submit_user_report(uuid,text,text)'::regprocedure),
    E'\r', ''
  );
  v_old_decl constant text := E'  v_id uuid;\nBEGIN';
  v_new_decl constant text := E'  v_id uuid;\n  v_inserted boolean := false;\nBEGIN';
  v_old_tail constant text := E'  RETURNING id INTO v_id;\n\n  INSERT INTO public.admin_notifications(type, message, related_user_id)\n  VALUES (\n    ''member_report_received'',\n    ''A member report requires moderation review.'',\n    p_reported_user_id\n  );\n  RETURN v_id;';
  v_new_tail constant text := E'  RETURNING id, (xmax = 0) INTO v_id, v_inserted;\n\n  -- Only a new report alerts staff; a repeat while it is pending updates it.\n  IF v_inserted THEN\n    INSERT INTO public.admin_notifications(type, message, related_user_id)\n    VALUES (\n      ''member_report_received'',\n      ''A member report requires moderation review.'',\n      p_reported_user_id\n    );\n  END IF;\n  RETURN v_id;';
BEGIN
  IF (length(v_def) - length(replace(v_def, v_old_decl, ''))) / length(v_old_decl) <> 1
     OR (length(v_def) - length(replace(v_def, v_old_tail, ''))) / length(v_old_tail) <> 1 THEN
    RAISE EXCEPTION 'submit_user_report definition changed; review migration 313';
  END IF;
  v_def := replace(v_def, v_old_decl, v_new_decl);
  v_def := replace(v_def, v_old_tail, v_new_tail);
  EXECUTE v_def;
END;
$migration$;

CREATE OR REPLACE FUNCTION public.report_chat_message(p_message_id uuid, p_reason text, p_description text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := auth.uid();
  v_msg public.messages%rowtype;
  v_reason text := lower(coalesce(p_reason, 'other'));
  v_report_id uuid;
  v_inserted boolean := false;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = '42501';
  END IF;
  PERFORM private.enforce_member_feature_rate_limit('message_report', v_me, 20, 86400);

  SELECT * INTO v_msg
  FROM public.messages
  WHERE id = p_message_id;

  IF NOT FOUND OR v_msg.receiver_id <> v_me THEN
    RAISE EXCEPTION 'message_not_reportable' USING ERRCODE = 'P0001';
  END IF;
  IF v_reason NOT IN (
    'harassment', 'inappropriate', 'scam', 'contact_sharing', 'other'
  ) THEN
    v_reason := 'other';
  END IF;

  -- A report staff already resolved is never reopened by a repeat tap.
  INSERT INTO public.message_reports(
    message_id, match_id, reporter_id, reported_user_id, reason, description
  )
  VALUES (
    v_msg.id, v_msg.match_id, v_me, v_msg.sender_id, v_reason,
    nullif(left(trim(coalesce(p_description, '')), 1000), '')
  )
  ON CONFLICT (message_id, reporter_id) DO UPDATE
  SET reason = EXCLUDED.reason,
      description = EXCLUDED.description,
      created_at = now()
  WHERE message_reports.status = 'pending'
  RETURNING id, (xmax = 0) INTO v_report_id, v_inserted;

  IF v_report_id IS NULL THEN
    RETURN;
  END IF;

  UPDATE public.matches
  SET status = 'reported',
      closed_by = v_me,
      closed_at = coalesce(closed_at, now()),
      closure_reason = 'message_report_submitted'
  WHERE id = v_msg.match_id
    AND status = 'active';

  IF v_inserted THEN
    INSERT INTO public.admin_notifications(type, message, related_user_id)
    VALUES (
      'message_report_received',
      'A reported chat message requires moderation review.',
      v_msg.sender_id
    );
  END IF;
END;
$function$;

-- 14b. AFTER INSERT trigger: the old NEW assignment did nothing (the report
-- RPC already stores the trust score) and every report past three re-alerted.
CREATE OR REPLACE FUNCTION public.check_report_threshold()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_reporter_count integer;
BEGIN
  SELECT count(DISTINCT reporter_id) INTO v_reporter_count
  FROM public.reports
  WHERE reported_user_id = NEW.reported_user_id
    AND status = 'pending';
  IF v_reporter_count >= 3 AND NOT EXISTS (
    SELECT 1 FROM public.admin_notifications an
    WHERE an.type = 'review_required'
      AND an.related_user_id = NEW.reported_user_id
      AND (an.is_read = false OR an.created_at >= now() - interval '7 days')
  ) THEN
    INSERT INTO public.admin_notifications(type, message, related_user_id)
    VALUES (
      'review_required',
      format('%s distinct members reported this account. Manual review is required.', v_reporter_count),
      NEW.reported_user_id
    );
  END IF;
  RETURN NULL;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 6. Reported matches
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_resolve_message_report(p_report_id uuid, p_action text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_target uuid;
  v_match_id uuid;
  v_restored integer := 0;
  v_action text := lower(coalesce(p_action, ''));
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator']) THEN
    RAISE EXCEPTION 'staff_authorization_required' USING ERRCODE = '42501';
  END IF;
  IF v_action NOT IN ('reviewed', 'dismissed', 'actioned') THEN
    RAISE EXCEPTION 'invalid_message_report_action' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.message_reports
  SET status = v_action
  WHERE id = p_report_id AND status = 'pending'
  RETURNING reported_user_id, match_id INTO v_target, v_match_id;
  IF v_target IS NULL THEN
    RAISE EXCEPTION 'message_report_not_pending' USING ERRCODE = 'P0001';
  END IF;

  IF v_action = 'actioned' THEN
    UPDATE public.users
    SET messaging_suspended_until = greatest(
      coalesce(messaging_suspended_until, now()),
      now() + interval '7 days'
    )
    WHERE id = v_target;
  END IF;

  -- A dismissed report gives the pair their chat back, unless something else
  -- still keeps it closed.
  IF v_action = 'dismissed' THEN
    UPDATE public.matches m
    SET status = 'active',
        closed_by = NULL,
        closed_at = NULL,
        closure_reason = NULL
    WHERE m.id = v_match_id
      AND m.status = 'reported'
      AND m.closure_reason = 'message_report_submitted'
      AND m.hidden_by_a_at IS NULL
      AND m.hidden_by_b_at IS NULL
      AND NOT EXISTS (
        SELECT 1 FROM public.message_reports other
        WHERE other.match_id = m.id
          AND other.status IN ('pending', 'actioned')
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.blocks b
        WHERE (b.blocker_id = m.user_a AND b.blocked_id = m.user_b)
           OR (b.blocker_id = m.user_b AND b.blocked_id = m.user_a)
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.reports r
        WHERE ((r.reporter_id = m.user_a AND r.reported_user_id = m.user_b)
            OR (r.reporter_id = m.user_b AND r.reported_user_id = m.user_a))
          AND r.status IS DISTINCT FROM 'dismissed'
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.matches other_match
        WHERE other_match.id <> m.id
          AND other_match.status = 'active'
          AND least(other_match.user_a, other_match.user_b) = least(m.user_a, m.user_b)
          AND greatest(other_match.user_a, other_match.user_b) = greatest(m.user_a, m.user_b)
      )
      AND (
        SELECT count(*) FROM public.users u
        LEFT JOIN public.profiles p ON p.user_id = u.id
        WHERE u.id IN (m.user_a, m.user_b)
          AND u.deleted_at IS NULL
          AND coalesce(u.is_banned, false) = false
          AND coalesce(p.visibility, 'visible') NOT IN ('suspended', 'deactivated')
      ) = 2;
    GET DIAGNOSTICS v_restored = ROW_COUNT;
  END IF;

  DELETE FROM public.admin_work_locks
  WHERE item_type = 'message_report' AND item_id = p_report_id;
  INSERT INTO public.admin_audit_log(
    admin_id, actor_role, action_type, target_user_id, details
  ) VALUES (
    auth.uid(), public.current_admin_role(),
    'message_report_' || v_action, v_target,
    jsonb_build_object(
      'report_id', p_report_id,
      'messaging_restricted_days', CASE WHEN v_action = 'actioned' THEN 7 ELSE 0 END,
      'match_restored', v_restored > 0
    )
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_match_on_accept()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_low uuid := LEAST(NEW.sender_id, NEW.receiver_id);
  v_high uuid := GREATEST(NEW.sender_id, NEW.receiver_id);
BEGIN
  IF NEW.status <> 'accepted' THEN
    RETURN NEW;
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(v_low::text || ':' || v_high::text, 182)
  );

  IF NOT private.is_marriage_pair(NEW.sender_id, NEW.receiver_id)
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id IN (NEW.sender_id, NEW.receiver_id)
      AND (u.deleted_at IS NOT NULL OR coalesce(u.is_banned, false))
  ) OR EXISTS (
    SELECT 1 FROM public.blocks b
    WHERE (b.blocker_id = v_low AND b.blocked_id = v_high)
       OR (b.blocker_id = v_high AND b.blocked_id = v_low)
  ) OR EXISTS (
    SELECT 1 FROM public.reports r
    WHERE ((r.reporter_id = v_low AND r.reported_user_id = v_high)
       OR (r.reporter_id = v_high AND r.reported_user_id = v_low))
      AND r.status IS DISTINCT FROM 'dismissed'
  ) OR EXISTS (
    SELECT 1 FROM public.matches m
    WHERE m.user_a = v_low
      AND m.user_b = v_high
      AND m.status IN ('active','blocked','reported')
  ) THEN
    RAISE EXCEPTION 'match_pair_unavailable' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.matches(user_a, user_b, status)
  VALUES (v_low, v_high, 'active');
  RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 8. Notifications never reach deleted or banned members
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.queue_notification(p_user_id uuid, p_type text, p_title text, p_body text, p_deep_link text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_tz text;
  v_start time;
  v_end time;
  v_local timestamp;
  v_local_time time;
  v_local_date date;
  v_deliver_local timestamp;
  v_deliver_at timestamptz;
  v_quiet boolean;
  v_deep_link text := nullif(pg_catalog.btrim(p_deep_link), '');
BEGIN
  IF v_deep_link IS NOT NULL AND v_deep_link NOT LIKE 'silarah://%' THEN
    v_deep_link := CASE
      WHEN v_deep_link = '/help-support' THEN 'silarah://help-support'
      WHEN v_deep_link = '/home?tab=0' THEN 'silarah://discover'
      WHEN v_deep_link = '/home?tab=1' THEN 'silarah://interests'
      WHEN v_deep_link = '/home?tab=2' THEN 'silarah://chat'
      WHEN v_deep_link = '/home?tab=3' THEN 'silarah://profile'
      WHEN v_deep_link = '/profile' THEN 'silarah://profile'
      WHEN v_deep_link = '/verify' THEN 'silarah://verify-identity'
      WHEN v_deep_link = '/badge-verification' THEN 'silarah://verify'
      WHEN v_deep_link = '/photo-requests' THEN 'silarah://photo-requests'
      WHEN v_deep_link = '/notifications' THEN 'silarah://notifications'
      WHEN v_deep_link = '/subscription' THEN 'silarah://subscription'
      WHEN v_deep_link = '/edit-profile' THEN 'silarah://complete-profile'
      WHEN v_deep_link = '/edit-profile?section=photos' THEN 'silarah://photos'
      WHEN v_deep_link ~ '^/chat/[A-Za-z0-9_-]+$'
        THEN 'silarah://chat/' || pg_catalog.substr(v_deep_link, 7)
      WHEN v_deep_link ~ '^/profile/[A-Za-z0-9_-]+$'
        THEN 'silarah://profile/' || pg_catalog.substr(v_deep_link, 10)
      ELSE NULL
    END;

    IF v_deep_link IS NULL THEN
      RAISE EXCEPTION 'Unsupported notification deep link'
        USING ERRCODE = '22023';
    END IF;
  END IF;

  -- Deleted and banned accounts receive nothing.
  IF EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = p_user_id
      AND (u.deleted_at IS NOT NULL OR coalesce(u.is_banned, false))
  ) THEN
    RETURN;
  END IF;

  SELECT
    CASE WHEN EXISTS (
      SELECT 1
      FROM private.timezone_names
      WHERE name = u.timezone
    ) THEN u.timezone ELSE 'UTC' END,
    coalesce(np.quiet_start, time '23:00'),
    coalesce(np.quiet_end, time '08:00')
  INTO v_tz, v_start, v_end
  FROM public.users u
  LEFT JOIN public.notification_prefs np ON np.user_id = u.id
  WHERE u.id = p_user_id;

  IF v_tz IS NULL THEN
    v_tz := 'UTC';
  END IF;

  v_local := pg_catalog.now() AT TIME ZONE v_tz;
  v_local_time := v_local::time;
  v_local_date := v_local::date;
  v_quiet := CASE
    WHEN v_start = v_end THEN false
    WHEN v_start < v_end
      THEN v_local_time >= v_start AND v_local_time < v_end
    ELSE v_local_time >= v_start OR v_local_time < v_end
  END;

  IF NOT v_quiet THEN
    v_deliver_at := pg_catalog.now();
  ELSE
    v_deliver_local := CASE
      WHEN v_start < v_end THEN v_local_date + v_end
      WHEN v_local_time >= v_start THEN (v_local_date + 1) + v_end
      ELSE v_local_date + v_end
    END;
    v_deliver_at := v_deliver_local AT TIME ZONE v_tz;
  END IF;

  INSERT INTO public.notifications(
    user_id,
    type,
    title,
    body,
    deep_link,
    scheduled_at,
    next_attempt_at
  )
  VALUES (
    p_user_id,
    p_type,
    pg_catalog.left(p_title, 160),
    pg_catalog.left(p_body, 1000),
    v_deep_link,
    v_deliver_at,
    v_deliver_at
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.checkout_notifications(batch_size integer DEFAULT 100)
 RETURNS TABLE(id uuid, user_id uuid, type text, title text, body text, deep_link text, lease_token uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  UPDATE public.notifications
  SET delivery_status = 'pending', processing_at = NULL, lease_token = NULL
  WHERE delivery_status = 'processing'
    AND processing_at < now() - interval '5 minutes'
    AND sent_at IS NULL;

  -- Rows queued before the account was deleted or banned are never pushed.
  UPDATE public.notifications n
  SET sent_at = now(),
      delivery_status = 'in_app_only',
      last_error_code = 'recipient_unavailable'
  FROM public.users u
  WHERE u.id = n.user_id
    AND n.sent_at IS NULL
    AND n.delivery_status = 'pending'
    AND (u.deleted_at IS NOT NULL OR coalesce(u.is_banned, false));

  UPDATE public.notifications n
  SET sent_at = now(), delivery_status = 'in_app_only'
  WHERE n.sent_at IS NULL
    AND n.scheduled_at <= now()
    AND NOT public.notification_push_enabled(n.user_id, n.type);

  RETURN QUERY
  UPDATE public.notifications n
  SET delivery_status = 'processing',
      processing_at = now(),
      lease_token = gen_random_uuid(),
      attempt_count = n.attempt_count + 1
  WHERE n.id IN (
    SELECT q.id
    FROM public.notifications q
    WHERE q.sent_at IS NULL
      AND q.scheduled_at <= now()
      AND q.next_attempt_at <= now()
      AND q.delivery_status = 'pending'
      AND q.attempt_count < 8
      AND public.notification_push_enabled(q.user_id, q.type)
      AND NOT EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = q.user_id
          AND (u.deleted_at IS NOT NULL OR coalesce(u.is_banned, false))
      )
    ORDER BY q.scheduled_at, q.id
    LIMIT least(greatest(batch_size, 1), 100)
    FOR UPDATE SKIP LOCKED
  )
  RETURNING n.id, n.user_id, n.type, n.title, n.body, n.deep_link, n.lease_token;
END;
$function$;

-- Device tokens go when an account is banned or deleted. A trigger (not an
-- edit to admin_account_action) so every ban and deletion path is covered.
CREATE OR REPLACE FUNCTION private.revoke_push_tokens_for_closed_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  DELETE FROM public.user_fcm_tokens t WHERE t.user_id = NEW.id;
  RETURN NULL;
END;
$function$;

REVOKE ALL ON FUNCTION private.revoke_push_tokens_for_closed_account() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_revoke_push_tokens_for_closed_account ON public.users;
CREATE TRIGGER trg_revoke_push_tokens_for_closed_account
  AFTER UPDATE OF is_banned, deleted_at ON public.users
  FOR EACH ROW
  WHEN (
    (NEW.is_banned IS TRUE AND OLD.is_banned IS NOT TRUE)
    OR (NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL)
  )
  EXECUTE FUNCTION private.revoke_push_tokens_for_closed_account();

DELETE FROM public.user_fcm_tokens t
USING public.users u
WHERE u.id = t.user_id
  AND (u.deleted_at IS NOT NULL OR coalesce(u.is_banned, false));

-- ---------------------------------------------------------------------------
-- 7. Match expiry
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.expire_stale_matches()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_expiring_count integer;
  v_nudge record;
BEGIN
  -- ── Pre-expiration nudge: 24 hours before expiry ──────────
  -- Matches with no messages whose chat opened 6 days ago (the clock starts
  -- when the last guardian approval arrives, if any).
  FOR v_nudge IN
    SELECT recipient.user_id, m.id AS match_id
    FROM public.matches m
    CROSS JOIN LATERAL (
      SELECT greatest(m.created_at, coalesce(max(a.approved_at), m.created_at)) AS opened_at
      FROM private.guardian_match_approvals a
      WHERE a.match_id = m.id
    ) clock
    CROSS JOIN LATERAL (VALUES (m.user_a), (m.user_b)) recipient(user_id)
    WHERE m.status = 'active'
      AND m.last_message_at IS NULL
      AND clock.opened_at BETWEEN now() - interval '7 days' AND now() - interval '6 days'
      AND private.guardian_approvals_complete(m.id)
      AND EXISTS (
        SELECT 1 FROM public.users u
        LEFT JOIN public.profiles p ON p.user_id = u.id
        WHERE u.id = recipient.user_id
          AND u.deleted_at IS NULL
          AND coalesce(u.is_banned, false) = false
          AND (u.messaging_suspended_until IS NULL OR u.messaging_suspended_until <= now())
          AND coalesce(p.visibility, 'visible') NOT IN ('suspended', 'deactivated')
          AND (lower(trim(coalesce(u.gender, ''))) = 'female'
               OR public.has_active_premium(u.id))
      )
      -- Don't re-notify (check if we already sent this notification)
      AND NOT EXISTS (
        SELECT 1 FROM public.notifications n
        WHERE n.type = 'match_expiring'
          AND n.user_id = recipient.user_id
          AND n.deep_link = format('silarah://chat/%s', m.id)
          AND n.created_at > now() - interval '2 days'
      )
  LOOP
    PERFORM public.queue_notification(
      v_nudge.user_id,
      'match_expiring',
      '⏳ Match expiring soon',
      'Your match will expire tomorrow. Send a message to keep the conversation going!',
      format('silarah://chat/%s', v_nudge.match_id)
    );
  END LOOP;

  -- Nudge for stale conversations (12 days since last message)
  FOR v_nudge IN
    SELECT
      CASE
        WHEN last_msg.last_sender = m.user_a THEN m.user_b  -- Nudge the non-responder
        ELSE m.user_a
      END AS user_id,
      m.id AS match_id
    FROM public.matches m
    JOIN LATERAL (
      SELECT msg.sender_id AS last_sender
      FROM public.messages msg WHERE msg.match_id = m.id
      ORDER BY msg.created_at DESC LIMIT 1
    ) last_msg ON true
    WHERE m.status = 'active'
      AND m.last_message_at IS NOT NULL
      AND m.last_message_at BETWEEN now() - interval '13 days' AND now() - interval '12 days'
      AND private.guardian_approvals_complete(m.id)
      AND NOT EXISTS (
        SELECT 1 FROM public.notifications n
        WHERE n.type = 'match_expiring'
          AND n.deep_link = format('silarah://chat/%s', m.id)
          AND n.created_at > now() - interval '2 days'
      )
  LOOP
    CONTINUE WHEN NOT EXISTS (
      SELECT 1 FROM public.users u
      LEFT JOIN public.profiles p ON p.user_id = u.id
      WHERE u.id = v_nudge.user_id
        AND u.deleted_at IS NULL
        AND coalesce(u.is_banned, false) = false
        AND (u.messaging_suspended_until IS NULL OR u.messaging_suspended_until <= now())
        AND coalesce(p.visibility, 'visible') NOT IN ('suspended', 'deactivated')
        AND (lower(trim(coalesce(u.gender, ''))) = 'female'
             OR public.has_active_premium(u.id))
    );
    PERFORM public.queue_notification(
      v_nudge.user_id,
      'match_expiring',
      '⏳ Conversation expiring',
      'Your conversation will expire in 2 days if there''s no response.',
      format('silarah://chat/%s', v_nudge.match_id)
    );
  END LOOP;

  -- ── Expire: no messages 7 days after the chat opened ─────
  -- A match still waiting for guardian approval never expires.
  UPDATE public.matches m
  SET status = 'expired',
      closed_at = now(),
      closure_reason = 'no_response'
  WHERE m.status = 'active'
    AND m.last_message_at IS NULL
    AND m.created_at < now() - interval '7 days'
    AND private.guardian_approvals_complete(m.id)
    AND coalesce((
      SELECT max(a.approved_at) FROM private.guardian_match_approvals a
      WHERE a.match_id = m.id
    ), m.created_at) < now() - interval '7 days';

  GET DIAGNOSTICS v_expiring_count = ROW_COUNT;
  IF v_expiring_count > 0 THEN
    RAISE NOTICE 'Expired % matches with no messages after 7 days', v_expiring_count;
  END IF;

  -- ── Expire: conversation stale after 14 days ────────────
  UPDATE public.matches m
  SET status = 'expired',
      closed_at = now(),
      closure_reason = 'conversation_stale'
  WHERE m.status = 'active'
    AND m.last_message_at IS NOT NULL
    AND m.last_message_at < now() - interval '14 days'
    AND private.guardian_approvals_complete(m.id);

  GET DIAGNOSTICS v_expiring_count = ROW_COUNT;
  IF v_expiring_count > 0 THEN
    RAISE NOTICE 'Expired % matches with stale conversations (14d)', v_expiring_count;
  END IF;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 9. Messages a member removed from their inbox stay hidden from them
-- ---------------------------------------------------------------------------
-- A definer function, not a subquery on matches: the matches policy reads
-- profiles, which the authenticated role cannot select, so a plain subquery
-- would make every message read (and Realtime) fail with permission denied.
-- It only answers for the caller and only about flags the caller passes in.
CREATE OR REPLACE FUNCTION public.is_chat_message_hidden_for_me(p_match_id uuid, p_deleted_by_a boolean, p_deleted_by_b boolean)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.matches m
    WHERE m.id = p_match_id
      AND (
        (m.user_a = auth.uid() AND coalesce(p_deleted_by_a, false))
        OR (m.user_b = auth.uid() AND coalesce(p_deleted_by_b, false))
      )
  );
$function$;

REVOKE ALL ON FUNCTION public.is_chat_message_hidden_for_me(uuid, boolean, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_chat_message_hidden_for_me(uuid, boolean, boolean) TO authenticated, service_role;

ALTER POLICY messages_select ON public.messages
USING (
  (
    ((sender_id = (SELECT auth.uid() AS uid)) OR (receiver_id = (SELECT auth.uid() AS uid)))
    AND (SELECT public.can_read_my_chat_content() AS can_read_my_chat_content)
    AND NOT (
      (deleted_by_a OR deleted_by_b)
      AND public.is_chat_message_hidden_for_me(match_id, deleted_by_a, deleted_by_b)
    )
  )
  OR public.can_read_guardian_mirror(match_id)
);

-- ---------------------------------------------------------------------------
-- 10. Legacy chat reader (the app uses get_chat_messages_v2)
-- ---------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.get_chat_messages(uuid, integer, timestamp with time zone)
  FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 12. Dead storage cleanup queue (nothing reads it; the purge worker clears
-- storage before deleting the account row)
-- ---------------------------------------------------------------------------
DROP TRIGGER IF EXISTS clean_storage_on_user_delete ON public.users;
REVOKE EXECUTE ON FUNCTION public.queue_storage_cleanup() FROM PUBLIC, anon, authenticated;
TRUNCATE public.storage_cleanup_queue;

-- ---------------------------------------------------------------------------
-- 13. Integrity
-- ---------------------------------------------------------------------------
DO $migration$
BEGIN
  -- NOT VALID: one known fixture row has no login; new rows are checked.
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.users'::regclass AND conname = 'users_id_auth_fkey'
  ) THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_id_auth_fkey
      FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.matches'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ~ 'user_a <> user_b'
  ) THEN
    ALTER TABLE public.matches
      ADD CONSTRAINT matches_distinct_members_check
      CHECK (user_a <> user_b) NOT VALID;
  END IF;
END;
$migration$;

-- Staff-reference columns (all nullable): deleting a staff login keeps the
-- record and clears the reference instead of failing.
DO $migration$
DECLARE
  v_fk record;
BEGIN
  FOR v_fk IN
    SELECT c.conrelid::regclass AS tbl, c.conname, a.attname
    FROM pg_constraint c
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
    WHERE c.contype = 'f'
      AND c.confrelid = 'auth.users'::regclass
      AND c.confdeltype IN ('a', 'r')
      AND array_length(c.conkey, 1) = 1
      AND NOT a.attnotnull
      AND (c.conrelid, a.attname::text) IN (
        ('public.photos'::regclass, 'moderated_by'),
        ('public.photo_moderation_queue'::regclass, 'reviewed_by'),
        ('public.admin_memberships'::regclass, 'created_by'),
        ('public.admin_memberships'::regclass, 'revoked_by'),
        ('public.admin_push_campaigns'::regclass, 'created_by'),
        ('public.admin_push_campaigns'::regclass, 'queued_by'),
        ('public.admin_export_requests'::regclass, 'reviewed_by'),
        ('public.app_content_pages'::regclass, 'updated_by'),
        ('public.marriage_success_stories'::regclass, 'reviewed_by')
      )
  LOOP
    EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', v_fk.tbl, v_fk.conname);
    EXECUTE format(
      'ALTER TABLE %s ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES auth.users(id) ON DELETE SET NULL NOT VALID',
      v_fk.tbl, v_fk.conname, v_fk.attname
    );
    EXECUTE format('ALTER TABLE %s VALIDATE CONSTRAINT %I', v_fk.tbl, v_fk.conname);
  END LOOP;

  -- No staff reference to a login may still block deleting that login.
  IF EXISTS (
    SELECT 1 FROM pg_constraint c
    WHERE c.contype = 'f'
      AND c.confrelid = 'auth.users'::regclass
      AND c.confdeltype IN ('a', 'r')
      AND c.conrelid IN (
        'public.photos'::regclass, 'public.photo_moderation_queue'::regclass,
        'public.admin_memberships'::regclass, 'public.admin_push_campaigns'::regclass,
        'public.admin_export_requests'::regclass, 'public.app_content_pages'::regclass,
        'public.marriage_success_stories'::regclass
      )
  ) THEN
    RAISE EXCEPTION 'staff reference foreign keys still block login deletion';
  END IF;
END;
$migration$;

-- ---------------------------------------------------------------------------
-- 14a. Photos approved everywhere except moderation_status
-- ---------------------------------------------------------------------------
UPDATE public.photos p
SET moderation_status = 'approved',
    moderated_at = coalesce(p.moderated_at, now())
FROM public.photo_moderation_queue q
WHERE q.photo_id = p.id
  AND q.status = 'approved'
  AND p.status = 'active'
  AND p.admin_approved = true
  AND p.nsfw_cleared = true
  AND p.moderation_status IS DISTINCT FROM 'approved';

-- ---------------------------------------------------------------------------
-- 15. Retention (admin_audit_log and profile_views are kept)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.cleanup_operational_history()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_cron bigint := 0;
  v_jobs bigint := 0;
  v_signup bigint := 0;
  v_rank bigint := 0;
  v_admin_alerts bigint := 0;
  v_admin_logins bigint := 0;
  v_view_seen bigint := 0;
  v_send_receipts bigint := 0;
  v_deliveries bigint := 0;
  v_dead_pushes bigint := 0;
BEGIN
  DELETE FROM cron.job_run_details
  WHERE end_time IS NOT NULL
    AND end_time < now() - interval '14 days';
  GET DIAGNOSTICS v_cron = ROW_COUNT;

  DELETE FROM private.job_runs
  WHERE finished_at IS NOT NULL
    AND finished_at < now() - interval '30 days';
  GET DIAGNOSTICS v_jobs = ROW_COUNT;

  DELETE FROM private.signup_consent_transactions
  WHERE (
      consumed_at IS NULL
      AND expires_at < now() - interval '1 day'
    ) OR (
      consumed_at IS NOT NULL
      AND consumed_at < now() - interval '30 days'
    );
  GET DIAGNOSTICS v_signup = ROW_COUNT;

  DELETE FROM public.glicko_interactions
  WHERE processed = true
    AND created_at < now() - interval '90 days';
  GET DIAGNOSTICS v_rank = ROW_COUNT;

  DELETE FROM public.admin_notifications
  WHERE is_read = true
    AND created_at < now() - interval '180 days';
  GET DIAGNOSTICS v_admin_alerts = ROW_COUNT;

  DELETE FROM public.admin_login_attempts
  WHERE created_at < now() - interval '90 days';
  GET DIAGNOSTICS v_admin_logins = ROW_COUNT;

  DELETE FROM public.profile_view_daily_seen
  WHERE first_viewed_at < now() - interval '60 days';
  GET DIAGNOSTICS v_view_seen = ROW_COUNT;

  -- Receipts have no timestamp of their own; the message carries it.
  DELETE FROM private.chat_send_receipts r
  WHERE NOT EXISTS (
    SELECT 1 FROM public.messages m
    WHERE m.id = r.message_id
      AND m.created_at >= now() - interval '30 days'
  );
  GET DIAGNOSTICS v_send_receipts = ROW_COUNT;

  DELETE FROM private.notification_deliveries
  WHERE updated_at < now() - interval '90 days';
  GET DIAGNOSTICS v_deliveries = ROW_COUNT;

  DELETE FROM public.notifications
  WHERE sent_at IS NULL
    AND attempt_count >= 8
    AND created_at < now() - interval '7 days';
  GET DIAGNOSTICS v_dead_pushes = ROW_COUNT;

  RETURN jsonb_build_object(
    'cron_history_deleted', v_cron,
    'worker_history_deleted', v_jobs,
    'temporary_signup_transactions_deleted', v_signup,
    'processed_ranking_events_deleted', v_rank,
    'read_admin_notifications_deleted', v_admin_alerts,
    'admin_login_attempts_deleted', v_admin_logins,
    'profile_view_daily_seen_deleted', v_view_seen,
    'chat_send_receipts_deleted', v_send_receipts,
    'notification_deliveries_deleted', v_deliveries,
    'undeliverable_notifications_deleted', v_dead_pushes
  );
END;
$function$;
