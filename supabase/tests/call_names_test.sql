-- Rollback test: the other member's name on a call (docs/voice_calling_spec.md
-- 7, 12.3, 12.5): first name only in pushes, first name and initial on Stream,
-- the full name on the call screen once matched. STAGING only, same runner.
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
    country_code, visibility, onboarding_completed, city_id)
  VALUES (p_id, p_first, 'Qatest', date '1995-01-01', p_gender, 'IN', 'visible', true, (SELECT c.id FROM public.cities c JOIN public.regions r ON r.id = c.region_id WHERE upper(r.country_code) = 'IN' ORDER BY c.id LIMIT 1));
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
  m1 uuid := '00000000-0000-4000-8000-000000120001'; -- man, Premium
  w1 uuid := '00000000-0000-4000-8000-000000120002';
  k uuid; rid uuid; r jsonb;
BEGIN
  PERFORM pg_temp.member(m1, 'male', 'Arif', true);
  PERFORM pg_temp.member(w1, 'female', 'Sana', false);
  k := pg_temp.match(m1, w1);

  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k));
  rid := (r->>'request_id')::uuid;
  PERFORM pg_temp.ok('the ring push names him by first name only (lock screen)',
    r->>'caller_name' = 'Arif', r::text);

  r := pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w1, rid));
  PERFORM pg_temp.ok('answering: her app shows his full name (matched)',
    r->>'caller_shown_name' = 'Arif Qatest', r::text);
  PERFORM pg_temp.ok('answering: Stream keeps first name and initial',
    r->>'caller_name' = 'Arif Q.' AND r->>'callee_name' = 'Sana Q.', r::text);

  PERFORM pg_temp.svc(format('SELECT to_jsonb(public.call_service_session_started(%L))', rid));
  r := pg_temp.svc(format('SELECT public.call_service_join(%L, %L)', m1, rid));
  PERFORM pg_temp.ok('in the call: his screen shows her full name; his Stream name stays short',
    r->>'other_name' = 'Sana Qatest' AND r->>'my_name' = 'Arif Q.', r::text);
  r := pg_temp.svc(format('SELECT public.call_service_join(%L, %L)', w1, rid));
  PERFORM pg_temp.ok('in the call: her screen shows his full name',
    r->>'other_name' = 'Arif Qatest', r::text);

  -- Once the match has ended the name goes back to first name and initial.
  UPDATE public.matches SET status = 'closed' WHERE id = k;
  PERFORM pg_temp.ok('not matched any more: first name and initial only',
    private.call_shown_name(m1, k) = 'Arif Q.', private.call_shown_name(m1, k));
END $$;

SELECT n, ok, name, detail FROM t_results ORDER BY n;
ROLLBACK;
