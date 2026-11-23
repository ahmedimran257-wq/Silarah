-- Rollback test for migration 326 (a call's result before settlement;
-- docs/voice_calling_spec.md 12.5). STAGING only, same runner as the others.
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
  INSERT INTO public.notification_prefs(user_id, quiet_start, quiet_end)
  VALUES (p_id, time '00:00', time '00:00')
  ON CONFLICT (user_id) DO UPDATE SET quiet_start = time '00:00', quiet_end = time '00:00';
  INSERT INTO public.user_fcm_tokens(user_id, device_id, fcm_token, platform)
  VALUES (p_id, 'vcqa-' || replace(p_id::text, '-', ''), 'vcqa-token-' || p_id, 'android')
  ON CONFLICT (user_id, device_id) DO NOTHING;
  INSERT INTO private.call_device_capabilities(user_id, device_id, can_ring)
  VALUES (p_id, 'vcqa-' || replace(p_id::text, '-', ''), true)
  ON CONFLICT (user_id, device_id) DO UPDATE SET can_ring = true;
END $$;

CREATE FUNCTION pg_temp.match(p_a uuid, p_b uuid) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v uuid;
BEGIN
  INSERT INTO public.matches(user_a, user_b, status, guardian_approved)
  VALUES (p_a, p_b, 'active', true) RETURNING id INTO v;
  RETURN v;
END $$;

DO $$
BEGIN
  DELETE FROM private.call_jobs;
  DELETE FROM private.call_requests;
  UPDATE private.call_settings SET calls_enabled = true, monthly_cap_minutes = 100000,
    auto_cap_minutes = NULL, auto_cap_at = NULL, calling_consent_version = NULL;
END $$;

DO $$
DECLARE
  m1 uuid := '00000000-0000-4000-8000-0000000f0001';
  w1 uuid := '00000000-0000-4000-8000-0000000f0002';
  k uuid; rid uuid; rid2 uuid; r jsonb; ov jsonb;
BEGIN
  PERFORM pg_temp.member(m1, 'male', 'Arif', true);
  PERFORM pg_temp.member(w1, 'female', 'Sana', false);
  k := pg_temp.match(m1, w1);

  -- A call both were in, ended, not settled yet.
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k));
  rid := (r->>'request_id')::uuid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w1, rid));
  UPDATE private.call_sessions SET status = 'ended', both_joined_at = accepted_at, ended_at = now()
  WHERE request_id = rid;
  r := pg_temp.usr(m1, 'SELECT jsonb_agg(to_jsonb(l)) FROM public.get_my_call_log() l');
  PERFORM pg_temp.ok('caller: a connected call is answered before settlement',
    (SELECT e->>'outcome' FROM jsonb_array_elements(r) e WHERE (e->>'request_id')::uuid = rid) = 'answered', r::text);
  r := pg_temp.usr(w1, 'SELECT jsonb_agg(to_jsonb(l)) FROM public.get_my_call_log() l');
  PERFORM pg_temp.ok('callee: the same', (SELECT e->>'outcome' FROM jsonb_array_elements(r) e
    WHERE (e->>'request_id')::uuid = rid) = 'answered', r::text);
  r := pg_temp.usr(m1, format('SELECT public.get_chat_call_state(%L)', k));
  PERFORM pg_temp.ok('chat: the same', r->'events'->0->>'outcome' = 'answered', left(r::text, 300));
  ov := pg_temp.usr(m1, 'SELECT public.get_my_call_overview()');
  PERFORM pg_temp.ok('the overview says the call is being settled', (ov->>'settling')::boolean, ov::text);
  ov := pg_temp.usr(w1, 'SELECT public.get_my_call_overview()');
  PERFORM pg_temp.ok('for the callee too', (ov->>'settling')::boolean, ov::text);

  -- Settled with 0 s (the two never heard each other): not answered after all.
  r := pg_temp.svc(format('SELECT public.call_service_settle(%L, 0, %L)', rid, 'test'));
  PERFORM pg_temp.ok('settles (returns the hold)', r->>'outcome' = 'settled', r::text);
  r := pg_temp.usr(m1, 'SELECT jsonb_agg(to_jsonb(l)) FROM public.get_my_call_log() l');
  PERFORM pg_temp.ok('settled at 0 s: the caller sees no answer', (SELECT e->>'outcome' FROM jsonb_array_elements(r) e
    WHERE (e->>'request_id')::uuid = rid) = 'no_answer', r::text);
  ov := pg_temp.usr(m1, 'SELECT public.get_my_call_overview()');
  PERFORM pg_temp.ok('nothing left to settle', NOT (ov->>'settling')::boolean, ov::text);

  -- Ended without both ever joining: never answered.
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k));
  rid2 := (r->>'request_id')::uuid;
  PERFORM pg_temp.ok('second call rings', r->>'outcome' = 'ringing', r::text);
  PERFORM pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w1, rid2));
  UPDATE private.call_sessions SET status = 'ended', ended_at = now() WHERE request_id = rid2;
  r := pg_temp.usr(m1, 'SELECT jsonb_agg(to_jsonb(l)) FROM public.get_my_call_log() l');
  PERFORM pg_temp.ok('ended before both joined: no answer, even unsettled', (SELECT e->>'outcome'
    FROM jsonb_array_elements(r) e WHERE (e->>'request_id')::uuid = rid2) = 'no_answer', r::text);
  r := pg_temp.usr(w1, 'SELECT jsonb_agg(to_jsonb(l)) FROM public.get_my_call_log() l');
  PERFORM pg_temp.ok('callee: not connected', (SELECT e->>'outcome'
    FROM jsonb_array_elements(r) e WHERE (e->>'request_id')::uuid = rid2) = 'not_connected', r::text);
  PERFORM pg_temp.ok('the 5-argument helper is gone',
    to_regprocedure('private.call_outcome_for(uuid, uuid, text, integer, text)') IS NULL, NULL);
END $$;

SELECT n, ok, name, detail FROM t_results ORDER BY n;
ROLLBACK;
