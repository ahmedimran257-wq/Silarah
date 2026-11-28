-- A ring is "Ringing" only once it reached the callee's phone, and only a
-- ring that reached it counts towards the unanswered-call limit
-- (docs/voice_calling_spec.md 4 and 12.2; found on the phones 25 Nov 2026).
-- Builds on 323 and 328.
--
-- With the callee's mobile data off, the caller saw "Ringing…" for the whole
-- ring, and the unanswered call counted towards the limit of 3 a day as if it
-- had rung: a man could be blocked for calls she never saw. Like WhatsApp's
-- "Calling" and "Ringing", the callee's phone now sends a receipt the moment
-- it shows the ring, proven with the ring's own token (the one the
-- notification's Decline uses, which reached only her own phones), so it
-- works with Silarah closed and no session. The caller's screen says
-- "Calling…" until then and "Ringing…" after; a ring that never arrived
-- ends as "Couldn't reach their phone". Declined, missed or cancelled calls
-- count only when they reached her phone; a refused call ("unavailable":
-- calls off, silent, quiet hours) counts as before, as it is her choice.

ALTER TABLE private.call_requests ADD COLUMN delivered_at timestamptz;

COMMENT ON COLUMN private.call_requests.delivered_at IS
  'When a device of the callee first showed this ring (its receipt). Null: the ring never reached a phone.';

-- The callee's phone showed the ring. Idempotent; the token is checked, not
-- used up (Decline still needs it).
CREATE FUNCTION public.call_service_ring_delivered(p_request_id uuid, p_token text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_request private.call_requests%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_request FROM private.call_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND OR v_request.decline_token_hash IS NULL OR p_token IS NULL
    OR length(p_token) <> 48
    OR encode(extensions.digest(p_token, 'sha256'), 'hex') <> v_request.decline_token_hash THEN
    RETURN jsonb_build_object('outcome', 'not_found');
  END IF;
  -- Only a ring still ringing can arrive: a late push never rings either.
  IF v_request.status <> 'ringing' THEN
    RETURN jsonb_build_object('outcome', v_request.status);
  END IF;
  IF v_request.delivered_at IS NULL THEN
    UPDATE private.call_requests SET delivered_at = now() WHERE id = p_request_id;
  END IF;
  RETURN jsonb_build_object('outcome', 'delivered');
END;
$function$;

-- 332: the caller's status says whether the ring reached the callee's phone.
CREATE OR REPLACE FUNCTION public.call_service_join(p_user uuid, p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_session private.call_sessions%ROWTYPE;
  v_request private.call_requests%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_request FROM private.call_requests WHERE id = p_request_id;
  IF NOT FOUND OR p_user NOT IN (v_request.caller_id, v_request.callee_id) THEN
    RETURN jsonb_build_object('outcome', 'not_found');
  END IF;
  IF v_request.status = 'ringing' THEN
    RETURN jsonb_build_object('outcome', 'ringing',
      'ring_expires_at', v_request.ring_expires_at,
      'delivered', v_request.delivered_at IS NOT NULL);
  END IF;
  SELECT * INTO v_session FROM private.call_sessions WHERE request_id = p_request_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('outcome', v_request.status, 'reason', v_request.reason,
      'delivered', v_request.delivered_at IS NOT NULL);
  END IF;
  IF v_session.status = 'creating' THEN
    RETURN jsonb_build_object('outcome', 'connecting');
  END IF;
  IF v_session.status <> 'active' THEN
    RETURN jsonb_build_object('outcome', 'ended', 'reason', v_session.end_reason);
  END IF;
  RETURN jsonb_build_object(
    'outcome', 'active',
    'request_id', p_request_id,
    'match_id', v_session.match_id,
    'stream_call_id', v_session.stream_call_id,
    'call_type', 'silarah_voice',
    'caller_id', v_session.caller_id,
    'callee_id', v_session.callee_id,
    'role', CASE WHEN p_user = v_session.caller_id THEN 'caller' ELSE 'callee' END,
    'my_name', private.call_display_name(p_user),
    -- 328: shown in the app only (my_name stays Stream's short name).
    'other_name', private.call_shown_name(
      CASE WHEN p_user = v_session.caller_id THEN v_session.callee_id ELSE v_session.caller_id END,
      v_session.match_id),
    'hold_minutes', v_session.hold_minutes,
    'max_duration_seconds', v_session.max_duration_seconds,
    'accepted_at', v_session.accepted_at
  );
END;
$function$;

-- 332: 3 unanswered calls to the same person in 24 h, counting only calls
-- that reached her phone (declined is proof it did), plus refused calls.
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
    AND (r.status IN ('declined', 'unavailable')
         OR (r.status IN ('cancelled', 'missed') AND r.delivered_at IS NOT NULL))
    AND r.created_at > now() - interval '24 hours'
    AND (v_last_answered IS NULL OR r.created_at > v_last_answered);

  IF v_count < v_limit THEN RETURN NULL; END IF;
  v_until := (date_trunc('day', v_latest AT TIME ZONE v_tz) + interval '1 day')
             AT TIME ZONE v_tz;
  RETURN CASE WHEN v_until > now() THEN v_until ELSE NULL END;
END;
$function$;

REVOKE ALL ON FUNCTION public.call_service_ring_delivered(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.call_service_ring_delivered(uuid, text) TO service_role;
REVOKE ALL ON FUNCTION public.call_service_join(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.call_service_join(uuid, uuid) TO service_role;
REVOKE ALL ON FUNCTION private.call_unanswered_block_until(uuid, uuid) FROM PUBLIC, anon, authenticated;
