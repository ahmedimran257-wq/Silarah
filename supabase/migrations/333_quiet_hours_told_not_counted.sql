-- Quiet hours are told to the caller and never count towards the
-- unanswered-call limit (owner's rule, 25 Nov 2026; docs/voice_calling_spec.md
-- 4 and 8). Builds on 323 and 332.
--
-- A call in the callee's quiet hours (her own, or the default 11 PM - 8 AM)
-- was refused with the same neutral "isn't taking calls right now" as calls
-- off or a block, and counted as an unanswered call: two calls at 7:45 AM
-- used two of the man's three for the day, and he could not tell that
-- calling after 8 would ring. Now:
--  * The caller is told it is her quiet hours and when calls ring again
--    (call_service_unrung_notice). Every other refusal stays private to the
--    callee and keeps the neutral words. The server checks her own refusals
--    first (calls blocked for him, a block, calls off, silent, muted calls),
--    so "quiet hours" is only ever said when none of those applies and never
--    reveals one.
--  * Only calls that reached her count: declined; missed or cancelled after
--    her phone showed the ring (332); and calls she refused by her own
--    choice (calls off, silent, calls from him muted or blocked). Quiet
--    hours, her being on another call, no phone able to ring, her account
--    being unavailable, his plan and her calling terms never count: none of
--    those disturbed her or was her answer to him.

-- When the member's quiet hours end, if they are in them now; null otherwise.
CREATE FUNCTION private.call_quiet_hours_end(p_user uuid)
RETURNS timestamptz
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_tz text := private.member_timezone(p_user);
  v_end time;
  v_today date;
  v_until timestamptz;
BEGIN
  IF NOT private.call_in_quiet_hours(p_user) THEN RETURN NULL; END IF;
  SELECT coalesce(np.quiet_end, time '08:00') INTO v_end
  FROM public.users u
  LEFT JOIN public.notification_prefs np ON np.user_id = u.id
  WHERE u.id = p_user;
  v_today := (now() AT TIME ZONE v_tz)::date;
  v_until := (v_today + v_end) AT TIME ZONE v_tz;
  IF v_until <= now() THEN
    v_until := ((v_today + 1) + v_end) AT TIME ZONE v_tz;
  END IF;
  RETURN v_until;
END;
$function$;

-- What the caller may be told about their call that did not ring: only
-- quiet hours, with when calls ring again. Anything else: nothing.
CREATE FUNCTION public.call_service_unrung_notice(p_caller uuid, p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_request private.call_requests%ROWTYPE;
  v_until timestamptz;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_request FROM private.call_requests
  WHERE id = p_request_id AND caller_id = p_caller;
  IF NOT FOUND OR v_request.status <> 'unavailable' OR v_request.reason <> 'quiet_hours' THEN
    RETURN '{}'::jsonb;
  END IF;
  v_until := private.call_quiet_hours_end(v_request.callee_id);
  IF v_until IS NULL THEN RETURN '{}'::jsonb; END IF;
  RETURN jsonb_build_object('reason', 'quiet_hours', 'quiet_until', v_until);
END;
$function$;

-- 333: only calls that reached her, or that she refused by her own choice.
CREATE OR REPLACE FUNCTION private.call_unanswered_block_until(p_caller uuid, p_callee uuid)
RETURNS timestamptz
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_limit integer := (private.call_settings_row()).unanswered_call_limit;
  v_last_answered timestamptz;
  v_count integer;
  v_latest timestamptz;
  v_tz text := private.member_timezone(p_caller);
  v_until timestamptz;
BEGIN
  SELECT max(r.answered_at) INTO v_last_answered
  FROM private.call_requests r
  WHERE r.answered_at IS NOT NULL
    AND ((r.caller_id = p_caller AND r.callee_id = p_callee)
      OR (r.caller_id = p_callee AND r.callee_id = p_caller));

  SELECT count(*), max(r.created_at) INTO v_count, v_latest
  FROM private.call_requests r
  WHERE r.caller_id = p_caller AND r.callee_id = p_callee
    AND (r.status = 'declined'
         OR (r.status IN ('cancelled', 'missed') AND r.delivered_at IS NOT NULL)
         OR (r.status = 'unavailable'
             AND r.reason IN ('calls_off', 'silent', 'muted', 'calls_blocked')))
    AND r.created_at > now() - interval '24 hours'
    AND (v_last_answered IS NULL OR r.created_at > v_last_answered);

  IF v_count < v_limit THEN RETURN NULL; END IF;
  v_until := (date_trunc('day', v_latest AT TIME ZONE v_tz) + interval '1 day')
             AT TIME ZONE v_tz;
  RETURN CASE WHEN v_until > now() THEN v_until ELSE NULL END;
END;
$function$;

REVOKE ALL ON FUNCTION private.call_quiet_hours_end(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.call_service_unrung_notice(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.call_service_unrung_notice(uuid, uuid) TO service_role;
REVOKE ALL ON FUNCTION private.call_unanswered_block_until(uuid, uuid) FROM PUBLIC, anon, authenticated;
