-- Rollback test for migration 327 (paid talk time never longer than the
-- hold; docs/voice_calling_spec.md 5). STAGING only, same runner.
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

CREATE FUNCTION pg_temp.joined(p_call text, p_user uuid, p_at timestamptz) RETURNS jsonb LANGUAGE sql AS $$
  SELECT pg_temp.svc(format('SELECT public.call_service_record_stream_event(%L,%L,%L,%L,%L,%L,%L,NULL)',
    'wh-' || gen_random_uuid(), 'call.session_participant_joined', p_call, 'sess-1', p_user, 'us-' || p_user, p_at));
$$;

DO $$
BEGIN
  DELETE FROM private.call_jobs;
  DELETE FROM private.call_requests;
  UPDATE private.call_settings SET calls_enabled = true, monthly_cap_minutes = 100000,
    auto_cap_minutes = NULL, auto_cap_at = NULL, calling_consent_version = NULL;
END $$;

DO $$
DECLARE
  m1 uuid := '00000000-0000-4000-8000-000000100001';
  w1 uuid := '00000000-0000-4000-8000-000000100002';
  m2 uuid := '00000000-0000-4000-8000-000000100003';
  w2 uuid := '00000000-0000-4000-8000-000000100004';
  k uuid; k2 uuid; rid uuid; r jsonb; call_id text; s private.call_sessions%ROWTYPE;
BEGIN
  PERFORM pg_temp.member(m1, 'male', 'Arif', true);
  PERFORM pg_temp.member(w1, 'female', 'Sana', false);
  PERFORM pg_temp.member(m2, 'male', 'Bilal', true);
  PERFORM pg_temp.member(w2, 'female', 'Hina', false);
  k := pg_temp.match(m1, w1);
  k2 := pg_temp.match(m2, w2);

  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k));
  rid := (r->>'request_id')::uuid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w1, rid));
  PERFORM pg_temp.svc(format('SELECT jsonb_build_object(''ok'', true) FROM (SELECT public.call_service_session_started(%L)) x', rid));
  SELECT * INTO s FROM private.call_sessions WHERE request_id = rid;
  call_id := s.stream_call_id;
  PERFORM pg_temp.ok('before both join, the limit has the full allowance',
    s.max_duration_seconds = s.hold_minutes * 60 + 30, to_jsonb(s)::text);
  r := pg_temp.joined(call_id, m1, now());
  PERFORM pg_temp.ok('one member in: nothing to change', r->>'action' = 'none', r::text);
  r := pg_temp.joined(call_id, w1, now() + interval '4 seconds');
  SELECT * INTO s FROM private.call_sessions WHERE request_id = rid;
  PERFORM pg_temp.ok('both in after 4 s: allowance = 4 s + 2 s, Stream told the new limit',
    r->>'action' = 'set_limit' AND (r->>'max_duration_seconds')::int = s.hold_minutes * 60 + 6
    AND s.max_duration_seconds = s.hold_minutes * 60 + 6 AND s.connect_seconds = 4
    AND r->>'stream_call_id' = call_id, r::text || to_jsonb(s)::text);
  r := pg_temp.joined(call_id, w1, now() + interval '9 seconds');
  PERFORM pg_temp.ok('a rejoin does not move it again', r->>'action' = 'none', r::text);

  UPDATE private.call_wallets SET pack_minutes = pack_minutes + 20 WHERE user_id = m1;
  r := pg_temp.svc(format('SELECT public.call_service_extend(%L, %L)', m1, rid));
  SELECT * INTO s FROM private.call_sessions WHERE request_id = rid;
  PERFORM pg_temp.ok('Add minutes keeps the real connect time',
    r->>'outcome' = 'extended' AND (r->>'max_duration_seconds')::int = s.hold_minutes * 60 + 6
    AND s.max_duration_seconds = s.hold_minutes * 60 + 6, r::text);

  -- Slow joining never eats paid time: capped at the allowance.
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m2, k2));
  rid := (r->>'request_id')::uuid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w2, rid));
  SELECT * INTO s FROM private.call_sessions WHERE request_id = rid;
  PERFORM pg_temp.joined(s.stream_call_id, m2, now());
  r := pg_temp.joined(s.stream_call_id, w2, now() + interval '50 seconds');
  SELECT * INTO s FROM private.call_sessions WHERE request_id = rid;
  PERFORM pg_temp.ok('joining took 50 s: the full 30 s allowance, never more',
    s.max_duration_seconds = s.hold_minutes * 60 + 30 AND s.connect_seconds = 50, to_jsonb(s)::text);
  r := pg_temp.usr(m2, format('SELECT public.call_service_record_stream_event(%L,%L,%L,%L,%L,%L,now(),NULL)',
    'x', 'call.session_participant_joined', s.stream_call_id, 's', m2, 'u'));
  PERFORM pg_temp.ok('members cannot send Stream events', r->>'error' = '42501', r::text);
END $$;

SELECT n, ok, name, detail FROM t_results ORDER BY n;
ROLLBACK;
