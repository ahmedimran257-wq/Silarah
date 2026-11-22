-- Rollback test for voice calling (migrations 323 and 324). Run against
-- STAGING only:
--   supabase db query --remote=ykmgkrveucslglxvcyss --file <(BEGIN + 323/324 if not applied + this) --yes
-- Everything happens inside one transaction that ends in ROLLBACK, so no
-- fixture, call, minute or notification survives. The last SELECT prints
-- one row per rule with ok = true/false.
BEGIN;

CREATE TEMP TABLE t_results (n serial, name text, ok boolean, detail text) ON COMMIT DROP;

CREATE FUNCTION pg_temp.ok(p_name text, p_ok boolean, p_detail text DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO t_results(name, ok, detail) VALUES (p_name, coalesce(p_ok, false), p_detail);
$$;

-- Runs a statement as the edge functions do (service_role) and returns jsonb.
CREATE FUNCTION pg_temp.svc(p_sql text) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', '{"role":"service_role"}', true);
  PERFORM set_config('role', 'service_role', true);
  EXECUTE p_sql INTO v;
  PERFORM set_config('role', 'postgres', true);
  RETURN v;
EXCEPTION WHEN OTHERS THEN
  PERFORM set_config('role', 'postgres', true);
  RETURN jsonb_build_object('error', SQLSTATE, 'message', SQLERRM);
END $$;

-- Runs a statement as a signed-in member.
CREATE FUNCTION pg_temp.usr(p_user uuid, p_sql text) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims',
    jsonb_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  EXECUTE p_sql INTO v;
  PERFORM set_config('role', 'postgres', true);
  RETURN v;
EXCEPTION WHEN OTHERS THEN
  PERFORM set_config('role', 'postgres', true);
  RETURN jsonb_build_object('error', SQLSTATE, 'message', SQLERRM);
END $$;

-- One phone that can ring (migration 324: only such phones are rung).
-- Account deletion removes push tokens, so restores call this again.
CREATE FUNCTION pg_temp.phone(p_id uuid) RETURNS void LANGUAGE sql AS $$
  INSERT INTO public.user_fcm_tokens(user_id, device_id, fcm_token, platform)
  VALUES (p_id, 'vcqa-' || replace(p_id::text, '-', ''), 'vcqa-token-' || p_id, 'android')
  ON CONFLICT (user_id, device_id) DO NOTHING;
  INSERT INTO private.call_device_capabilities(user_id, device_id, can_ring)
  VALUES (p_id, 'vcqa-' || replace(p_id::text, '-', ''), true)
  ON CONFLICT (user_id, device_id) DO UPDATE SET can_ring = true;
$$;

CREATE FUNCTION pg_temp.member(p_id uuid, p_gender text, p_first text, p_premium boolean)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO auth.users(id, aud, role, email, email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data)
  VALUES (p_id, 'authenticated', 'authenticated',
    'vcqa.' || right(p_id::text, 4) || '@gmail.com', now(), now(), now(), '{}', '{}');
  INSERT INTO public.users(id, email, gender, country_code, timezone,
    subscription_status, subscription_expires_at)
  VALUES (p_id, 'vcqa.' || right(p_id::text, 4) || '@gmail.com', p_gender, 'IN', 'Asia/Kolkata',
    CASE WHEN p_premium THEN 'active' ELSE 'none' END,
    CASE WHEN p_premium THEN now() + interval '30 days' END);
  INSERT INTO public.profiles(user_id, first_name, last_name, date_of_birth, gender,
    country_code, visibility, onboarding_completed)
  VALUES (p_id, p_first, 'Qatest', date '1995-01-01', p_gender, 'IN', 'visible', true);
  PERFORM pg_temp.phone(p_id);
  -- No quiet hours unless a test sets them.
  INSERT INTO public.notification_prefs(user_id, quiet_start, quiet_end)
  VALUES (p_id, time '00:00', time '00:00')
  ON CONFLICT (user_id) DO UPDATE SET quiet_start = time '00:00', quiet_end = time '00:00';
END $$;

CREATE FUNCTION pg_temp.match(p_a uuid, p_b uuid) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v uuid;
BEGIN
  INSERT INTO public.matches(user_a, user_b, status, guardian_approved)
  VALUES (p_a, p_b, 'active', true) RETURNING id INTO v;
  RETURN v;
END $$;

-- Clears call history between scenarios (unanswered-call limit etc.).
CREATE FUNCTION pg_temp.reset_calls() RETURNS void LANGUAGE sql AS $$
  DELETE FROM private.call_jobs;
  DELETE FROM private.call_requests;
  DELETE FROM private.call_ledger;
  DELETE FROM private.call_included_periods;
  DELETE FROM private.call_wallets;
  DELETE FROM private.call_usage_months;
  DELETE FROM private.call_member_prefs;
  DELETE FROM private.call_pair_prefs;
  -- The hourly entitlement cap (324) is tested on its own; here the floor.
  UPDATE private.call_settings SET calls_enabled = true, monthly_cap_minutes = 100000,
    auto_cap_minutes = NULL, auto_cap_at = NULL;
$$;

DO $$
DECLARE
  m1 uuid := '00000000-0000-4000-8000-0000000c0001'; -- man, Premium
  w1 uuid := '00000000-0000-4000-8000-0000000c0002'; -- woman, free
  m2 uuid := '00000000-0000-4000-8000-0000000c0003'; -- man, free
  w2 uuid := '00000000-0000-4000-8000-0000000c0004'; -- woman, Premium
  m3 uuid := '00000000-0000-4000-8000-0000000c0005'; -- man, Premium
  k_m1w1 uuid; k_w2m2 uuid; k_m1w2 uuid; k_m3w1 uuid; k_m3w2 uuid;
  r jsonb; r2 jsonb; rid uuid; rid2 uuid; tok text; n integer; v_text text;
  w record;
BEGIN
  PERFORM pg_temp.member(m1, 'male', 'Ahmed', true);
  PERFORM pg_temp.member(w1, 'female', 'Aisha', false);
  PERFORM pg_temp.member(m2, 'male', 'Bilal', false);
  PERFORM pg_temp.member(w2, 'female', 'Fatima', true);
  PERFORM pg_temp.member(m3, 'male', 'Kareem', true);
  k_m1w1 := pg_temp.match(m1, w1);
  k_w2m2 := pg_temp.match(w2, m2);
  k_m1w2 := pg_temp.match(m1, w2);
  k_m3w1 := pg_temp.match(m3, w1);
  k_m3w2 := pg_temp.match(m3, w2);
  PERFORM pg_temp.reset_calls();

  -- ---- Switch -------------------------------------------------------------
  UPDATE private.call_settings SET calls_enabled = false;
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('switch off: no calls', r->>'outcome' = 'calls_disabled', r::text);
  PERFORM pg_temp.ok('switch defaults to off', NOT (SELECT calls_enabled FROM private.call_settings
    WHERE id) , NULL);
  UPDATE private.call_settings SET calls_enabled = true;

  -- ---- Access rules (spec 2) ------------------------------------------------
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', w1, k_m1w1));
  PERFORM pg_temp.ok('free woman cannot start a call', r->>'outcome' = 'premium_required', r::text);
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m2, k_w2m2));
  PERFORM pg_temp.ok('free man cannot start a call', r->>'outcome' = 'premium_required', r::text);
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m2, k_m1w1));
  PERFORM pg_temp.ok('non-member of the match cannot call', r->>'outcome' = 'not_allowed', r::text);

  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', w2, k_w2m2));
  PERFORM pg_temp.ok('free man is not rung (neutral answer)', r->>'outcome' = 'unavailable', r::text);
  PERFORM pg_temp.ok('free man gets a missed-call push job',
    EXISTS (SELECT 1 FROM private.call_jobs WHERE kind = 'missed_push'
            AND request_id = (r->>'request_id')::uuid), NULL);
  PERFORM pg_temp.ok('free man reason recorded',
    (SELECT reason FROM private.call_requests WHERE id = (r->>'request_id')::uuid) = 'callee_needs_premium', NULL);
  PERFORM pg_temp.ok('caller response hides the reason', NOT (r ? 'reason'), r::text);

  -- ---- Ringing and answer ---------------------------------------------------
  PERFORM pg_temp.reset_calls();
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  rid := (r->>'request_id')::uuid; tok := r->>'decline_token';
  PERFORM pg_temp.ok('premium man rings free woman', r->>'outcome' = 'ringing', r::text);
  PERFORM pg_temp.ok('ring push name is the first name only', r->>'caller_name' = 'Ahmed', r->>'caller_name');
  PERFORM pg_temp.ok('decline token is 48 hex chars and stored hashed',
    length(tok) = 48 AND (SELECT decline_token_hash FROM private.call_requests WHERE id = rid) <> tok, NULL);
  r2 := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w2));
  PERFORM pg_temp.ok('caller already ringing cannot start another call', r2->>'outcome' = 'busy_self', r2::text);
  r2 := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m3, k_m3w1));
  PERFORM pg_temp.ok('busy callee is not rung', r2->>'outcome' = 'unavailable'
    AND (SELECT reason FROM private.call_requests WHERE id = (r2->>'request_id')::uuid) = 'busy', r2::text);

  r := pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, %L)', m2, rid, 'dev-x'));
  PERFORM pg_temp.ok('only the callee can answer', r->>'outcome' = 'not_found', r::text);
  r := pg_temp.svc(format('SELECT public.call_service_join(%L, %L)', m1, rid));
  PERFORM pg_temp.ok('no token while ringing', r->>'outcome' = 'ringing', r::text);

  r := pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, %L)', w1, rid, 'dev-a'));
  PERFORM pg_temp.ok('free woman can answer', r->>'outcome' = 'accepted', r::text);
  PERFORM pg_temp.ok('hold = min(balance 30, 60) = 30', (r->>'hold_minutes')::int = 30, r::text);
  PERFORM pg_temp.ok('max duration = hold + 30 s', (r->>'max_duration_seconds')::int = 1830, r::text);
  PERFORM pg_temp.ok('new Stream call id per call', r->>'stream_call_id' = replace(rid::text, '-', ''), NULL);
  r2 := pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, %L)', w1, rid, 'dev-b'));
  PERFORM pg_temp.ok('first device wins', r2->>'outcome' = 'already_answered', r2::text);
  SELECT * INTO w FROM private.call_wallet_state(m1);
  PERFORM pg_temp.ok('held minutes are unavailable', w.available_minutes = 0, w::text);

  r := pg_temp.svc(format('SELECT public.call_service_join(%L, %L)', m1, rid));
  PERFORM pg_temp.ok('no token before Stream call exists', r->>'outcome' = 'connecting', r::text);
  PERFORM pg_temp.svc(format('SELECT to_jsonb(public.call_service_session_started(%L))', rid));
  r := pg_temp.svc(format('SELECT public.call_service_join(%L, %L)', m1, rid));
  PERFORM pg_temp.ok('caller gets join info once live', r->>'outcome' = 'active' AND r->>'role' = 'caller', r::text);
  r := pg_temp.svc(format('SELECT public.call_service_join(%L, %L)', m2, rid));
  PERFORM pg_temp.ok('outsider gets no join info', r->>'outcome' = 'not_found', r::text);

  -- ---- Top-up mid-call -------------------------------------------------------
  r := pg_temp.svc(format('SELECT public.call_service_extend(%L, %L)', m1, rid));
  PERFORM pg_temp.ok('extend without balance refused', r->>'outcome' = 'no_minutes', r::text);
  r := pg_temp.svc(format('SELECT public.call_service_extend(%L, %L)', w1, rid));
  PERFORM pg_temp.ok('callee cannot extend (caller pays)', r->>'outcome' = 'not_found', r::text);
  r := pg_temp.svc(format('SELECT public.call_service_credit_pack(%L, %L, %L, %L)',
    m1, 'evt-1', 'GPA.0001', 'silarah_calls_60'));
  PERFORM pg_temp.ok('pack credits minutes', (r->>'applied')::boolean AND (r->>'minutes')::int = 60, r::text);
  r := pg_temp.svc(format('SELECT public.call_service_credit_pack(%L, %L, %L, %L)',
    m1, 'evt-1b', 'GPA.0001', 'silarah_calls_60'));
  PERFORM pg_temp.ok('same purchase twice counted once', r->>'reason' = 'duplicate', r::text);
  r := pg_temp.svc(format('SELECT public.call_service_credit_pack(%L, %L, %L, %L)',
    m1, 'evt-1', 'GPA.0002', 'silarah_calls_60'));
  PERFORM pg_temp.ok('same RevenueCat event twice counted once', r->>'reason' = 'duplicate', r::text);
  r := pg_temp.svc(format('SELECT public.call_service_credit_pack(%L, %L, %L, %L)',
    m1, 'evt-x', 'GPA.0003', 'silarah_monthly'));
  PERFORM pg_temp.ok('non-pack product never credits minutes', r->>'reason' = 'unknown_product', r::text);
  r := pg_temp.svc(format('SELECT public.call_service_extend(%L, %L)', m1, rid));
  PERFORM pg_temp.ok('extend after top-up adds a new hold (max 60)',
    r->>'outcome' = 'extended' AND (r->>'added_minutes')::int = 60
    AND (r->>'max_duration_seconds')::int = 90 * 60 + 30, r::text);

  -- ---- Webhooks --------------------------------------------------------------
  r := pg_temp.svc(format('SELECT public.call_service_record_stream_event(%L,%L,%L,%L,%L,%L,%L,%L)',
    'wh-1', 'call.session_participant_joined', replace(rid::text,'-',''), 'sess-1', m1, 'us-1', now(), NULL));
  r2 := pg_temp.svc(format('SELECT public.call_service_record_stream_event(%L,%L,%L,%L,%L,%L,%L,%L)',
    'wh-1', 'call.session_participant_joined', replace(rid::text,'-',''), 'sess-1', m1, 'us-1', now(), NULL));
  PERFORM pg_temp.ok('duplicate webhook delivery counted once',
    (r->>'duplicate')::boolean = false AND (r2->>'duplicate')::boolean = true, r2::text);
  PERFORM pg_temp.svc(format('SELECT public.call_service_record_stream_event(%L,%L,%L,%L,%L,%L,%L,%L)',
    'wh-2', 'call.session_participant_joined', replace(rid::text,'-',''), 'sess-1', w1, 'us-2', now(), NULL));
  PERFORM pg_temp.ok('both joined recorded',
    (SELECT both_joined_at IS NOT NULL FROM private.call_sessions WHERE request_id = rid), NULL);
  r := pg_temp.svc(format('SELECT public.call_service_record_stream_event(%L,%L,%L,%L,%L,%L,%L,%L)',
    'wh-3', 'call.session_participant_left', replace(rid::text,'-',''), 'sess-1', w1, 'us-2', now(), 125));
  PERFORM pg_temp.ok('a member leaving asks the worker to end the call', r->>'action' = 'check_left', r::text);

  -- ---- End and settle --------------------------------------------------------
  r := pg_temp.svc(format('SELECT public.call_service_end(%L, %L, %L)', w1, rid, 'hangup'));
  PERFORM pg_temp.ok('hang up marks ending', r->>'outcome' = 'ending', r::text);
  PERFORM pg_temp.ok('end queues Stream mark_ended',
    EXISTS (SELECT 1 FROM private.call_jobs WHERE kind = 'end_stream_call' AND request_id = rid), NULL);
  r := pg_temp.svc(format('SELECT public.call_service_settle(%L, 125, %L)', rid, 'test'));
  PERFORM pg_temp.ok('no settlement before Stream confirms the end', r->>'outcome' = 'not_ended', r::text);
  PERFORM pg_temp.svc(format('SELECT jsonb_build_object(''done'', true) FROM (SELECT public.call_service_stream_end_confirmed(%L)) x', rid));
  r := pg_temp.svc(format('SELECT public.call_service_settle(%L, 125, %L)', rid, 'test'));
  PERFORM pg_temp.ok('125 s connected = 3 started minutes',
    (r->>'charged_minutes')::int = 3 AND (r->>'charged_included_minutes')::int = 3
    AND (r->>'charged_pack_minutes')::int = 0, r::text);
  r2 := pg_temp.svc(format('SELECT public.call_service_settle(%L, 9999, %L)', rid, 'test'));
  PERFORM pg_temp.ok('settles once', r2->>'outcome' = 'already_settled', r2::text);
  SELECT * INTO w FROM private.call_wallet_state(m1);
  PERFORM pg_temp.ok('unused hold returned (27 included + 60 pack)',
    w.included_remaining = 27 AND w.pack_minutes = 60 AND w.available_minutes = 87, w::text);
  PERFORM pg_temp.ok('monthly usage counts the charge',
    (SELECT charged_minutes FROM private.call_usage_months WHERE month_start = private.call_month_start()) = 3, NULL);

  -- Charge is capped at the hold.
  PERFORM pg_temp.reset_calls();
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  rid := (r->>'request_id')::uuid;
  r := pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w1, rid));
  PERFORM pg_temp.svc(format('SELECT to_jsonb(public.call_service_session_started(%L))', rid));
  PERFORM pg_temp.svc(format('SELECT public.call_service_end(%L, %L, %L)', m1, rid, 'hangup'));
  PERFORM pg_temp.svc(format('SELECT jsonb_build_object(''done'', true) FROM (SELECT public.call_service_stream_end_confirmed(%L)) x', rid));
  r := pg_temp.svc(format('SELECT public.call_service_settle(%L, 100000, %L)', rid, 'test'));
  PERFORM pg_temp.ok('charge capped at the hold', (r->>'charged_minutes')::int = 30, r::text);
  SELECT * INTO w FROM private.call_wallet_state(m1);
  PERFORM pg_temp.ok('included minutes used before packs; none left', w.included_remaining = 0
    AND w.available_minutes = 0, w::text);
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('no minutes: call refused before ringing', r->>'outcome' = 'no_minutes', r::text);

  -- Zero talk time costs nothing.
  PERFORM pg_temp.reset_calls();
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  rid := (r->>'request_id')::uuid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w1, rid));
  PERFORM pg_temp.svc(format('SELECT to_jsonb(public.call_service_session_started(%L))', rid));
  PERFORM pg_temp.svc(format('SELECT public.call_service_end(%L, %L, %L)', m1, rid, 'hangup'));
  PERFORM pg_temp.svc(format('SELECT jsonb_build_object(''done'', true) FROM (SELECT public.call_service_stream_end_confirmed(%L)) x', rid));
  r := pg_temp.svc(format('SELECT public.call_service_settle(%L, 0, %L)', rid, 'test'));
  SELECT * INTO w FROM private.call_wallet_state(m1);
  PERFORM pg_temp.ok('unconnected call charges 0 and returns all', (r->>'charged_minutes')::int = 0
    AND w.included_remaining = 30, r::text || w::text);

  -- Stream create failure returns everything.
  PERFORM pg_temp.reset_calls();
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  rid := (r->>'request_id')::uuid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w1, rid));
  PERFORM pg_temp.svc(format('SELECT jsonb_build_object(''done'', true) FROM (SELECT public.call_service_session_failed(%L, %L)) x', rid, 'boom'));
  SELECT * INTO w FROM private.call_wallet_state(m1);
  PERFORM pg_temp.ok('failed Stream create releases the hold', w.included_remaining = 30
    AND (SELECT status FROM private.call_sessions WHERE request_id = rid) = 'failed', w::text);

  -- ---- Refunds (spec 6) ------------------------------------------------------
  PERFORM pg_temp.reset_calls();
  PERFORM pg_temp.svc(format('SELECT public.call_service_credit_pack(%L,%L,%L,%L)', m1, 'e1', 'GPA.1', 'silarah_calls_20'));
  r := pg_temp.svc(format('SELECT public.call_service_refund_pack(%L,%L,%L,%L)', m1, 'e2', 'GPA.1', 'silarah_calls_20'));
  r2 := pg_temp.svc(format('SELECT public.call_service_refund_pack(%L,%L,%L,%L)', m1, 'e3', 'GPA.1', 'silarah_calls_20'));
  SELECT * INTO w FROM private.call_wallet_state(m1);
  PERFORM pg_temp.ok('refund removes the minutes once', (r->>'applied')::boolean
    AND r2->>'reason' = 'duplicate' AND w.pack_minutes = 0, r2::text || w::text);
  PERFORM pg_temp.svc(format('SELECT public.call_service_credit_pack(%L,%L,%L,%L)', m1, 'e4', 'GPA.2', 'silarah_calls_20'));
  -- Use 25 of 30+20, then refund the 20-minute pack: balance goes negative.
  UPDATE private.call_wallets SET pack_minutes = 5 WHERE user_id = m1;
  PERFORM pg_temp.svc(format('SELECT public.call_service_refund_pack(%L,%L,%L,%L)', m1, 'e5', 'GPA.2', 'silarah_calls_20'));
  SELECT * INTO w FROM private.call_wallet_state(m1);
  PERFORM pg_temp.ok('refund after use goes negative', w.pack_minutes = -15, w::text);
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('negative balance blocks calling', r->>'outcome' = 'balance_negative', r::text);
  r := pg_temp.usr(m1, 'SELECT public.get_my_call_wallet()');
  PERFORM pg_temp.ok('after 2 refunds packs cannot be bought', (r->>'can_buy_packs')::boolean = false, r::text);
  r := pg_temp.usr(m3, 'SELECT public.get_my_call_wallet()');
  PERFORM pg_temp.ok('premium member can buy packs; 30 included', (r->>'can_buy_packs')::boolean
    AND (r->>'included_minutes')::int = 30 AND jsonb_array_length(r->'packs') = 4, r::text);
  r := pg_temp.usr(w1, 'SELECT public.get_my_call_wallet()');
  PERFORM pg_temp.ok('free member: no included minutes, no packs', (r->>'can_buy_packs')::boolean = false
    AND (r->>'included_minutes')::int = 0, r::text);
  r := pg_temp.svc(format('SELECT public.call_service_forfeit_included(%L, %L)', m3, 'rf-1'));
  SELECT * INTO w FROM private.call_wallet_state(m3);
  PERFORM pg_temp.ok('Premium refund removes the period''s included minutes',
    (r->>'applied')::boolean AND w.included_remaining = 0, r::text);

  -- ---- Member controls (spec 8) --------------------------------------------
  PERFORM pg_temp.reset_calls();
  PERFORM pg_temp.usr(w1, 'SELECT to_jsonb(public.set_my_call_mode(''off''))');
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('Calls off: not rung, neutral answer, missed note',
    r->>'outcome' = 'unavailable'
    AND (SELECT reason FROM private.call_requests WHERE id = (r->>'request_id')::uuid) = 'calls_off', r::text);
  PERFORM pg_temp.usr(w1, 'SELECT to_jsonb(public.set_my_call_mode(''silent''))');
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('Silent: not rung, shows missed', r->>'outcome' = 'unavailable'
    AND (SELECT reason FROM private.call_requests WHERE id = (r->>'request_id')::uuid) = 'silent', r::text);
  PERFORM pg_temp.usr(w1, 'SELECT to_jsonb(public.set_my_call_mode(''ring''))');
  UPDATE public.notification_prefs SET quiet_start = time '00:00', quiet_end = time '23:59:59'
  WHERE user_id = w1;
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('quiet hours: not rung', r->>'outcome' = 'unavailable'
    AND (SELECT reason FROM private.call_requests WHERE id = (r->>'request_id')::uuid) = 'quiet_hours', r::text);
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('3 unanswered calls in 24 h: blocked until tomorrow',
    r->>'outcome' = 'limit_reached' AND (r->>'retry_after')::timestamptz > now(), r::text);
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w2));
  PERFORM pg_temp.ok('limit is per person', r->>'outcome' = 'ringing', r::text);
  PERFORM pg_temp.svc(format('SELECT public.call_service_end(%L, %L, %L)', m1, (r->>'request_id')::uuid, 'cancelled'));
  UPDATE public.notification_prefs SET quiet_start = time '00:00', quiet_end = time '00:00' WHERE user_id = w1;

  PERFORM pg_temp.reset_calls();
  r := pg_temp.usr(w1, format('SELECT public.set_chat_call_prefs(%L, true, false)', k_m1w1));
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('muted chat: not rung', (SELECT reason FROM private.call_requests
    WHERE id = (r->>'request_id')::uuid) = 'muted', r::text);
  r := pg_temp.usr(w1, format('SELECT public.set_chat_call_prefs(%L, false, true)', k_m1w1));
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('calls blocked from this person: not rung, no note',
    r->>'outcome' = 'unavailable'
    AND NOT EXISTS (SELECT 1 FROM private.call_jobs WHERE kind = 'missed_push'
                    AND request_id = (r->>'request_id')::uuid), r::text);
  r := pg_temp.usr(w1, format('SELECT public.get_chat_call_state(%L)', k_m1w1));
  PERFORM pg_temp.ok('blocked calls hidden from the blocker''s chat',
    jsonb_array_length(r->'events') = 1 AND r->'events'->0->>'outcome' = 'missed', r::text);
  r := pg_temp.usr(m1, format('SELECT public.get_chat_call_state(%L)', k_m1w1));
  PERFORM pg_temp.ok('caller only sees "not answered"',
    (SELECT bool_and(e->>'outcome' = 'not_answered') FROM jsonb_array_elements(r->'events') e), r::text);
  r := pg_temp.usr(w1, format('SELECT public.get_chat_call_state(%L)', k_m1w1));
  PERFORM pg_temp.ok('free woman: call button leads to paywall',
    (r->>'can_call')::boolean = false AND r->>'reason' = 'premium_required'
    AND (r->>'i_am_female')::boolean, r::text);
  PERFORM pg_temp.usr(w1, format('SELECT public.set_chat_call_prefs(%L, false, false)', k_m1w1));

  -- ---- Decline token, cancel, timeout, glare --------------------------------
  PERFORM pg_temp.reset_calls();
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  rid := (r->>'request_id')::uuid; tok := r->>'decline_token';
  r2 := pg_temp.svc(format('SELECT public.call_service_decline_with_token(%L, %L)', rid, repeat('0', 48)));
  PERFORM pg_temp.ok('wrong decline token refused', r2->>'outcome' = 'not_found', r2::text);
  r2 := pg_temp.svc(format('SELECT public.call_service_decline_with_token(%L, %L)', rid, tok));
  PERFORM pg_temp.ok('decline from notification works', r2->>'outcome' = 'declined'
    AND EXISTS (SELECT 1 FROM private.call_jobs WHERE kind = 'cancel_ring' AND request_id = rid), r2::text);
  r2 := pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w1, rid));
  PERFORM pg_temp.ok('declined call cannot be answered later', r2->>'outcome' = 'declined', r2::text);

  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  rid := (r->>'request_id')::uuid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_end(%L, %L, %L)', m1, rid, 'cancelled'));
  r2 := pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w1, rid));
  PERFORM pg_temp.ok('cancelled call: later Answer refused', r2->>'outcome' = 'cancelled', r2::text);

  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  rid := (r->>'request_id')::uuid;
  UPDATE private.call_requests SET ring_expires_at = now() - interval '1 second' WHERE id = rid;
  r2 := pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w1, rid));
  PERFORM pg_temp.ok('timeout = missed; late Answer refused', r2->>'outcome' = 'missed'
    AND (SELECT status FROM private.call_requests WHERE id = rid) = 'missed', r2::text);

  PERFORM pg_temp.reset_calls();
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', w2, k_m1w2));
  rid := (r->>'request_id')::uuid;
  r2 := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w2));
  PERFORM pg_temp.ok('glare merges into the existing call', r2->>'outcome' = 'glare'
    AND (r2->>'request_id')::uuid = rid, r2::text);

  -- ---- Safety: server ends the call ------------------------------------------
  -- helper: start a live call m1 -> w1
  PERFORM pg_temp.reset_calls();
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  rid := (r->>'request_id')::uuid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w1, rid));
  PERFORM pg_temp.svc(format('SELECT to_jsonb(public.call_service_session_started(%L))', rid));
  INSERT INTO public.blocks(blocker_id, blocked_id) VALUES (w1, m1);
  PERFORM pg_temp.ok('block ends a live call', (SELECT status = 'ending' AND end_reason = 'blocked'
    FROM private.call_sessions WHERE request_id = rid), NULL);
  DELETE FROM public.blocks WHERE blocker_id = w1 AND blocked_id = m1;
  UPDATE public.matches SET status = 'active', closed_by = NULL, closed_at = NULL, closure_reason = NULL
  WHERE id = k_m1w1;

  PERFORM pg_temp.reset_calls();
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  rid := (r->>'request_id')::uuid;
  INSERT INTO public.blocks(blocker_id, blocked_id) VALUES (m1, w1);
  PERFORM pg_temp.ok('block cancels ringing', (SELECT status = 'cancelled' FROM private.call_requests
    WHERE id = rid) AND EXISTS (SELECT 1 FROM private.call_jobs WHERE kind = 'cancel_ring' AND request_id = rid), NULL);
  DELETE FROM public.blocks WHERE blocker_id = m1 AND blocked_id = w1;
  UPDATE public.matches SET status = 'active', closed_by = NULL, closed_at = NULL, closure_reason = NULL
  WHERE id = k_m1w1;

  FOR v_text IN SELECT unnest(ARRAY['report', 'unmatch', 'ban', 'pause', 'delete', 'premium', 'switch', 'messaging']) LOOP
    PERFORM pg_temp.reset_calls();
    r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
    rid := (r->>'request_id')::uuid;
    PERFORM pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w1, rid));
    PERFORM pg_temp.svc(format('SELECT to_jsonb(public.call_service_session_started(%L))', rid));
    IF v_text = 'report' THEN
      INSERT INTO public.reports(reporter_id, reported_user_id, reason, status) VALUES (w1, m1, 'harassment', 'pending');
    ELSIF v_text = 'unmatch' THEN
      UPDATE public.matches SET status = 'closed', closed_by = w1, closed_at = now() WHERE id = k_m1w1;
    ELSIF v_text = 'ban' THEN
      UPDATE public.users SET is_banned = true WHERE id = m1;
    ELSIF v_text = 'pause' THEN
      UPDATE public.profiles SET visibility = 'paused' WHERE user_id = w1;
    ELSIF v_text = 'delete' THEN
      UPDATE public.users SET deleted_at = now() WHERE id = w1;
    ELSIF v_text = 'premium' THEN
      UPDATE public.users SET subscription_status = 'none', subscription_expires_at = NULL WHERE id = m1;
    ELSIF v_text = 'switch' THEN
      UPDATE private.call_settings SET calls_enabled = false;
    ELSIF v_text = 'messaging' THEN
      UPDATE public.users SET messaging_suspended_until = now() + interval '1 day' WHERE id = m1;
    END IF;
    PERFORM pg_temp.ok(v_text || ' ends a live call',
      (SELECT status = 'ending' FROM private.call_sessions WHERE request_id = rid)
      AND EXISTS (SELECT 1 FROM private.call_jobs WHERE kind = 'end_stream_call' AND request_id = rid),
      (SELECT end_reason FROM private.call_sessions WHERE request_id = rid));
    IF v_text = 'delete' THEN
      PERFORM pg_temp.ok('deletion queues Stream user removal',
        EXISTS (SELECT 1 FROM private.call_jobs WHERE kind = 'delete_stream_user' AND user_id = w1), NULL);
    END IF;
    -- restore
    DELETE FROM public.reports WHERE reporter_id = w1 AND reported_user_id = m1;
    UPDATE public.matches SET status = 'active', closed_by = NULL, closed_at = NULL, closure_reason = NULL WHERE id = k_m1w1;
    UPDATE public.users SET is_banned = false, deleted_at = NULL, messaging_suspended_until = NULL,
      subscription_status = 'active', subscription_expires_at = now() + interval '30 days' WHERE id = m1;
    UPDATE public.users SET deleted_at = NULL WHERE id = w1;
    UPDATE public.profiles SET visibility = 'visible' WHERE user_id = w1;
    PERFORM pg_temp.phone(m1);
    PERFORM pg_temp.phone(w1);
  END LOOP;

  -- Premium lost by the callee man (Premium woman calling him) ends the call;
  -- a free woman callee is fine.
  PERFORM pg_temp.reset_calls();
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', w2, k_m1w2));
  rid := (r->>'request_id')::uuid;
  r := pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', m1, rid));
  PERFORM pg_temp.svc(format('SELECT to_jsonb(public.call_service_session_started(%L))', rid));
  UPDATE public.users SET subscription_status = 'none', subscription_expires_at = NULL WHERE id = m1;
  PERFORM pg_temp.ok('male callee losing Premium ends the call',
    (SELECT end_reason FROM private.call_sessions WHERE request_id = rid) = 'premium_lost', NULL);
  UPDATE public.users SET subscription_status = 'active', subscription_expires_at = now() + interval '30 days' WHERE id = m1;

  -- Join timeout and premium expiry by time are caught by the watchdog scan.
  PERFORM pg_temp.reset_calls();
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  rid := (r->>'request_id')::uuid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w1, rid));
  PERFORM pg_temp.svc(format('SELECT to_jsonb(public.call_service_session_started(%L))', rid));
  UPDATE private.call_sessions SET accepted_at = now() - interval '25 seconds' WHERE request_id = rid;
  PERFORM private.call_enqueue_due_work();
  PERFORM pg_temp.ok('not joined within 20 s: join check queued',
    EXISTS (SELECT 1 FROM private.call_jobs WHERE kind = 'join_check' AND request_id = rid), NULL);
  UPDATE public.users SET subscription_expires_at = now() - interval '1 second' WHERE id = m1;
  PERFORM private.call_enqueue_due_work();
  PERFORM pg_temp.ok('Premium expiring mid-call ends it (watchdog)',
    (SELECT end_reason FROM private.call_sessions WHERE request_id = rid) IN ('premium_lost'),
    (SELECT end_reason FROM private.call_sessions WHERE request_id = rid));
  UPDATE public.users SET subscription_status = 'active', subscription_expires_at = now() + interval '30 days' WHERE id = m1;

  -- Monthly cap.
  PERFORM pg_temp.reset_calls();
  UPDATE private.call_settings SET monthly_cap_minutes = 10;
  INSERT INTO private.call_usage_months(month_start, charged_minutes) VALUES (private.call_month_start(), 10);
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('monthly cap stops new calls', r->>'outcome' = 'capacity', r::text);
  UPDATE private.call_usage_months SET charged_minutes = 5;
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  rid := (r->>'request_id')::uuid;
  r := pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w1, rid));
  PERFORM pg_temp.ok('hold limited by cap room', (r->>'hold_minutes')::int = 5, r::text);

  -- Purge of the callee mid-call returns the caller's minutes.
  PERFORM pg_temp.reset_calls();
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m3, k_m3w2));
  rid := (r->>'request_id')::uuid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w2, rid));
  DELETE FROM public.users WHERE id = w2;
  SELECT * INTO w FROM private.call_wallet_state(m3);
  PERFORM pg_temp.ok('callee purge mid-call returns held minutes', w.included_remaining = 30, w::text);

  -- ---- Privileges -----------------------------------------------------------
  r := pg_temp.usr(m1, format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('members cannot call service RPCs', r->>'error' = '42501', r::text);
  r := pg_temp.usr(m1, format('SELECT public.call_service_credit_pack(%L,%L,%L,%L)', m1, 'x', 'y', 'silarah_calls_350'));
  PERFORM pg_temp.ok('members cannot grant themselves minutes', r->>'error' = '42501', r::text);
  r := pg_temp.usr(m1, 'SELECT to_jsonb(count(*)) FROM private.call_wallets');
  PERFORM pg_temp.ok('members cannot read call tables', r->>'error' = '42501', r::text);
  r := pg_temp.usr(m1, 'SELECT to_jsonb(public.admin_set_calls_enabled(true))');
  PERFORM pg_temp.ok('members cannot flip the switch', r->>'error' = '42501', r::text);
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  r := pg_temp.usr(m1, 'SELECT to_jsonb(private.call_place_hold(gen_random_uuid(), auth.uid()))');
  PERFORM pg_temp.ok('members cannot call private helpers', r ? 'error', r::text);

  -- ---- Export and Guardian --------------------------------------------------
  r := pg_temp.usr(m1, 'SELECT private.build_personal_data_export(''test'')');
  PERFORM pg_temp.ok('export function remains private', r ? 'error', r::text);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', m1, 'role', 'authenticated')::text, true);
  r := private.build_personal_data_export('vc-test');
  PERFORM pg_temp.ok('data export includes call history',
    r ? 'calls' AND jsonb_array_length(r->'calls'->'calls') >= 1, left((r->'calls')::text, 300));
  PERFORM set_config('request.jwt.claims', '', true);
END $$;

SELECT n, ok, name, detail FROM t_results ORDER BY n;
ROLLBACK;
