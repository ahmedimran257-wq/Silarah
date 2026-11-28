-- Rollback test for migration 324 (Calls tab, call notifications, planned
-- calls; docs/voice_calling_spec.md sections 12 and 13). STAGING only:
--   supabase db query --remote=ykmgkrveucslglxvcyss --file <(BEGIN + 324 if not applied + this) --yes
-- One transaction ending in ROLLBACK; the last SELECT prints one row per rule.
BEGIN;

CREATE TEMP TABLE t_results (n serial, name text, ok boolean, detail text) ON COMMIT DROP;

CREATE FUNCTION pg_temp.ok(p_name text, p_ok boolean, p_detail text DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO t_results(name, ok, detail) VALUES (p_name, coalesce(p_ok, false), p_detail);
$$;

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

-- A member's call log as jsonb rows.
CREATE FUNCTION pg_temp.log(p_user uuid, p_args text DEFAULT '') RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
  RETURN pg_temp.usr(p_user, format(
    'SELECT coalesce(jsonb_agg(to_jsonb(l)), ''[]''::jsonb) FROM public.get_my_call_log(%s) l', p_args));
END $$;

CREATE FUNCTION pg_temp.phone(p_id uuid, p_can_ring boolean DEFAULT true) RETURNS void LANGUAGE sql AS $$
  INSERT INTO public.user_fcm_tokens(user_id, device_id, fcm_token, platform)
  VALUES (p_id, 'vcqa-' || replace(p_id::text, '-', ''), 'vcqa-token-' || p_id, 'android')
  ON CONFLICT (user_id, device_id) DO NOTHING;
  INSERT INTO private.call_device_capabilities(user_id, device_id, can_ring)
  VALUES (p_id, 'vcqa-' || replace(p_id::text, '-', ''), p_can_ring)
  ON CONFLICT (user_id, device_id) DO UPDATE SET can_ring = p_can_ring;
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
    country_code, visibility, onboarding_completed, city_id)
  VALUES (p_id, p_first, 'Qatest', date '1995-01-01', p_gender, 'IN', 'visible', true, (SELECT c.id FROM public.cities c JOIN public.regions r ON r.id = c.region_id WHERE upper(r.country_code) = 'IN' ORDER BY c.id LIMIT 1));
  INSERT INTO public.notification_prefs(user_id, quiet_start, quiet_end)
  VALUES (p_id, time '00:00', time '00:00')
  ON CONFLICT (user_id) DO UPDATE SET quiet_start = time '00:00', quiet_end = time '00:00';
  PERFORM pg_temp.phone(p_id);
END $$;

CREATE FUNCTION pg_temp.match(p_a uuid, p_b uuid) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v uuid;
BEGIN
  INSERT INTO public.matches(user_a, user_b, status, guardian_approved)
  VALUES (p_a, p_b, 'active', true) RETURNING id INTO v;
  RETURN v;
END $$;

CREATE FUNCTION pg_temp.reset_calls() RETURNS void LANGUAGE sql AS $$
  DELETE FROM private.call_jobs;
  DELETE FROM private.call_plans;
  DELETE FROM private.call_requests;
  DELETE FROM private.call_ledger;
  DELETE FROM private.call_included_periods;
  DELETE FROM private.call_wallets;
  DELETE FROM private.call_usage_months;
  DELETE FROM private.call_member_prefs;
  DELETE FROM private.call_pair_prefs;
  UPDATE private.call_settings SET calls_enabled = true, monthly_cap_minutes = 100000,
    auto_cap_minutes = NULL, auto_cap_at = NULL;
$$;

-- A call that rang and was not answered (timeout).
CREATE FUNCTION pg_temp.missed(p_caller uuid, p_match uuid) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE r jsonb; v uuid;
BEGIN
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', p_caller, p_match));
  v := (r->>'request_id')::uuid;
  UPDATE private.call_requests SET ring_expires_at = now() - interval '1 second' WHERE id = v;
  PERFORM private.call_expire_ringing(NULL);
  RETURN v;
END $$;

-- A call that connected for p_seconds and was settled at p_minutes.
CREATE FUNCTION pg_temp.talked(p_caller uuid, p_callee uuid, p_match uuid, p_seconds integer,
  p_minutes integer) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE r jsonb; v uuid;
BEGIN
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', p_caller, p_match));
  v := (r->>'request_id')::uuid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', p_callee, v));
  UPDATE private.call_sessions SET status = 'settled', connected_seconds = p_seconds,
    charged_minutes = p_minutes, both_joined_at = accepted_at, ended_at = now(), settled_at = now()
  WHERE request_id = v;
  RETURN v;
END $$;

DO $$
DECLARE
  m1 uuid := '00000000-0000-4000-8000-0000000d0001'; -- man, Premium
  w1 uuid := '00000000-0000-4000-8000-0000000d0002'; -- woman, free
  m2 uuid := '00000000-0000-4000-8000-0000000d0003'; -- man, free
  w2 uuid := '00000000-0000-4000-8000-0000000d0004'; -- woman, Premium
  m3 uuid := '00000000-0000-4000-8000-0000000d0005'; -- man, Premium
  w3 uuid := '00000000-0000-4000-8000-0000000d0006';
  w4 uuid := '00000000-0000-4000-8000-0000000d0007';
  w5 uuid := '00000000-0000-4000-8000-0000000d0008';
  w6 uuid := '00000000-0000-4000-8000-0000000d0009';
  w7 uuid := '00000000-0000-4000-8000-0000000d000a'; -- woman, Premium: block / delete checks
  m4 uuid := '00000000-0000-4000-8000-0000000d000b'; -- man, free: inbox preview
  k_m1w1 uuid; k_w2m2 uuid; k_m1w2 uuid; k_m3w1 uuid; k_m1w3 uuid; k_m1w4 uuid;
  k_m1w5 uuid; k_m1w6 uuid; k_w7m1 uuid; k_w7m4 uuid;
  r jsonb; rid uuid; rid2 uuid; rid3 uuid; rid4 uuid; pid uuid; n integer;
