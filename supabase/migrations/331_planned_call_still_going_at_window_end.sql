-- A planned call still going when its window ends is done, not missed
-- (docs/voice_calling_spec.md 13.4, gate 14, found 24 Nov 2026). Builds on 330.
--
-- The 10-second sweep closed every accepted plan whose 30-minute window had
-- passed, and counted a call as talked only by its settled seconds. A call
-- that fulfils the plan but was still ringing, live or not yet settled at
-- that moment (a long call, or one that ended seconds before and settles a
-- little later) counted as not talked: the plan was set to "expired" and
-- the members saw "Missed scheduled call". Settlement only closes plans
-- still accepted, so nothing put it right.
--
-- Now the sweep leaves an accepted plan alone while a call that fulfils it
-- is unfinished; settling that call closes the plan (330), and if they never
-- talked the next sweep expires it. The wait ends after the longest call the
-- plan's window allows (window + ring + longest hold + settling), so a call
-- that never settles cannot keep a plan open.
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
                              ELSE now() - make_interval(mins => v_settings.plan_window_minutes) END
    -- 331: not while a call that fulfils it is still ringing, live or unsettled.
    AND NOT (
      cp.status = 'accepted'
      AND cp.planned_for > now() - make_interval(
        mins => v_settings.plan_window_minutes + v_settings.max_hold_minutes + 10,
        secs => v_settings.ring_timeout_seconds + v_settings.join_timeout_seconds)
      AND EXISTS (
        SELECT 1 FROM private.call_requests r
        LEFT JOIN private.call_sessions s ON s.request_id = r.id
        WHERE r.match_id = cp.match_id
          AND private.call_plan_fulfilled_by(cp.planned_for, r.created_at)
          AND (r.status = 'ringing'
               OR s.status IN ('creating', 'active', 'ending', 'ended'))));
  GET DIAGNOSTICS v_n = ROW_COUNT; v_count := v_count + v_n;
  RETURN v_count;
END;
$function$;

REVOKE ALL ON FUNCTION private.call_close_due_plans() FROM PUBLIC, anon, authenticated;
