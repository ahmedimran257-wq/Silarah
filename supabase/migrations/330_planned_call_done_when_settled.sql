-- A planned call is done as soon as its call is settled (docs/voice_calling_spec.md 13.4,
-- added 23 Nov 2026 after the two-phone test). Builds on 324.
--
-- A plan closed only in the sweep after its 30-minute window, so after the
-- two had talked the plan stayed pinned with "Call now" for up to half an
-- hour. One rule now says which call fulfils a plan; settling a connected
-- call closes the plan it fulfils, and the sweep keeps closing the rest.

-- A call made at p_call_at fulfils a plan for p_planned_for: from the
-- planning lead before the time until the window after it.
CREATE FUNCTION private.call_plan_fulfilled_by(p_planned_for timestamptz, p_call_at timestamptz)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT p_call_at BETWEEN p_planned_for - make_interval(mins => s.plan_min_lead_minutes)
                       AND p_planned_for + make_interval(mins => s.plan_window_minutes)
  FROM private.call_settings s WHERE s.id;
$function$;

-- 330: the same rule as settlement.
CREATE OR REPLACE FUNCTION private.call_close_due_plans()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_settings private.call_settings := private.call_settings_row();
  v_count integer := 0;
  v_n integer;
BEGIN
  -- Plans end when the chat ends, someone blocks, or the man's Premium ends.
  UPDATE private.call_plans cp SET status = 'cancelled', closed_at = now()
  WHERE cp.status IN ('proposed', 'accepted')
    AND (private.call_match_block_reason(cp.match_id, cp.proposer_id) IS NOT NULL
         OR NOT private.call_pair_premium_ok(cp.proposer_id, cp.invitee_id));
  GET DIAGNOSTICS v_n = ROW_COUNT; v_count := v_count + v_n;

  UPDATE private.call_plans cp
  SET status = CASE WHEN cp.status = 'accepted' AND EXISTS (
        SELECT 1 FROM private.call_requests r
        JOIN private.call_sessions s ON s.request_id = r.id
        WHERE r.match_id = cp.match_id
          AND private.call_plan_fulfilled_by(cp.planned_for, r.created_at)
          AND coalesce(s.connected_seconds, 0) > 0
      ) THEN 'done' ELSE 'expired' END,
      closed_at = now()
  WHERE cp.status IN ('proposed', 'accepted')
    AND cp.planned_for < CASE WHEN cp.status = 'proposed' THEN now()
                              ELSE now() - make_interval(mins => v_settings.plan_window_minutes) END;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_count := v_count + v_n;
  RETURN v_count;
END;
$function$;

-- 330: settling a connected call closes the plan it fulfils.
CREATE OR REPLACE FUNCTION public.call_service_settle(
  p_request_id uuid,
  p_connected_seconds integer,
  p_source text,
  p_stream_session_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_cap integer;
  v_settings private.call_settings := private.call_settings_row();
  v_session private.call_sessions%ROWTYPE;
  v_seconds integer := greatest(coalesce(p_connected_seconds, 0), 0);
  v_charge integer;
  v_result record;
  v_month date := private.call_month_start();
  v_used integer;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_session FROM private.call_sessions WHERE request_id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('outcome', 'not_found'); END IF;
  IF v_session.status IN ('settled', 'failed') THEN
    RETURN jsonb_build_object('outcome', 'already_settled',
      'charged_minutes', v_session.charged_minutes);
  END IF;
  IF v_session.status <> 'ended' THEN
    RETURN jsonb_build_object('outcome', 'not_ended');
  END IF;

  v_charge := least(ceil(v_seconds / 60.0)::integer, v_session.hold_minutes);
  SELECT * INTO v_result FROM private.call_release_holds(
    p_request_id, v_charge, 'settled:' || left(coalesce(p_source, 'unknown'), 40));
  UPDATE private.call_sessions
  SET status = 'settled',
      connected_seconds = v_seconds,
      charged_minutes = v_charge,
      charged_included_minutes = v_result.charged_included,
      charged_pack_minutes = v_result.charged_pack,
      settled_at = now(),
      settle_source = left(p_source, 40),
      stream_session_id = coalesce(stream_session_id, left(p_stream_session_id, 200))
  WHERE request_id = p_request_id;
  UPDATE private.call_requests SET closed_at = coalesce(closed_at, now())
  WHERE id = p_request_id;

  -- 330: a connected call closes the plan it fulfils at once.
  IF v_seconds > 0 THEN
    UPDATE private.call_plans cp SET status = 'done', closed_at = now()
    FROM private.call_requests r
    WHERE r.id = p_request_id
      AND cp.match_id = r.match_id
      AND cp.status = 'accepted'
      AND private.call_plan_fulfilled_by(cp.planned_for, r.created_at);
  END IF;

  INSERT INTO private.call_usage_months(month_start, charged_minutes)
  VALUES (v_month, v_charge)
  ON CONFLICT (month_start) DO UPDATE
  SET charged_minutes = private.call_usage_months.charged_minutes + EXCLUDED.charged_minutes,
      updated_at = now()
  RETURNING charged_minutes INTO v_used;

  -- 324: alerts against the brake actually in force.
  v_cap := private.call_month_cap_minutes();
  IF v_cap > 0 THEN
    PERFORM private.set_operational_alert(
      'voice_call_minutes_70',
      format('Voice calls used %s of the %s-minute monthly brake (70%% alert).', v_used, v_cap),
      v_used, v_used >= v_cap * 0.7);
    PERFORM private.set_operational_alert(
      'voice_call_minutes_90',
      format('Voice calls used %s of the %s-minute monthly brake (90%% alert). New calls pause at 100%%.',
             v_used, v_cap),
      v_used, v_used >= v_cap * 0.9);
  END IF;

  RETURN jsonb_build_object(
    'outcome', 'settled',
    'connected_seconds', v_seconds,
    'charged_minutes', v_charge,
    'charged_included_minutes', v_result.charged_included,
    'charged_pack_minutes', v_result.charged_pack
  );
END;
$function$;

REVOKE ALL ON FUNCTION private.call_plan_fulfilled_by(timestamptz, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.call_close_due_plans() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.call_service_settle(uuid, integer, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.call_service_settle(uuid, integer, text, text) TO service_role;