BEGIN
  PERFORM pg_temp.member(m1, 'male', 'Ahmed', true);
  PERFORM pg_temp.member(w1, 'female', 'Aisha', false);
  PERFORM pg_temp.member(m2, 'male', 'Bilal', false);
  PERFORM pg_temp.member(w2, 'female', 'Fatima', true);
  PERFORM pg_temp.member(m3, 'male', 'Kareem', true);
  PERFORM pg_temp.member(w3, 'female', 'Huda', false);
  PERFORM pg_temp.member(w4, 'female', 'Iman', false);
  PERFORM pg_temp.member(w5, 'female', 'Jannah', false);
  PERFORM pg_temp.member(w6, 'female', 'Khadija', false);
  PERFORM pg_temp.member(w7, 'female', 'Layla', true);
  PERFORM pg_temp.member(m4, 'male', 'Musa', false);
  k_m1w1 := pg_temp.match(m1, w1);
  k_w2m2 := pg_temp.match(w2, m2);
  k_m1w2 := pg_temp.match(m1, w2);
  k_m3w1 := pg_temp.match(m3, w1);
  k_m1w3 := pg_temp.match(m1, w3);
  k_m1w4 := pg_temp.match(m1, w4);
  k_m1w5 := pg_temp.match(m1, w5);
  k_m1w6 := pg_temp.match(m1, w6);
  k_w7m1 := pg_temp.match(w7, m1);
  k_w7m4 := pg_temp.match(w7, m4);
  PERFORM pg_temp.reset_calls();

  -- ---- 12.2.4 Ring capability ----------------------------------------------
  PERFORM pg_temp.phone(w1, false);
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('no phone can ring: neutral unavailable for the caller',
    r->>'outcome' = 'unavailable' AND NOT (r ? 'reason'), r::text);
  PERFORM pg_temp.ok('no phone can ring: recorded as no_device',
    (SELECT reason FROM private.call_requests WHERE id = (r->>'request_id')::uuid) = 'no_device', NULL);
  PERFORM pg_temp.ok('no phone can ring: the callee still gets the missed call',
    EXISTS (SELECT 1 FROM private.call_jobs WHERE kind = 'missed_push'
            AND request_id = (r->>'request_id')::uuid), NULL);
  DELETE FROM private.call_device_capabilities WHERE user_id = w1;
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('unknown capability (older app) never rings',
    (SELECT reason FROM private.call_requests WHERE id = (r->>'request_id')::uuid) = 'no_device', r::text);
  r := pg_temp.usr(w1, format('SELECT to_jsonb(public.set_my_call_ring_capability(%L, true))',
    'vcqa-' || replace(w1::text, '-', '')));
  PERFORM pg_temp.ok('member reports their phone can ring', r = 'true'::jsonb, r::text);
  r := pg_temp.usr(w1, 'SELECT to_jsonb(public.set_my_call_ring_capability(''x'', true))');
  PERFORM pg_temp.ok('invalid device id refused', r->>'error' = '22023', r::text);
  r := pg_temp.svc(format(
    'SELECT jsonb_agg(to_jsonb(t)) FROM public.call_service_device_tokens(%L) t', w1));
  PERFORM pg_temp.ok('device list carries can_ring', (r->0->>'can_ring')::boolean, r::text);
  PERFORM pg_temp.reset_calls();
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('a phone that can ring is rung', r->>'outcome' = 'ringing', r::text);
  PERFORM pg_temp.svc(format('SELECT public.call_service_end(%L, %L, %L)', m1, (r->>'request_id')::uuid, 'cancelled'));

  -- ---- 12.3 Missed-call push ------------------------------------------------
  PERFORM pg_temp.reset_calls();
  rid := pg_temp.missed(m1, k_m1w1);
  r := pg_temp.svc(format('SELECT public.call_service_missed_push(%L)', rid));
  PERFORM pg_temp.ok('timeout: missed push for a free woman',
    (r->>'send')::boolean AND r->>'variant' = 'missed' AND r->>'caller_name' = 'Ahmed'
    AND NOT (r->>'silent')::boolean AND (r->>'count')::int = 1, r::text);
  PERFORM pg_temp.ok('timeout queued the missed push job',
    EXISTS (SELECT 1 FROM private.call_jobs WHERE kind = 'missed_push' AND request_id = rid), NULL);
  rid2 := pg_temp.missed(m1, k_m1w1);
  r := pg_temp.svc(format('SELECT public.call_service_missed_push(%L)', rid2));
  PERFORM pg_temp.ok('two missed calls from one person collapse with a count',
    (r->>'count')::int = 2, r::text);
  PERFORM pg_temp.ok('push never carries a surname',
    position('Qatest' IN r::text) = 0 AND position(' Q.' IN r::text) = 0, r::text);

  -- Caller cancels while ringing: the callee missed it.
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m3, k_m3w1));
  rid3 := (r->>'request_id')::uuid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_end(%L, %L, %L)', m3, rid3, 'cancelled'));
  r := pg_temp.svc(format('SELECT public.call_service_missed_push(%L)', rid3));
  PERFORM pg_temp.ok('caller hung up while ringing: missed push',
    (r->>'send')::boolean AND (r->>'count')::int = 1 AND r->>'caller_name' = 'Kareem', r::text);

  -- Free man: Premium variant.
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', w2, k_w2m2));
  r := pg_temp.svc(format('SELECT public.call_service_missed_push(%L)', (r->>'request_id')::uuid));
  PERFORM pg_temp.ok('free man: Premium variant',
    (r->>'send')::boolean AND r->>'variant' = 'premium' AND r->>'caller_name' = 'Fatima', r::text);

  -- Silent, muted, quiet hours: silent notification. Off / toggle: none.
  PERFORM pg_temp.reset_calls();
  PERFORM pg_temp.usr(w1, 'SELECT to_jsonb(public.set_my_call_mode(''silent''))');
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  r := pg_temp.svc(format('SELECT public.call_service_missed_push(%L)', (r->>'request_id')::uuid));
  PERFORM pg_temp.ok('Silent: silent missed-call notification',
    (r->>'send')::boolean AND (r->>'silent')::boolean, r::text);
  PERFORM pg_temp.usr(w1, 'SELECT to_jsonb(public.set_my_call_mode(''off''))');
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  r := pg_temp.svc(format('SELECT public.call_service_missed_push(%L)', (r->>'request_id')::uuid));
  PERFORM pg_temp.ok('Calls off: no push at all', NOT (r->>'send')::boolean, r::text);
  PERFORM pg_temp.usr(w1, 'SELECT to_jsonb(public.set_my_call_mode(''ring''))');
  PERFORM pg_temp.reset_calls();
  PERFORM pg_temp.usr(w1, format('SELECT public.set_chat_call_prefs(%L, true, false)', k_m1w1));
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  r := pg_temp.svc(format('SELECT public.call_service_missed_push(%L)', (r->>'request_id')::uuid));
  PERFORM pg_temp.ok('muted chat: silent notification', (r->>'silent')::boolean, r::text);
  PERFORM pg_temp.usr(w1, format('SELECT public.set_chat_call_prefs(%L, false, true)', k_m1w1));
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  r := pg_temp.svc(format('SELECT public.call_service_missed_push(%L)', (r->>'request_id')::uuid));
  PERFORM pg_temp.ok('calls blocked from this person: never told', NOT (r->>'send')::boolean, r::text);
  PERFORM pg_temp.usr(w1, format('SELECT public.set_chat_call_prefs(%L, false, false)', k_m1w1));
  PERFORM pg_temp.reset_calls();
  UPDATE public.notification_prefs SET quiet_start = time '00:00', quiet_end = time '23:59' WHERE user_id = w1;
  rid := pg_temp.missed(m1, k_m1w1);
  r := pg_temp.svc(format('SELECT public.call_service_missed_push(%L)', rid));
  PERFORM pg_temp.ok('quiet hours: not rung, silent missed-call notification',
    (SELECT reason FROM private.call_requests WHERE id = rid) = 'quiet_hours'
    AND (r->>'silent')::boolean, r::text);
  UPDATE public.notification_prefs SET quiet_start = time '00:00', quiet_end = time '00:00',
    missed_call = false WHERE user_id = w1;
  r := pg_temp.svc(format('SELECT public.call_service_missed_push(%L)', rid));
  PERFORM pg_temp.ok('missed_call toggle off: no push', NOT (r->>'send')::boolean, r::text);
  UPDATE public.notification_prefs SET missed_call = true WHERE user_id = w1;

  -- ---- 12.5 Call log ----------------------------------------------------------
  PERFORM pg_temp.reset_calls();
  rid := pg_temp.missed(m1, k_m1w1);
  rid2 := pg_temp.talked(m1, w1, k_m1w1, 125, 3);
  rid3 := pg_temp.talked(w2, m1, k_m1w2, 61, 2);
  -- now() is fixed inside a transaction: give the calls distinct times.
  UPDATE private.call_requests SET created_at = now() - interval '3 minutes' WHERE id = rid;
  UPDATE private.call_requests SET created_at = now() - interval '2 minutes' WHERE id = rid2;
  UPDATE private.call_requests SET created_at = now() - interval '1 minute' WHERE id = rid3;
  r := pg_temp.log(m1);
  PERFORM pg_temp.ok('log: newest first, both directions',
    jsonb_array_length(r) = 3 AND (r->0->>'request_id')::uuid = rid3
    AND r->0->>'direction' = 'incoming' AND r->2->>'direction' = 'outgoing', r::text);
  PERFORM pg_temp.ok('caller sees "No answer", never why',
    r->2->>'outcome' = 'no_answer', (r->2)::text);
  PERFORM pg_temp.ok('talk time and minutes used for the caller',
    r->1->>'outcome' = 'answered' AND (r->1->>'talk_seconds')::int = 125
    AND (r->1->>'minutes_used')::int = 3, (r->1)::text);
  PERFORM pg_temp.ok('the callee never sees minutes used',
    r->0->>'minutes_used' IS NULL AND (r->0->>'talk_seconds')::int = 61, (r->0)::text);
  PERFORM pg_temp.ok('active match shows the full surname',
    r->1->>'other_first_name' = 'Aisha' AND r->1->>'other_last_name' = 'Qatest', (r->1)::text);
  r := pg_temp.log(w1);
  PERFORM pg_temp.ok('callee sees the missed call, unseen',
    r->1->>'outcome' = 'missed' AND (r->1->>'unseen')::boolean, r::text);
  r := pg_temp.log(w1, '''missed''');
  PERFORM pg_temp.ok('filter missed', jsonb_array_length(r) = 1 AND (r->0->>'request_id')::uuid = rid, r::text);
  r := pg_temp.log(m1, '''outgoing''');
  PERFORM pg_temp.ok('filter outgoing', jsonb_array_length(r) = 2, r::text);
  r := pg_temp.log(m1, '''incoming''');
  PERFORM pg_temp.ok('filter incoming', jsonb_array_length(r) = 1, r::text);
  r := pg_temp.log(m1, '''nonsense''');
  PERFORM pg_temp.ok('unknown filter refused', r->>'error' = '22023', r::text);
  r := pg_temp.log(m1, 'p_limit => 1');
  r := pg_temp.log(m1, format('p_before => %L, p_before_id => %L, p_limit => 1',
    r->0->>'created_at', r->0->>'request_id'));
  PERFORM pg_temp.ok('cursor pagination continues after the last row',
    jsonb_array_length(r) = 1 AND (r->0->>'request_id')::uuid = rid2, r::text);
  r := pg_temp.log(m1, 'p_before => now()');
  PERFORM pg_temp.ok('half a cursor refused', r->>'error' = '22023', r::text);
  r := pg_temp.log(m1, 'p_query => ''fati''');
  PERFORM pg_temp.ok('search by first name', jsonb_array_length(r) = 1
    AND r->0->>'other_first_name' = 'Fatima', r::text);
  r := pg_temp.log(m1, 'p_query => ''%''');
  PERFORM pg_temp.ok('search treats % literally', jsonb_array_length(r) = 0, r::text);
  r := pg_temp.log(m1, format('p_other_user_id => %L', w2));
  PERFORM pg_temp.ok('one member''s calls only (details sheet)',
    jsonb_array_length(r) = 1 AND r->0->>'other_first_name' = 'Fatima', r::text);
  r := pg_temp.log(m1, 'p_query => ''Qatest''');
  PERFORM pg_temp.ok('search never matches hidden surnames', jsonb_array_length(r) = 0, r::text);

  -- Closed match: surname initial only. Blocked: member unavailable.
  UPDATE public.matches SET status = 'closed', closed_by = w2, closed_at = now() WHERE id = k_m1w2;
  r := pg_temp.log(m1);
  PERFORM pg_temp.ok('ended match: surname initial only', r->0->>'other_last_name' = 'Q', (r->0)::text);
  UPDATE public.matches SET status = 'active', closed_by = NULL, closed_at = NULL, closure_reason = NULL WHERE id = k_m1w2;
  PERFORM pg_temp.ok('an available member is not marked unavailable',
    r->0->>'member_unavailable' = 'false', (r->0)::text);
  rid4 := pg_temp.talked(w7, m1, k_w7m1, 30, 1);
  INSERT INTO public.blocks(blocker_id, blocked_id) VALUES (w7, m1);
  r := pg_temp.log(m1);
  PERFORM pg_temp.ok('blocked: "Member unavailable", no id, no name',
    (r->0->>'member_unavailable')::boolean AND r->0->>'other_user_id' IS NULL
    AND r->0->>'other_first_name' = 'Silarah member' AND r->0->>'other_last_name' = '', (r->0)::text);
  DELETE FROM public.blocks WHERE blocker_id = w7 AND blocked_id = m1;
  UPDATE public.users SET deleted_at = now() WHERE id = w7;
  r := pg_temp.log(m1);
  PERFORM pg_temp.ok('deleted account: member unavailable', (r->0->>'member_unavailable')::boolean, (r->0)::text);
  UPDATE private.call_requests SET hidden_by_caller_at = now(), hidden_by_callee_at = now() WHERE id = rid4;

  -- Remove from history.
  r := pg_temp.usr(w1, format('SELECT to_jsonb(public.hide_my_calls(ARRAY[%L, %L]::uuid[]))', rid, rid3));
  PERFORM pg_temp.ok('hide: only the member''s own calls', r = '1'::jsonb, r::text);
  PERFORM pg_temp.ok('hidden for the member', jsonb_array_length(pg_temp.log(w1, '''missed''')) = 0, NULL);
  PERFORM pg_temp.ok('the other member still sees it', jsonb_array_length(pg_temp.log(m1)) = 3, NULL);
  PERFORM pg_temp.ok('hidden calls still count for the harassment limit',
    (SELECT count(*) FROM private.call_requests WHERE id = rid AND hidden_by_callee_at IS NOT NULL) = 1
    AND (SELECT count(*) FROM private.call_requests WHERE caller_id = m1 AND callee_id = w1
         AND status IN ('declined', 'cancelled', 'missed', 'unavailable')) = 1, NULL);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', w1, 'role', 'authenticated')::text, true);
  r := private.call_history_export(w1);
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM pg_temp.ok('export keeps hidden calls, marked removed',
    EXISTS (SELECT 1 FROM jsonb_array_elements(r->'calls') c
            WHERE c->>'removed_from_history_at' IS NOT NULL), left(r::text, 300));
  PERFORM pg_temp.ok('hiding never deletes',
    (SELECT count(*) FROM private.call_requests WHERE match_id = k_m1w1) = 2, NULL);

  -- ---- 12.5 Badge ---------------------------------------------------------------
  PERFORM pg_temp.reset_calls();
  rid := pg_temp.missed(m1, k_m1w1);
  rid2 := pg_temp.missed(m3, k_m3w1);
  r := pg_temp.usr(w1, 'SELECT public.get_my_call_overview()');
  PERFORM pg_temp.ok('overview: unseen missed count', (r->>'unseen_missed')::int = 2, r::text);
  DELETE FROM private.call_jobs WHERE kind = 'seen_push';
  r := pg_temp.usr(w1, 'SELECT to_jsonb(public.mark_calls_seen())');
  PERFORM pg_temp.ok('mark seen returns how many were unseen', r = '2'::jsonb, r::text);
  PERFORM pg_temp.ok('seen on one phone clears the others',
    EXISTS (SELECT 1 FROM private.call_jobs WHERE kind = 'seen_push' AND user_id = w1), NULL);
  r := pg_temp.usr(w1, 'SELECT public.get_my_call_overview()');
  PERFORM pg_temp.ok('badge cleared', (r->>'unseen_missed')::int = 0, r::text);
  r := pg_temp.svc(format('SELECT public.call_service_missed_push(%L)', rid));
  PERFORM pg_temp.ok('a missed call already seen sends no push', NOT (r->>'send')::boolean, r::text);
  DELETE FROM private.call_jobs WHERE kind = 'seen_push';
  r := pg_temp.usr(w1, 'SELECT to_jsonb(public.mark_calls_seen())');
  PERFORM pg_temp.ok('nothing unseen: no push to other phones',
    NOT EXISTS (SELECT 1 FROM private.call_jobs WHERE kind = 'seen_push'), r::text);

  -- Monthly insight and minutes.
  PERFORM pg_temp.reset_calls();
  PERFORM pg_temp.talked(m1, w1, k_m1w1, 300, 5);
  PERFORM pg_temp.talked(m3, w1, k_m3w1, 45, 1);
  r := pg_temp.usr(w1, 'SELECT public.get_my_call_overview()');
  PERFORM pg_temp.ok('monthly talk time counts both directions',
    (r->>'month_talk_seconds')::int = 345 AND NOT (r->>'premium')::boolean
    AND (r->>'female')::boolean, r::text);
  r := pg_temp.usr(m1, 'SELECT public.get_my_call_overview()');
  PERFORM pg_temp.ok('overview has included minutes, renewal and packs',
    (r->>'premium')::boolean AND r ? 'included_minutes' AND r ? 'included_period_end'
    AND r ? 'pack_minutes' AND r ? 'can_buy_packs', r::text);

  -- Chat inbox preview (spec 12.3).
  PERFORM pg_temp.reset_calls();
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', w2, k_w2m2));
  PERFORM pg_temp.ok('inbox fixture: call recorded', r->>'outcome' = 'unavailable', r::text);
  r := pg_temp.usr(m2, 'SELECT jsonb_agg(to_jsonb(i)) FROM public.get_chat_inbox(50, NULL) i');
  PERFORM pg_temp.ok('locked chat preview shows the missed call (free man)',
    EXISTS (SELECT 1 FROM jsonb_array_elements(r) i WHERE (i->>'match_id')::uuid = k_w2m2
            AND i->>'last_call_outcome' = 'missed' AND (i->>'content_locked')::boolean
            AND i->>'last_message_content' IS NULL), r::text);
  r := pg_temp.usr(w2, 'SELECT jsonb_agg(to_jsonb(i)) FROM public.get_chat_inbox(50, NULL) i');
  PERFORM pg_temp.ok('caller''s preview: no answer',
    EXISTS (SELECT 1 FROM jsonb_array_elements(r) i WHERE (i->>'match_id')::uuid = k_w2m2
            AND i->>'last_call_outcome' = 'no_answer'), r::text);

  -- ---- 13 Planned calls -----------------------------------------------------
  PERFORM pg_temp.reset_calls();
  r := pg_temp.usr(m2, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_w2m2));
  PERFORM pg_temp.ok('free man cannot propose (paywall)', r->>'outcome' = 'premium_required', r::text);
  r := pg_temp.usr(w1, format('SELECT public.propose_call_plan(%L, now() + interval ''5 minutes'')', k_m1w1));
  PERFORM pg_temp.ok('too soon refused', r->>'outcome' = 'invalid_time', r::text);
  r := pg_temp.usr(w1, format('SELECT public.propose_call_plan(%L, now() + interval ''8 days'')', k_m1w1));
  PERFORM pg_temp.ok('more than 7 days ahead refused', r->>'outcome' = 'invalid_time', r::text);
  r := pg_temp.usr(w1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_m1w1));
  pid := (r->>'plan_id')::uuid;
  PERFORM pg_temp.ok('free woman proposes a time', r->>'outcome' = 'proposed', r::text);
  PERFORM pg_temp.ok('the other member is told, first name only, opens Calls',
    EXISTS (SELECT 1 FROM public.notifications WHERE user_id = m1 AND type = 'call_plan'
            AND body = 'Aisha suggested a time to talk.' AND deep_link = 'silarah://calls'), NULL);
  r := pg_temp.usr(m1, format('SELECT public.propose_call_plan(%L, now() + interval ''2 hours'')', k_m1w1));
  PERFORM pg_temp.ok('one open plan per chat', r->>'outcome' = 'already_planned'
    AND (r->>'plan_id')::uuid = pid, r::text);
  r := pg_temp.usr(m3, format('SELECT public.respond_call_plan(%L, true)', pid));
  PERFORM pg_temp.ok('only the invitee answers', r->>'outcome' = 'not_found', r::text);
  r := pg_temp.usr(w1, format('SELECT public.respond_call_plan(%L, true)', pid));
  PERFORM pg_temp.ok('the proposer cannot accept their own plan', r->>'outcome' = 'not_found', r::text);
  r := pg_temp.usr(m1, 'SELECT public.get_my_call_overview()');
  PERFORM pg_temp.ok('invitee sees Accept / Decline',
    r->'plans'->0->>'action' = 'respond' AND NOT (r->'plans'->0->>'i_proposed')::boolean, r::text);
  r := pg_temp.usr(m1, format('SELECT public.respond_call_plan(%L, true)', pid));
  PERFORM pg_temp.ok('invitee accepts', r->>'outcome' = 'accepted', r::text);
  PERFORM pg_temp.ok('proposer told it was accepted',
    EXISTS (SELECT 1 FROM public.notifications WHERE user_id = w1 AND type = 'call_plan'
            AND body = 'Ahmed accepted your call time.'), NULL);
  r := pg_temp.usr(m1, 'SELECT public.get_my_call_overview()');
  PERFORM pg_temp.ok('before the time: waiting', r->'plans'->0->>'action' = 'wait_for_time', r::text);
  UPDATE private.call_plans SET planned_for = now() + interval '4 minutes' WHERE id = pid;
  r := pg_temp.usr(m1, 'SELECT public.get_my_call_overview()');
  PERFORM pg_temp.ok('5 minutes before: Premium man can call now', r->'plans'->0->>'action' = 'call', r::text);
  r := pg_temp.usr(w1, 'SELECT public.get_my_call_overview()');
  PERFORM pg_temp.ok('free woman waits for his call', r->'plans'->0->>'action' = 'wait_for_call', r::text);

  -- Reminder, once.
  PERFORM private.call_enqueue_due_work();
  PERFORM private.call_enqueue_due_work();
  PERFORM pg_temp.ok('reminder queued once, 5 minutes before',
    (SELECT count(*) FROM private.call_jobs WHERE kind = 'plan_reminder' AND plan_id = pid) = 1
    AND (SELECT reminder_sent_at IS NOT NULL FROM private.call_plans WHERE id = pid), NULL);
  r := pg_temp.svc(format('SELECT public.call_service_plan_reminder(%L)', pid));
  PERFORM pg_temp.ok('reminder goes to both, with the other''s first name',
    jsonb_array_length(r->'to') = 2 AND r::text LIKE '%"other_name": "Aisha"%'
    AND r::text LIKE '%"other_name": "Ahmed"%', r::text);
  PERFORM pg_temp.usr(w1, 'SELECT to_jsonb(public.set_my_call_mode(''off''))');
  r := pg_temp.svc(format('SELECT public.call_service_plan_reminder(%L)', pid));
  PERFORM pg_temp.ok('no reminder to a member with Calls off', jsonb_array_length(r->'to') = 1, r::text);
  PERFORM pg_temp.usr(w1, 'SELECT to_jsonb(public.set_my_call_mode(''ring''))');

  -- Done when they talked around the time; expired otherwise.
  PERFORM pg_temp.talked(m1, w1, k_m1w1, 200, 4);
  UPDATE private.call_plans SET planned_for = now() - interval '31 minutes' WHERE id = pid;
  UPDATE private.call_requests SET created_at = now() - interval '30 minutes' WHERE match_id = k_m1w1;
  PERFORM private.call_enqueue_due_work();
  PERFORM pg_temp.ok('plan done when they connected in the window',
    (SELECT status FROM private.call_plans WHERE id = pid) = 'done', NULL);
  r := pg_temp.usr(m1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_m1w2));
  pid := (r->>'plan_id')::uuid;
  PERFORM pg_temp.usr(w2, format('SELECT public.respond_call_plan(%L, true)', pid));
  UPDATE private.call_plans SET planned_for = now() - interval '31 minutes' WHERE id = pid;
  PERFORM private.call_enqueue_due_work();
  PERFORM pg_temp.ok('accepted plan with no call expires',
    (SELECT status FROM private.call_plans WHERE id = pid) = 'expired', NULL);
  r := pg_temp.usr(m1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_m1w2));
  pid := (r->>'plan_id')::uuid;
  UPDATE private.call_plans SET planned_for = now() - interval '1 minute' WHERE id = pid;
  PERFORM private.call_enqueue_due_work();
  PERFORM pg_temp.ok('unanswered proposal expires at its time',
    (SELECT status FROM private.call_plans WHERE id = pid) = 'expired', NULL);

  -- Decline is silent; cancel tells the other side only for an accepted plan.
  PERFORM pg_temp.reset_calls();
  DELETE FROM public.notifications WHERE type = 'call_plan';
  r := pg_temp.usr(m1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_m1w2));
  pid := (r->>'plan_id')::uuid;
  r := pg_temp.usr(w2, format('SELECT public.respond_call_plan(%L, false)', pid));
  PERFORM pg_temp.ok('decline: the proposer gets no push',
    r->>'outcome' = 'declined'
    AND NOT EXISTS (SELECT 1 FROM public.notifications WHERE user_id = m1 AND type = 'call_plan'), r::text);
  r := pg_temp.usr(m1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_m1w2));
  pid := (r->>'plan_id')::uuid;
  PERFORM pg_temp.usr(w2, format('SELECT public.respond_call_plan(%L, true)', pid));
  r := pg_temp.usr(m3, format('SELECT public.cancel_call_plan(%L)', pid));
  PERFORM pg_temp.ok('a stranger cannot cancel', r->>'outcome' = 'not_found', r::text);
  r := pg_temp.usr(w2, format('SELECT public.cancel_call_plan(%L)', pid));
  PERFORM pg_temp.ok('either member cancels; the other is told',
    r->>'outcome' = 'cancelled'
    AND EXISTS (SELECT 1 FROM public.notifications WHERE user_id = m1 AND type = 'call_plan'
                AND body = 'Fatima cancelled the call time.'), r::text);

  -- Neutral refusals and limits.
  PERFORM pg_temp.usr(w3, 'SELECT to_jsonb(public.set_my_call_mode(''off''))');
  r := pg_temp.usr(m1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_m1w3));
  PERFORM pg_temp.ok('invitee has Calls off: neutral unavailable', r->>'outcome' = 'unavailable', r::text);
  PERFORM pg_temp.usr(w3, 'SELECT to_jsonb(public.set_my_call_mode(''ring''))');
  PERFORM pg_temp.usr(w3, format('SELECT public.set_chat_call_prefs(%L, false, true)', k_m1w3));
  r := pg_temp.usr(m1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_m1w3));
  PERFORM pg_temp.ok('invitee blocked calls from me: neutral unavailable', r->>'outcome' = 'unavailable', r::text);
  PERFORM pg_temp.usr(w3, format('SELECT public.set_chat_call_prefs(%L, false, false)', k_m1w3));
  PERFORM pg_temp.reset_calls();
  FOREACH pid IN ARRAY ARRAY[k_m1w1, k_m1w2, k_m1w3, k_m1w4, k_m1w5] LOOP
    PERFORM pg_temp.usr(m1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', pid));
  END LOOP;
  r := pg_temp.usr(m1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_m1w6));
  PERFORM pg_temp.ok('at most 5 open plans per member', r->>'outcome' = 'limit_reached', r::text);
  PERFORM pg_temp.reset_calls();
  FOR n IN 1..3 LOOP
    r := pg_temp.usr(m1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_m1w2));
    PERFORM pg_temp.usr(m1, format('SELECT public.cancel_call_plan(%L)', r->>'plan_id'));
  END LOOP;
  r := pg_temp.usr(m1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_m1w2));
  PERFORM pg_temp.ok('propose-cancel loop stops after 3 in 24 h', r->>'outcome' = 'limit_reached', r::text);
  PERFORM pg_temp.reset_calls();
  FOREACH pid IN ARRAY ARRAY[k_m1w1, k_m1w2, k_m1w3, k_m1w4, k_m1w5] LOOP
    PERFORM pg_temp.usr(m1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', pid));
  END LOOP;
  INSERT INTO public.blocks(blocker_id, blocked_id) VALUES (w1, m1);
  r := pg_temp.usr(m1, 'SELECT public.get_my_call_overview()');
  PERFORM pg_temp.ok('a block hides the plan at once',
    NOT EXISTS (SELECT 1 FROM jsonb_array_elements(r->'plans') p
                WHERE (p->>'match_id')::uuid = k_m1w1), r::text);
  PERFORM private.call_enqueue_due_work();
  PERFORM pg_temp.ok('a block cancels the plan',
    (SELECT status FROM private.call_plans WHERE match_id = k_m1w1) = 'cancelled', NULL);
  DELETE FROM public.blocks WHERE blocker_id = w1 AND blocked_id = m1;
  -- A block closes the match; reopen it for the scenarios below.
  UPDATE public.matches SET status = 'active', closed_by = NULL, closed_at = NULL, closure_reason = NULL
  WHERE id = k_m1w1;
  UPDATE private.call_settings SET calls_enabled = false;
  r := pg_temp.usr(w4, format('SELECT public.propose_call_plan(%L, now() + interval ''2 hours'')', k_m1w4));
  PERFORM pg_temp.ok('switch off: no plans', r->>'outcome' = 'calls_disabled', r::text);
  UPDATE private.call_settings SET calls_enabled = true;

  -- ---- 13.1 Who may plan a call ----------------------------------------------
  PERFORM pg_temp.reset_calls();
  -- m2 (free man) is matched with w2 (Premium woman); add a free woman pair.
  r := pg_temp.usr(w2, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_w2m2));
  PERFORM pg_temp.ok('a free man is never offered a plan (neutral to her)',
    r->>'outcome' = 'unavailable', r::text);
  r := pg_temp.usr(m1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_m1w1));
  pid := (r->>'plan_id')::uuid;
  UPDATE public.users SET subscription_status = 'none', subscription_expires_at = NULL WHERE id = m1;
  r := pg_temp.usr(w1, format('SELECT public.respond_call_plan(%L, true)', pid));
  PERFORM pg_temp.ok('accepting needs the man to hold Premium', r->>'outcome' = 'not_allowed', r::text);
  PERFORM private.call_enqueue_due_work();
  PERFORM pg_temp.ok('Premium ending closes the plan',
    (SELECT status FROM private.call_plans WHERE id = pid) = 'cancelled', NULL);
  UPDATE public.users SET subscription_status = 'active', subscription_expires_at = now() + interval '30 days' WHERE id = m1;
  PERFORM pg_temp.reset_calls();
  PERFORM pg_temp.usr(w1, 'SELECT to_jsonb(public.set_my_call_mode(''off''))');
  r := pg_temp.usr(w1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_m1w1));
  PERFORM pg_temp.ok('own Calls off: told to turn calls on', r->>'outcome' = 'calls_off_self', r::text);
  PERFORM pg_temp.usr(w1, 'SELECT to_jsonb(public.set_my_call_mode(''ring''))');
  r := pg_temp.usr(w1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_m1w1));
  pid := (r->>'plan_id')::uuid;
  PERFORM pg_temp.usr(m1, format('SELECT public.respond_call_plan(%L, true)', pid));
  UPDATE public.notification_prefs SET quiet_start = time '00:00', quiet_end = time '23:59' WHERE user_id = w1;
  r := pg_temp.svc(format('SELECT public.call_service_plan_reminder(%L)', pid));
  PERFORM pg_temp.ok('reminder in quiet hours is silent',
    EXISTS (SELECT 1 FROM jsonb_array_elements(r->'to') t
            WHERE (t->>'user_id')::uuid = w1 AND (t->>'silent')::boolean)
    AND EXISTS (SELECT 1 FROM jsonb_array_elements(r->'to') t
                WHERE (t->>'user_id')::uuid = m1 AND NOT (t->>'silent')::boolean), r::text);
  UPDATE public.notification_prefs SET quiet_start = time '00:00', quiet_end = time '00:00' WHERE user_id = w1;
  UPDATE private.call_settings SET plan_min_lead_minutes = 120;
  r := pg_temp.usr(w2, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_m1w2));
  PERFORM pg_temp.ok('planning windows come from settings', r->>'outcome' = 'invalid_time', r::text);
  UPDATE private.call_settings SET plan_min_lead_minutes = 10;

  -- ---- 12.6 One source of numbers -------------------------------------------
  UPDATE private.call_settings SET unanswered_call_limit = 4, included_minutes = 45;
  r := pg_temp.usr(w1, 'SELECT public.get_calling_rules()');
  PERFORM pg_temp.ok('rules RPC carries the server numbers',
    (r->>'unanswered_call_limit')::int = 4 AND (r->>'included_minutes')::int = 45
    AND (r->>'max_call_minutes')::int = 60 AND (r->>'ring_seconds')::int = 30
    AND NOT r ? 'max_pack_refunds' AND (r->>'plan_window_minutes')::int = 30
    AND (r->>'log_retention_months')::int = 12 AND r ? 'calls_enabled', r::text);
  UPDATE private.call_settings SET unanswered_call_limit = 3, included_minutes = 30;
  r := pg_temp.usr(NULL, 'SELECT public.get_calling_rules()');
  PERFORM pg_temp.ok('rules need a signed-in account', r IS NULL OR r = 'null'::jsonb OR r ? 'error', r::text);

  -- ---- 5 Monthly brake --------------------------------------------------------
  PERFORM pg_temp.reset_calls();
  UPDATE private.call_settings SET monthly_cap_minutes = 10;
  INSERT INTO private.call_usage_months(month_start, charged_minutes) VALUES (private.call_month_start(), 10);
  n := private.call_refresh_month_cap();
  PERFORM pg_temp.ok('brake is at least entitled minutes + 25%',
    n >= ceil(((SELECT count(*) FROM public.users WHERE subscription_status = 'active'
               AND subscription_expires_at > now()) * 30) * 1.25)
    AND private.call_month_cap_minutes() = greatest(10, n), n::text);
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('a low manual cap never blocks entitled included minutes',
    r->>'outcome' = 'ringing', r::text);
  PERFORM pg_temp.svc(format('SELECT public.call_service_end(%L, %L, %L)', m1, (r->>'request_id')::uuid, 'cancelled'));
  UPDATE private.call_settings SET auto_cap_at = now() - interval '4 hours';
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w2));
  PERFORM pg_temp.ok('a stale entitlement figure falls back to the manual brake',
    r->>'outcome' = 'capacity', r::text);
  PERFORM pg_temp.reset_calls();

  -- ---- 12.7 Retention ---------------------------------------------------------
  rid := pg_temp.missed(m1, k_m1w1);
  rid2 := pg_temp.missed(m3, k_m3w1);
  UPDATE private.call_requests SET created_at = now() - interval '13 months' WHERE id IN (rid, rid2);
  INSERT INTO public.reports(reporter_id, reported_user_id, reason, status)
  VALUES (w1, m3, 'harassing_calls', 'pending');
  n := private.call_purge_old_records();
  PERFORM pg_temp.ok('calls older than 12 months are purged',
    NOT EXISTS (SELECT 1 FROM private.call_requests WHERE id = rid), n::text);
  PERFORM pg_temp.ok('an open report keeps the calls it needs',
    EXISTS (SELECT 1 FROM private.call_requests WHERE id = rid2), NULL);
  DELETE FROM public.reports WHERE reporter_id = w1 AND reported_user_id = m3;

  -- ---- Admin ------------------------------------------------------------------
  r := pg_temp.usr(m1, format('SELECT jsonb_agg(to_jsonb(h)) FROM public.admin_member_call_history(%L) h', w1));
  PERFORM pg_temp.ok('members cannot read others'' call history', r->>'error' = '42501', r::text);
  r := pg_temp.usr(m1, format('SELECT public.admin_report_call_context(%L)', gen_random_uuid()));
  PERFORM pg_temp.ok('members cannot read report call context', r->>'error' = '42501', r::text);
  r := pg_temp.usr(m1, format('SELECT to_jsonb(public.admin_adjust_call_minutes(%L, 100, %L))', m1, 'just because'));
  PERFORM pg_temp.ok('members cannot grant themselves minutes', r->>'error' = '42501', r::text);
  r := pg_temp.usr(m1, 'SELECT public.admin_call_overview()');
  PERFORM pg_temp.ok('members cannot read the admin overview', r->>'error' = '42501', r::text);

  -- ---- Reports, privileges, Guardian ------------------------------------------
  INSERT INTO public.reports(reporter_id, reported_user_id, reason, status)
  VALUES (w1, m1, 'harassing_calls', 'pending');
  PERFORM pg_temp.ok('report reason harassing_calls accepted',
    EXISTS (SELECT 1 FROM public.reports WHERE reporter_id = w1 AND reason = 'harassing_calls'), NULL);
  r := pg_temp.usr(m1, format('SELECT public.call_service_missed_push(%L)', gen_random_uuid()));
  PERFORM pg_temp.ok('members cannot call the push RPCs', r->>'error' = '42501', r::text);
  r := pg_temp.usr(m1, format('SELECT public.call_service_plan_reminder(%L)', gen_random_uuid()));
  PERFORM pg_temp.ok('members cannot call the reminder RPC', r->>'error' = '42501', r::text);
  r := pg_temp.usr(m1, 'SELECT to_jsonb(count(*)) FROM private.call_plans');
  PERFORM pg_temp.ok('members cannot read plans', r->>'error' = '42501', r::text);
  r := pg_temp.usr(m1, 'SELECT to_jsonb(count(*)) FROM private.call_device_capabilities');
  PERFORM pg_temp.ok('members cannot read phone capabilities', r->>'error' = '42501', r::text);
  r := pg_temp.usr(m1, format('SELECT jsonb_agg(to_jsonb(g)) FROM public.get_guardian_match_call_plans(%L) g', k_m1w2));
  PERFORM pg_temp.ok('Guardian plan log needs Guardian access', r->>'error' = '42501', r::text);
  r := pg_temp.usr(m1, 'SELECT to_jsonb(public.hide_my_calls(array_fill(gen_random_uuid(), ARRAY[201])))');
  PERFORM pg_temp.ok('hide is bounded', r->>'error' = '22023', r::text);
  PERFORM pg_temp.usr(m1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_m1w2));
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', m1, 'role', 'authenticated')::text, true);
  r := private.build_personal_data_export('vc-test');
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM pg_temp.ok('data export includes planned calls',
    jsonb_array_length(r->'calls'->'planned_calls') >= 1, left((r->'calls'->'planned_calls')::text, 300));
END $$;

SELECT n, ok, name, detail FROM t_results ORDER BY n;
ROLLBACK;
