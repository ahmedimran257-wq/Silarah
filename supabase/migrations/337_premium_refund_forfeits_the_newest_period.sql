-- 337: a Premium refund removes the included minutes of the period that
-- purchase paid for: the newest one.
--
-- Found on the phones (gate 6 / gap 4, 25 Nov 2026): a member whose earlier
-- run (a test grant) still had a period open bought Premium, then the
-- purchase was refunded. The forfeit picked any open period (no ORDER BY)
-- and hit the old one (already used up, 0 minutes), leaving the refunded
-- period's 30 minutes untouched; a reversed refund would bring them back and
-- the data export said 0 forfeited. Overlapping periods are normal (a new
-- run starts while an older period has days left), so the refunded purchase's
-- period is always the newest open one.

CREATE OR REPLACE FUNCTION public.call_service_forfeit_included(p_user uuid, p_event_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_period private.call_included_periods%ROWTYPE;
  v_remaining integer;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF EXISTS (SELECT 1 FROM private.call_ledger WHERE provider_event_id = p_event_id) THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'duplicate');
  END IF;
  -- 337: the newest open period is the one the refunded purchase paid for.
  SELECT * INTO v_period FROM private.call_included_periods cp
  WHERE cp.user_id = p_user AND cp.period_start <= now() AND cp.period_end > now()
    AND cp.forfeited_at IS NULL
  ORDER BY cp.period_start DESC
  LIMIT 1
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'no_current_period');
  END IF;
  v_remaining := greatest(v_period.granted_minutes - v_period.used_minutes, 0);
  UPDATE private.call_included_periods SET forfeited_at = now()
  WHERE user_id = p_user AND period_start = v_period.period_start;
  INSERT INTO private.call_ledger(user_id, kind, included_minutes_delta, provider_event_id, note)
  VALUES (p_user, 'included_forfeit', -v_remaining, p_event_id, 'premium_refunded');
  RETURN jsonb_build_object('applied', true, 'minutes', -v_remaining);
END;
$function$;

REVOKE ALL ON FUNCTION public.call_service_forfeit_included(uuid, text) FROM PUBLIC, anon, authenticated;
