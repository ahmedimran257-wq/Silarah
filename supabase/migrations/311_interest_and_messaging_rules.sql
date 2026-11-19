-- Interest, match and messaging rules from the second audit (19 Nov 2026).
-- Callers checked first: the app calls send_interest, respond_to_interest,
-- can_open_chat and apply_referral_code and reads only the fields kept here;
-- new error codes are mapped in interests_cubit.dart.
--
-- 1. Interests and matches never checked gender, so two women (or two men)
--    could send, accept and chat by calling the API with a member id.
--    Now: both members need a known gender and they must differ, checked
--    when sending, when accepting and when the match row is created.
-- 2. An admin-suspended member (profile visibility 'suspended') could still
--    open chats and send messages. Now refused as account_restricted.
-- 3. Accepting an interest from a banned or deleted sender made a match.
--    Now refused as interest_unavailable.
-- 4. A declined interest could be re-sent at once, repeatedly. Now one
--    30-day pause per declined pair (interest_declined_cooldown).
-- 5. Blocking deleted pending interests, which refunded the sender's daily
--    quota, so block/unblock/re-send looped notifications. Pending
--    interests are now closed (kept, hidden, still counted).
-- 6. Interest notes were checked for length only on the server, so contact
--    details reached members before Premium messaging. Notes now pass the
--    same safety check as chat messages; the limit is the column's 150.
-- 7. Shadowbanned senders still triggered "New interest" pushes.
-- 8. Referral: no rate limit on applying codes, the referrer's id was
--    returned to the new account, and banned or deleted referrers still
--    received Premium.

-- Pair rule used everywhere below.
CREATE OR REPLACE FUNCTION private.is_marriage_pair(p_a uuid, p_b uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.users a
    JOIN public.users b ON b.id = p_b
    WHERE a.id = p_a
      AND lower(trim(coalesce(a.gender, ''))) IN ('male', 'female')
      AND lower(trim(coalesce(b.gender, ''))) IN ('male', 'female')
      AND lower(trim(a.gender)) <> lower(trim(b.gender))
  );
$function$;

