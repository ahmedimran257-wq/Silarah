-- The other member's name on the call screen follows the app's rule
-- (docs/voice_calling_spec.md 12.5): first name and surname initial until
-- matched, the full name once matched. Added 23 Nov 2026 after the two-phone
-- test showed "Imran A." on a matched member's call screen.
--
-- Unchanged: Stream's user name stays first name + initial (spec 7), and
-- every push stays first name only (spec 12.3). Only the name the app shows
-- changes; it is never sent to Stream or in a push.

-- The name a member sees for the other member of a call's match.
CREATE FUNCTION private.call_shown_name(p_other uuid, p_match_id uuid)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT CASE
    WHEN EXISTS (SELECT 1 FROM public.matches m WHERE m.id = p_match_id AND m.status = 'active')
    THEN coalesce((
      SELECT trim(coalesce(nullif(trim(p.first_name), ''), 'Silarah member')
                  || coalesce(' ' || nullif(trim(p.last_name), ''), ''))
      FROM public.profiles p WHERE p.user_id = p_other
    ), 'Silarah member')
    ELSE private.call_display_name(p_other)
  END;
$function$;

-- 328: the answering member's app is told the caller's shown name.
CREATE OR REPLACE FUNCTION public.call_service_accept(
  p_user uuid, p_request_id uuid, p_device_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_settings private.call_settings := private.call_settings_row();
  v_request private.call_requests%ROWTYPE;
  v_fail text;
  v_hold integer;
  v_stream_id text;
  v_max integer;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_request FROM private.call_requests WHERE id = p_request_id;
  IF NOT FOUND OR v_request.callee_id <> p_user THEN
    RETURN jsonb_build_object('outcome', 'not_found');
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(least(v_request.caller_id, v_request.callee_id)::text, 323));
  PERFORM pg_advisory_xact_lock(hashtextextended(greatest(v_request.caller_id, v_request.callee_id)::text, 323));
  -- First device to answer wins; the rest see "answered".
  SELECT * INTO v_request FROM private.call_requests WHERE id = p_request_id FOR UPDATE;
  IF v_request.status = 'accepted' THEN
    RETURN jsonb_build_object('outcome', 'already_answered');
  END IF;
  IF v_request.status <> 'ringing' THEN
    RETURN jsonb_build_object('outcome', v_request.status);
  END IF;
  IF v_request.ring_expires_at <= now() THEN
    UPDATE private.call_requests SET status = 'missed', reason = 'timeout', closed_at = now()
    WHERE id = p_request_id;
    PERFORM private.call_queue_missed_note(p_request_id);
    RETURN jsonb_build_object('outcome', 'missed');
  END IF;

  v_fail := CASE
    WHEN NOT v_settings.calls_enabled THEN 'calls_disabled'
    WHEN private.call_member_block_reason(v_request.caller_id) IS NOT NULL THEN 'caller_unavailable'
    WHEN private.call_member_block_reason(v_request.callee_id) IS NOT NULL THEN 'account_restricted'
    WHEN private.call_match_block_reason(v_request.match_id, v_request.callee_id) IS NOT NULL THEN 'not_allowed'
    WHEN NOT private.call_premium_rule_ok(v_request.caller_id, v_request.callee_id) THEN 'premium_required'
    WHEN private.call_user_busy(v_request.caller_id, p_request_id) THEN 'caller_busy'
    WHEN private.call_user_busy(v_request.callee_id, p_request_id) THEN 'busy_self'
    ELSE NULL
  END;
  IF v_fail IS NOT NULL THEN
    UPDATE private.call_requests SET status = 'failed', reason = v_fail, closed_at = now()
    WHERE id = p_request_id;
    PERFORM private.call_enqueue_job('cancel_ring', p_request_id, v_request.callee_id);
    RETURN jsonb_build_object('outcome', 'failed', 'reason', v_fail);
  END IF;

  v_stream_id := replace(p_request_id::text, '-', '');
  INSERT INTO private.call_sessions(
    request_id, stream_call_id, match_id, caller_id, callee_id, status,
    hold_minutes, max_duration_seconds
  ) VALUES (
    p_request_id, v_stream_id, v_request.match_id, v_request.caller_id,
    v_request.callee_id, 'creating', 0, 1
  );
  v_hold := private.call_place_hold(p_request_id, v_request.caller_id);
  IF v_hold < 1 THEN
    DELETE FROM private.call_sessions WHERE request_id = p_request_id;
    UPDATE private.call_requests SET status = 'failed', reason = 'caller_no_minutes', closed_at = now()
    WHERE id = p_request_id;
    PERFORM private.call_enqueue_job('cancel_ring', p_request_id, v_request.callee_id);
    RETURN jsonb_build_object('outcome', 'failed', 'reason', 'caller_no_minutes');
  END IF;
  v_max := v_hold * 60 + v_settings.connect_allowance_seconds;
  UPDATE private.call_sessions
  SET hold_minutes = v_hold, max_duration_seconds = v_max
  WHERE request_id = p_request_id;
  UPDATE private.call_requests
  SET status = 'accepted', answered_at = now(), answered_device = left(p_device_id, 200)
  WHERE id = p_request_id;

  RETURN jsonb_build_object(
    'outcome', 'accepted',
    'request_id', p_request_id,
    'match_id', v_request.match_id,
    'stream_call_id', v_stream_id,
    'call_type', 'silarah_voice',
    'caller_id', v_request.caller_id,
    'callee_id', v_request.callee_id,
    'caller_name', private.call_display_name(v_request.caller_id),
    'callee_name', private.call_display_name(v_request.callee_id),
    -- 328: what the callee's app shows (Stream keeps caller_name).
    'caller_shown_name', private.call_shown_name(v_request.caller_id, v_request.match_id),
    'hold_minutes', v_hold,
    'max_duration_seconds', v_max
  );
END;
$function$;

-- 328: the call screen shows the matched member's full name.
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
      'ring_expires_at', v_request.ring_expires_at);
  END IF;
  SELECT * INTO v_session FROM private.call_sessions WHERE request_id = p_request_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('outcome', v_request.status, 'reason', v_request.reason);
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

REVOKE ALL ON FUNCTION private.call_shown_name(uuid, uuid) FROM PUBLIC, anon, authenticated;
