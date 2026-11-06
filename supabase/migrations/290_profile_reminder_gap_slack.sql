-- Silarah — profile reminders: one hour of slack in the 3-day gap
--
-- profile-nudge-daily runs at 10:00 UTC and stamps last_nudge_sent_at with
-- the run's own start time. The next eligible run is three days later at
-- about the same instant, so "<= now() - 3 days" was decided by milliseconds:
-- on 6 Nov 2026 the reviewer account (reminded 3 Nov 10:00:00.217) was
-- skipped by a run that started at 10:00:00.205, 12 ms short, turning the
-- 3-day gap into 4 days at random. The gap is now "3 days minus an hour",
-- so a daily run always picks up members whose window has opened, while
-- manual or overlapping runs still cannot send twice within ~3 days.
-- Only the three comparisons change; every other rule from 289 is the same.

CREATE OR REPLACE FUNCTION private.profile_nudge_audience(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    JOIN public.profiles p ON p.user_id = u.id
    LEFT JOIN public.notification_prefs prefs ON prefs.user_id = u.id
    WHERE u.id = p_user_id
      AND u.deleted_at IS NULL
      AND u.deletion_status = 'active'
      AND coalesce(u.is_banned, false) = false
      AND coalesce(u.is_shadowbanned, false) = false
      AND (u.messaging_suspended_until IS NULL
           OR u.messaging_suspended_until <= now())
      AND coalesce(u.account_role, 'member') <> 'guardian'
      AND p.visibility = 'visible'
      AND coalesce(p.onboarding_completed, false) = true
      AND p.approved_at <= now() - interval '1 day'
      AND p.last_active_at > now() - interval '7 days'
      AND coalesce(prefs.inactive_nudge, true) = true
      AND coalesce(u.last_nudge_sent_at, '-infinity'::timestamptz)
          <= now() - interval '3 days' + interval '1 hour'
  );
$$;

CREATE OR REPLACE FUNCTION public.dispatch_profile_nudge(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_profile public.profiles%ROWTYPE;
  v_lang text;
  v_gaps text[];
  v_gap_type text;
  v_deep_link text;
  v_title text;
  v_body text;
  v_claimed integer;
BEGIN
  -- Repeated here so a manual call cannot bypass the audience or the
  -- three-day interval.
  IF NOT private.profile_nudge_audience(p_user_id) THEN
    RETURN;
  END IF;

  SELECT p.* INTO v_profile
  FROM public.profiles p
  WHERE p.user_id = p_user_id;

  SELECT coalesce(lower(left(nullif(btrim(u.preferred_language), ''), 2)), 'en')
  INTO v_lang
  FROM public.users u
  WHERE u.id = p_user_id;

  v_gaps := private.profile_completion_gaps(v_profile);
  IF cardinality(v_gaps) = 0 THEN
    RETURN;
  END IF;

  -- Highest-priority missing item that was not sent in the last 14 days
  -- and has been sent fewer than 3 times.
  SELECT rule.gap_type, rule.deep_link, rule.title_template, rule.body_template
  INTO v_gap_type, v_deep_link, v_title, v_body
  FROM public.profile_nudge_rules rule
  LEFT JOIN private.profile_nudge_history sent
    ON sent.user_id = p_user_id AND sent.gap_type = rule.gap_type
  WHERE rule.enabled
    AND rule.gap_type = ANY(v_gaps)
    AND (
      sent.user_id IS NULL
      OR (sent.sent_count < 3
          AND sent.last_sent_at <= now() - interval '14 days')
    )
  ORDER BY rule.priority
  LIMIT 1;

  IF v_gap_type IS NULL THEN
    RETURN;
  END IF;

  SELECT c.title, c.body
  INTO v_title, v_body
  FROM private.profile_nudge_copy c
  WHERE c.gap_type = v_gap_type
    AND c.language_code IN (v_lang, 'en')
  ORDER BY (c.language_code = v_lang) DESC
  LIMIT 1;
  -- With no copy row, the rule's English templates (already selected) stay.

  -- Claim the send window atomically so overlapping runs cannot double-send.
  UPDATE public.users
  SET last_nudge_sent_at = now()
  WHERE id = p_user_id
    AND coalesce(last_nudge_sent_at, '-infinity'::timestamptz)
        <= now() - interval '3 days' + interval '1 hour';
  GET DIAGNOSTICS v_claimed = ROW_COUNT;
  IF v_claimed = 0 THEN
    RETURN;
  END IF;

  INSERT INTO private.profile_nudge_history(
    user_id, gap_type, sent_count, last_sent_at
  )
  VALUES (p_user_id, v_gap_type, 1, now())
  ON CONFLICT (user_id, gap_type) DO UPDATE
  SET sent_count = private.profile_nudge_history.sent_count + 1,
      last_sent_at = now();

  -- queue_notification moves delivery past the member's quiet hours.
  PERFORM public.queue_notification(
    p_user_id, 'profile_nudge', v_title, v_body, v_deep_link
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.dispatch_profile_nudges()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtextextended('profile_nudges', 289)) THEN
    RETURN;
  END IF;

  FOR v_user_id IN
    SELECT u.id
    FROM public.users u
    JOIN public.profiles p ON p.user_id = u.id
    WHERE u.deleted_at IS NULL
      AND p.visibility = 'visible'
      AND p.last_active_at > now() - interval '7 days'
      AND coalesce(u.last_nudge_sent_at, '-infinity'::timestamptz)
          <= now() - interval '3 days' + interval '1 hour'
      AND private.profile_nudge_audience(u.id)
    ORDER BY p.last_active_at DESC, u.id
    LIMIT 500
  LOOP
    PERFORM public.dispatch_profile_nudge(v_user_id);
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION private.profile_nudge_audience(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.dispatch_profile_nudge(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.dispatch_profile_nudges()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.dispatch_profile_nudge(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.dispatch_profile_nudges() TO service_role;