REVOKE ALL ON FUNCTION private.is_marriage_pair(uuid, uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.send_interest(p_receiver_id uuid, p_note text DEFAULT NULL::text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_sender uuid := private.assert_authenticated();
  v_id uuid;
  v_low uuid := LEAST(v_sender, p_receiver_id);
  v_high uuid := GREATEST(v_sender, p_receiver_id);
  v_available_at timestamptz;
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_safety_status text;
  v_safe_note text;
BEGIN
  IF p_receiver_id IS NULL OR p_receiver_id = v_sender THEN
    RAISE EXCEPTION 'cannot_interest_self' USING ERRCODE = 'P0001';
  END IF;
  IF char_length(coalesce(v_note, '')) > 150 THEN
    RAISE EXCEPTION 'interest_note_too_long' USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    JOIN public.users u ON u.id = p.user_id
    WHERE p.user_id = p_receiver_id
      AND p.visibility = 'visible'
      AND u.deleted_at IS NULL
      AND coalesce(u.is_banned, false) = false
  ) THEN
    RAISE EXCEPTION 'profile_unavailable' USING ERRCODE = 'P0001';
  END IF;

  -- Marriage introductions are always between a man and a woman.
  IF NOT private.is_marriage_pair(v_sender, p_receiver_id) THEN
    RAISE EXCEPTION 'profile_unavailable' USING ERRCODE = 'P0001';
  END IF;

  IF NOT private.can_access_incognito_profile(v_sender, p_receiver_id) THEN
    RAISE EXCEPTION 'profile_unavailable' USING ERRCODE = 'P0001';
  END IF;

  -- Notes get the same contact-detail screening as chat messages.
  IF v_note IS NOT NULL THEN
    SELECT check_result.safety_status, check_result.sanitized_content
    INTO v_safety_status, v_safe_note
    FROM public.chat_safety_check(v_note) AS check_result;
    IF v_safety_status = 'blocked' THEN
      RAISE EXCEPTION 'interest_note_blocked' USING ERRCODE = 'P0001';
    END IF;
    v_note := nullif(trim(coalesce(v_safe_note, v_note)), '');
    IF char_length(coalesce(v_note, '')) > 150 THEN
      RAISE EXCEPTION 'interest_note_too_long' USING ERRCODE = 'P0001';
    END IF;
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(v_low::text || ':' || v_high::text, 182)
  );

  IF EXISTS (
    SELECT 1 FROM public.blocks b
    WHERE (b.blocker_id = v_sender AND b.blocked_id = p_receiver_id)
       OR (b.blocker_id = p_receiver_id AND b.blocked_id = v_sender)
  ) OR EXISTS (
    SELECT 1 FROM public.reports r
    WHERE (r.reporter_id = v_sender AND r.reported_user_id = p_receiver_id)
       OR (r.reporter_id = p_receiver_id AND r.reported_user_id = v_sender)
  ) OR EXISTS (
    SELECT 1 FROM public.matches m
    WHERE m.user_a = v_low
      AND m.user_b = v_high
      AND m.status IN ('blocked','reported')
  ) THEN
    RAISE EXCEPTION 'profile_unavailable' USING ERRCODE = 'P0001';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.matches m
    WHERE m.user_a = v_low AND m.user_b = v_high AND m.status = 'active'
  ) THEN
    RAISE EXCEPTION 'already_matched' USING ERRCODE = 'P0001';
  END IF;

  SELECT max(coalesce(m.closed_at, m.created_at) + interval '7 days')
  INTO v_available_at
  FROM public.matches m
  WHERE m.user_a = v_low
    AND m.user_b = v_high
    AND m.status IN ('closed','expired')
    AND coalesce(m.closed_at, m.created_at) + interval '7 days' > now();

  IF v_available_at IS NOT NULL THEN
    RAISE EXCEPTION 'rematch_cooldown' USING
      ERRCODE = 'P0001',
      DETAIL = json_build_object('available_at', v_available_at)::text;
  END IF;

  -- A declined interest pauses this sender for 30 days.
  SELECT max(i.created_at + interval '30 days')
  INTO v_available_at
  FROM public.interests i
  WHERE i.sender_id = v_sender
    AND i.receiver_id = p_receiver_id
    AND i.status = 'declined'
    AND i.created_at + interval '30 days' > now();

  IF v_available_at IS NOT NULL THEN
    RAISE EXCEPTION 'interest_declined_cooldown' USING
      ERRCODE = 'P0001',
      DETAIL = json_build_object('available_at', v_available_at)::text;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.interests i
    WHERE (
      (i.sender_id = v_sender AND i.receiver_id = p_receiver_id)
      OR (i.sender_id = p_receiver_id AND i.receiver_id = v_sender)
    )
      AND i.status IN ('pending','accepted')
  ) THEN
    RAISE EXCEPTION 'interest_already_active' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.interests(
    sender_id, receiver_id, status, note, created_at, expires_at
  )
  VALUES (
    v_sender, p_receiver_id, 'pending', v_note,
    now(), now() + interval '14 days'
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.respond_to_interest(p_interest_id uuid, p_decision text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_receiver uuid := private.assert_authenticated();
  v_sender uuid;
  v_status text;
BEGIN
  IF p_decision NOT IN ('accepted', 'declined') THEN
    RAISE EXCEPTION 'invalid_interest_decision' USING ERRCODE = 'P0001';
  END IF;

  SELECT i.sender_id INTO v_sender
  FROM public.interests i
  WHERE i.id = p_interest_id
    AND i.receiver_id = v_receiver
    AND i.status = 'pending'
    AND i.expires_at > now()
  FOR UPDATE;

  IF v_sender IS NULL THEN
    RAISE EXCEPTION 'interest_unavailable' USING ERRCODE = 'P0001';
  END IF;

  -- Accepting needs a sender who can still take part: not banned, deleted
  -- or suspended, and a man-woman pair. Declining is always allowed.
  IF p_decision = 'accepted' AND (
    NOT private.is_marriage_pair(v_sender, v_receiver)
    OR NOT EXISTS (
      SELECT 1
      FROM public.users u
      JOIN public.profiles p ON p.user_id = u.id
      WHERE u.id = v_sender
        AND u.deleted_at IS NULL
        AND coalesce(u.is_banned, false) = false
        AND p.visibility NOT IN ('suspended', 'deactivated')
    )
  ) THEN
    RAISE EXCEPTION 'interest_unavailable' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.interests
  SET status = p_decision
  WHERE id = p_interest_id
    AND receiver_id = v_receiver
    AND status = 'pending'
  RETURNING status INTO v_status;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'interest_unavailable' USING ERRCODE = 'P0001';
  END IF;
  RETURN v_status;
END;
$function$;

-- The match row itself enforces the same rules, whatever path accepts.
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
    WHERE (r.reporter_id = v_low AND r.reported_user_id = v_high)
       OR (r.reporter_id = v_high AND r.reported_user_id = v_low)
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

-- Blocking closes pending interests instead of deleting them: the sender's
-- daily count is not refunded, and the app never lists closed interests.
CREATE OR REPLACE FUNCTION public.sever_ties_on_block()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  UPDATE public.matches
  SET status = 'blocked',
      closed_by = NEW.blocker_id,
      closed_at = now(),
      closure_reason = 'user_blocked'
  WHERE (
      (user_a = NEW.blocker_id AND user_b = NEW.blocked_id)
      OR (user_b = NEW.blocker_id AND user_a = NEW.blocked_id)
    )
    AND status = 'active';

  UPDATE public.interests
  SET status = 'closed'
  WHERE status = 'pending'
    AND (
      (sender_id = NEW.blocker_id AND receiver_id = NEW.blocked_id)
      OR (sender_id = NEW.blocked_id AND receiver_id = NEW.blocker_id)
    );
  RETURN NEW;
END;
$function$;

-- No "New interest" push from a shadowbanned sender.
CREATE OR REPLACE FUNCTION private.queue_interest_lifecycle_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  BEGIN
    IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = NEW.sender_id
          AND coalesce(u.is_shadowbanned, false)
      ) THEN
        PERFORM public.queue_notification(
          NEW.receiver_id,
          'interest_received',
          'New interest',
          'Someone is interested in your profile.',
          'silarah://interests'
        );
      END IF;
    ELSIF TG_OP = 'UPDATE'
      AND OLD.status IS DISTINCT FROM NEW.status
      AND NEW.status = 'accepted' THEN
      PERFORM public.queue_notification(
        NEW.sender_id,
        'interest_accepted',
        'Interest accepted',
        'You can now start a conversation.',
        'silarah://interests'
      );
    ELSIF TG_OP = 'UPDATE'
      AND OLD.status IS DISTINCT FROM NEW.status
      AND NEW.status = 'expired' THEN
      PERFORM public.queue_notification(
        NEW.sender_id,
        'interest_expired',
        'Your interest expired',
        'No response was received during the 14-day response window.',
        'silarah://interests'
      );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Interest % committed without notification enqueue: %',
      NEW.id, SQLERRM;
  END;
  RETURN NEW;
END;
$function$;

-- Messaging: an admin-suspended or deactivated sender cannot send, through
-- any path (the trigger covers direct inserts too).
CREATE OR REPLACE FUNCTION public.assert_messaging_allowed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_suspended_until timestamptz;
BEGIN
  IF v_actor IS NOT NULL AND NEW.sender_id <> v_actor THEN
    IF NEW.sent_by_guardian IS DISTINCT FROM true OR NOT EXISTS (
      SELECT 1 FROM public.guardian_chat_mirrors gcm
      WHERE gcm.match_id = NEW.match_id
        AND gcm.guardian_id = v_actor
        AND gcm.ward_id = NEW.sender_id
        AND gcm.mode = 'active'
        AND public.is_current_guardian_for_ward(gcm.ward_id, 'active')
    ) THEN
      RAISE EXCEPTION 'You cannot send a message for another member.'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  IF v_actor IS NOT NULL THEN
    PERFORM private.assert_active_member(v_actor, false);
  END IF;
  PERFORM private.assert_active_member(NEW.sender_id, false);
  PERFORM private.assert_active_member(NEW.receiver_id, false);
  IF EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = NEW.sender_id
      AND p.visibility IN ('suspended', 'deactivated')
  ) THEN
    RAISE EXCEPTION 'account_restricted' USING ERRCODE = 'P0001';
  END IF;
  SELECT u.messaging_suspended_until INTO v_suspended_until
  FROM public.users u WHERE u.id = NEW.sender_id;
  IF v_suspended_until IS NOT NULL AND v_suspended_until > now() THEN
    RAISE EXCEPTION 'messaging_suspended' USING ERRCODE = 'P0001',
      DETAIL = json_build_object('until', v_suspended_until)::text;
  END IF;
  PERFORM private.assert_outgoing_chat_entitlement(NEW.sender_id);
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.can_open_chat(p_match_id uuid)
RETURNS TABLE(allowed boolean, reason text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := auth.uid();
  v_match public.matches%rowtype;
  v_other uuid;
  v_gender text;
  v_suspended_until timestamptz;
  v_status text;
  v_is_banned boolean;
  v_deleted_at timestamptz;
  v_other_unavailable boolean;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_match
  FROM public.matches m
  WHERE m.id = p_match_id
    AND (m.user_a = v_me OR m.user_b = v_me);

  IF NOT FOUND
    OR (v_match.user_a = v_me AND v_match.hidden_by_a_at IS NOT NULL)
    OR (v_match.user_b = v_me AND v_match.hidden_by_b_at IS NOT NULL) THEN
    RETURN QUERY SELECT false, 'not_found'::text;
    RETURN;
  END IF;

  SELECT u.gender, u.messaging_suspended_until,
         coalesce(u.is_banned, false), u.deleted_at
  INTO v_gender, v_suspended_until, v_is_banned, v_deleted_at
  FROM public.users u
  WHERE u.id = v_me;

  IF NOT FOUND OR v_is_banned OR v_deleted_at IS NOT NULL THEN
    RETURN QUERY SELECT false, 'account_restricted'::text;
    RETURN;
  END IF;

  -- An admin-suspended or deactivated account cannot use chat.
  IF EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = v_me
      AND p.visibility IN ('suspended', 'deactivated')
  ) THEN
    RETURN QUERY SELECT false, 'account_restricted'::text;
    RETURN;
  END IF;

  v_status := coalesce(v_match.status, 'active');
  IF v_status IN ('blocked', 'reported') THEN
    RETURN QUERY SELECT false, 'closed'::text;
    RETURN;
  END IF;
  IF v_suspended_until IS NOT NULL AND v_suspended_until > now() THEN
    RETURN QUERY SELECT false, 'suspended'::text;
    RETURN;
  END IF;
  IF lower(trim(coalesce(v_gender, ''))) IS DISTINCT FROM 'female'
    AND NOT public.has_active_premium(v_me) THEN
    RETURN QUERY SELECT false, 'subscription_required'::text;
    RETURN;
  END IF;

  v_other := CASE WHEN v_match.user_a = v_me
    THEN v_match.user_b ELSE v_match.user_a END;
  SELECT NOT (
    u.id IS NOT NULL
    AND u.deleted_at IS NULL
    AND coalesce(u.is_banned, false) = false
    AND coalesce(p.visibility, 'deactivated') NOT IN ('suspended', 'deactivated')
  )
  INTO v_other_unavailable
  FROM (SELECT v_other AS id) target
  LEFT JOIN public.users u ON u.id = target.id
  LEFT JOIN public.profiles p ON p.user_id = target.id;

  IF coalesce(v_other_unavailable, true) THEN
    RETURN QUERY SELECT true, 'member_unavailable_read_only'::text;
    RETURN;
  END IF;
  IF v_status = 'active'
    AND NOT private.guardian_approvals_complete(p_match_id) THEN
    RETURN QUERY SELECT false, 'guardian_approval_required'::text;
    RETURN;
  END IF;
  IF v_status = 'active' THEN
    RETURN QUERY SELECT true, 'allowed'::text;
    RETURN;
  END IF;
  IF v_status IN ('closed', 'expired') THEN
    RETURN QUERY SELECT true, 'read_only'::text;
    RETURN;
  END IF;
  RETURN QUERY SELECT false, 'closed'::text;
