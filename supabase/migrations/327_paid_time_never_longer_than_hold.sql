-- Paid talk time is never longer than the hold (docs/voice_calling_spec.md 5,
-- added 23 Nov 2026 after the two-phone test). Builds on 323-326.
--
-- Stream's time limit is the hold plus a connect allowance (30 s) so that
-- slow joining never eats into paid time. Billing stops at the hold, so
-- when both joined quickly the rest of the allowance was free talk: a
-- 3-minute hold ran 3:29 in the test (joining took 4 s). The app now ends
-- the call at 0, but the server must not rely on the app. Once Stream says
-- both members are in, the allowance shrinks to the real connect time
-- (plus 2 s for clock skew between Stream's events), Stream's limit is set
-- to that, and "Add minutes" builds on it.

ALTER TABLE private.call_sessions
  -- Seconds from the first join to both joined (capped at the allowance);
  -- NULL until both are in.
  ADD COLUMN connect_seconds integer CHECK (connect_seconds IS NULL OR connect_seconds >= 0);

-- Stream's limit for a hold: paid time + the real connect time when known.
CREATE FUNCTION private.call_stream_limit(p_hold_minutes integer, p_connect_seconds integer)
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT p_hold_minutes * 60 + CASE
    WHEN p_connect_seconds IS NULL THEN s.connect_allowance_seconds
    ELSE least(p_connect_seconds + 2, s.connect_allowance_seconds) END
  FROM private.call_settings s WHERE s.id;
$function$;

-- 327: the connect allowance shrinks once both are in.
CREATE OR REPLACE FUNCTION public.call_service_record_stream_event(
  p_webhook_id text,
  p_event_type text,
  p_stream_call_id text,
  p_stream_session_id text,
  p_user_id text,
  p_user_session_id text,
  p_occurred_at timestamptz,
  p_duration_seconds integer
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_session private.call_sessions%ROWTYPE;
  v_limit integer;
  v_user uuid;
  v_action text := 'none';
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  INSERT INTO private.stream_webhook_deliveries(webhook_id, event_type)
  VALUES (left(p_webhook_id, 200), left(p_event_type, 100))
  ON CONFLICT (webhook_id) DO NOTHING;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('duplicate', true);
  END IF;

  SELECT * INTO v_session FROM private.call_sessions
  WHERE stream_call_id = p_stream_call_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('duplicate', false, 'known', false);
  END IF;
  IF p_user_id ~ '^[0-9a-f-]{36}$' THEN v_user := p_user_id::uuid; END IF;

  IF p_event_type IN ('call.session_participant_joined', 'call.session_participant_left')
    AND v_user IN (v_session.caller_id, v_session.callee_id) THEN
    INSERT INTO private.call_participant_events(
      request_id, user_id, user_session_id, stream_session_id, kind,
      occurred_at, duration_seconds
    ) VALUES (
      v_session.request_id, v_user, left(p_user_session_id, 200),
      left(p_stream_session_id, 200),
      CASE WHEN p_event_type = 'call.session_participant_joined' THEN 'joined' ELSE 'left' END,
      coalesce(p_occurred_at, now()), p_duration_seconds
    );
  END IF;

  IF p_event_type = 'call.session_participant_joined'
    AND v_user IN (v_session.caller_id, v_session.callee_id) THEN
    UPDATE private.call_sessions
    SET caller_joined_at = CASE WHEN v_user = caller_id
          THEN coalesce(caller_joined_at, coalesce(p_occurred_at, now())) ELSE caller_joined_at END,
        callee_joined_at = CASE WHEN v_user = callee_id
          THEN coalesce(callee_joined_at, coalesce(p_occurred_at, now())) ELSE callee_joined_at END,
        stream_session_id = coalesce(stream_session_id, left(p_stream_session_id, 200))
    WHERE request_id = v_session.request_id;
    -- 327: both are in: the allowance shrinks to the real connect time and
    -- Stream's limit follows (the webhook sends it).
    UPDATE private.call_sessions
    SET both_joined_at = greatest(caller_joined_at, callee_joined_at),
        connect_seconds = greatest(ceil(extract(epoch FROM
          greatest(caller_joined_at, callee_joined_at) - least(caller_joined_at, callee_joined_at)))::integer, 0),
        max_duration_seconds = private.call_stream_limit(hold_minutes, greatest(ceil(extract(epoch FROM
          greatest(caller_joined_at, callee_joined_at) - least(caller_joined_at, callee_joined_at)))::integer, 0))
    WHERE request_id = v_session.request_id
      AND both_joined_at IS NULL
      AND caller_joined_at IS NOT NULL AND callee_joined_at IS NOT NULL
      AND status IN ('creating', 'active')
    RETURNING max_duration_seconds INTO v_limit;
    IF v_limit IS NOT NULL THEN
      v_action := 'set_limit';
    END IF;
  ELSIF p_event_type = 'call.session_participant_left'
    AND v_user IN (v_session.caller_id, v_session.callee_id)
    AND v_session.status IN ('creating', 'active') THEN
    -- Either member leaving ends the call. The worker first confirms with
    -- Stream that the member has not reconnected.
    v_action := 'check_left';
  ELSIF p_event_type IN ('call.session_ended', 'call.ended') THEN
    UPDATE private.call_sessions
    SET status = CASE WHEN status IN ('creating', 'active', 'ending') THEN 'ended' ELSE status END,
        end_reason = coalesce(end_reason, CASE WHEN p_event_type = 'call.ended'
          THEN 'stream_ended' ELSE 'session_ended' END),
        ended_at = coalesce(ended_at, now()),
        stream_session_id = coalesce(stream_session_id, left(p_stream_session_id, 200))
    WHERE request_id = v_session.request_id;
    IF v_session.status NOT IN ('settled', 'failed') THEN
      PERFORM private.call_enqueue_job('settle', v_session.request_id, NULL, interval '3 seconds');
      v_action := 'settle';
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'duplicate', false, 'known', true,
    'request_id', v_session.request_id,
    'action', v_action,
    'stream_call_id', v_session.stream_call_id,
    'max_duration_seconds', v_limit
  );
END;
$function$;

-- 327: "Add minutes" keeps the real connect time.
CREATE OR REPLACE FUNCTION public.call_service_extend(p_user uuid, p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_settings private.call_settings := private.call_settings_row();
  v_session private.call_sessions%ROWTYPE;
  v_added integer;
  v_max integer;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_session FROM private.call_sessions WHERE request_id = p_request_id FOR UPDATE;
  IF NOT FOUND OR v_session.caller_id <> p_user THEN
    RETURN jsonb_build_object('outcome', 'not_found');
  END IF;
  IF v_session.status <> 'active' THEN
    RETURN jsonb_build_object('outcome', 'ended');
  END IF;
  IF NOT v_settings.calls_enabled
    OR NOT private.call_premium_rule_ok(v_session.caller_id, v_session.callee_id) THEN
    RETURN jsonb_build_object('outcome', 'not_allowed');
  END IF;
  v_added := private.call_place_hold(p_request_id, p_user);
  IF v_added < 1 THEN
    RETURN jsonb_build_object('outcome', 'no_minutes');
  END IF;
  -- 327: on top of the real connect time once known.
  v_max := private.call_stream_limit(v_session.hold_minutes + v_added, v_session.connect_seconds);
  UPDATE private.call_sessions
  SET hold_minutes = hold_minutes + v_added, max_duration_seconds = v_max
  WHERE request_id = p_request_id;
  RETURN jsonb_build_object(
    'outcome', 'extended',
    'stream_call_id', v_session.stream_call_id,
    'added_minutes', v_added,
    'hold_minutes', v_session.hold_minutes + v_added,
    'max_duration_seconds', v_max
  );
END;
$function$;

REVOKE ALL ON FUNCTION private.call_stream_limit(integer, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.call_service_record_stream_event(text, text, text, text, text, text, timestamptz, integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.call_service_record_stream_event(text, text, text, text, text, text, timestamptz, integer)
  TO service_role;
REVOKE ALL ON FUNCTION public.call_service_extend(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.call_service_extend(uuid, uuid) TO service_role;