END;
$function$;

-- Referral: rate-limited, and the referrer stays private.
CREATE OR REPLACE FUNCTION public.apply_referral_code(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_referred_id uuid := private.assert_authenticated();
  v_referrer_id uuid;
  v_inserted boolean := false;
BEGIN
  -- Ten attempts an hour is plenty for a person and stops code guessing.
  PERFORM private.enforce_member_feature_rate_limit(
    'referral_apply', v_referred_id, 10, 3600
  );

  -- Referral codes are a signup incentive. Existing completed accounts cannot
  -- attach a code after the fact and farm promotional access.
  IF EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.user_id = v_referred_id
      AND p.onboarding_completed = true
  ) THEN
    RETURN jsonb_build_object('status', 'ineligible_existing_account');
  END IF;

  SELECT rc.owner_id
  INTO v_referrer_id
  FROM public.referral_codes rc
  WHERE rc.code = upper(trim(coalesce(p_code, '')));

  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object('status', 'invalid_code');
  END IF;
  IF v_referrer_id = v_referred_id THEN
    RETURN jsonb_build_object('status', 'self_referral');
  END IF;

  WITH inserted AS (
    INSERT INTO public.referrals(referrer_id, referred_id)
    VALUES (v_referrer_id, v_referred_id)
    ON CONFLICT (referred_id) DO NOTHING
    RETURNING 1
  )
  SELECT EXISTS (SELECT 1 FROM inserted) INTO v_inserted;

  IF NOT v_inserted THEN
    RETURN jsonb_build_object('status', 'already_referred');
  END IF;

  UPDATE public.referral_codes
  SET uses_count = uses_count + 1
  WHERE owner_id = v_referrer_id;

  RETURN jsonb_build_object('status', 'applied');
END;
$function$;

CREATE OR REPLACE FUNCTION private.process_referral_reward(p_referred_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_referral public.referrals%ROWTYPE;
  v_referrer_gender text;
  v_referred_gender text;
  v_referrer_expiry timestamptz;
  v_referred_expiry timestamptz;
  v_referrer_eligible boolean;
BEGIN
  SELECT r.*
  INTO v_referral
  FROM public.referrals r
  WHERE r.referred_id = p_referred_id
    AND r.reward_granted = false
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    JOIN public.users u ON u.id = p.user_id
    WHERE p.user_id = p_referred_id
      AND p.onboarding_completed = true
      AND u.deleted_at IS NULL
  ) THEN
    RETURN false;
  END IF;

  -- Retain gender snapshots for aggregate referral analytics only. Gender is
  -- deliberately not an eligibility condition.
  SELECT lower(trim(u.gender::text))
  INTO v_referrer_gender
  FROM public.users u
  WHERE u.id = v_referral.referrer_id;

  SELECT lower(trim(u.gender::text))
  INTO v_referred_gender
  FROM public.users u
  WHERE u.id = p_referred_id;

  UPDATE public.referrals
  SET referred_gender = v_referred_gender,
      referrer_gender = v_referrer_gender
  WHERE id = v_referral.id;

  -- A banned or deleted referrer earns nothing; the new member still does.
  SELECT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = v_referral.referrer_id
      AND u.deleted_at IS NULL
      AND coalesce(u.is_banned, false) = false
  ) INTO v_referrer_eligible;

  IF v_referrer_eligible THEN
    v_referrer_expiry := private.grant_referral_premium(
      v_referral.id,
      v_referral.referrer_id,
      'referrer'
    );
  END IF;
  v_referred_expiry := private.grant_referral_premium(
    v_referral.id,
    p_referred_id,
    'referred'
  );

  UPDATE public.referrals
  SET reward_granted = true,
      reward_type = CASE
        WHEN v_referrer_expiry IS NOT NULL AND v_referred_expiry IS NOT NULL
          THEN '3_days_premium_both'
        WHEN v_referred_expiry IS NOT NULL
          THEN '3_days_premium_referred_only'
        WHEN v_referrer_expiry IS NOT NULL
          THEN '3_days_premium_referrer_only'
        ELSE 'referral_reward_cap_reached'
      END
  WHERE id = v_referral.id;

  IF v_referrer_eligible THEN
    IF v_referrer_expiry IS NOT NULL THEN
      PERFORM public.queue_notification(
        v_referral.referrer_id,
        'referral_reward',
        '3 days of Premium unlocked',
        'Your referral completed their profile. Your one-time 3-day Premium reward is active.',
        'silarah://profile'
      );
    ELSE
      PERFORM public.queue_notification(
        v_referral.referrer_id,
        'referral_completed',
        'Your referral joined',
        'You already claimed your one-time referral Premium. Your friend can still receive their own reward.',
        'silarah://profile'
      );
    END IF;
  END IF;

  IF v_referred_expiry IS NOT NULL THEN
    PERFORM public.queue_notification(
      p_referred_id,
      'referral_reward',
      '3 days of Premium unlocked',
      'Your one-time 3-day referral Premium is active.',
      'silarah://profile'
    );
  END IF;

  RETURN true;
END;
$function$;
