-- Rollback test for migration 332: "Calling…" until the ring reaches the
-- callee's phone, and only a ring that reached it counts towards the
-- unanswered-call limit (docs/voice_calling_spec.md 4 and 12.2). STAGING
-- only, same runner.
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

-- 332: the ring's receipt, and the unanswered-call limit counting only rings
-- that reached her phone.
DO $$
DECLARE
  m uuid := '00000000-0000-4000-8000-000000332001'; -- man, Premium
  w uuid := '00000000-0000-4000-8000-000000332002';
  k uuid; r jsonb; rid uuid; tok text; first_at timestamptz; i integer;
BEGIN
  PERFORM pg_temp.member(m, 'male', 'Faisal', true);
  PERFORM pg_temp.member(w, 'female', 'Zainab', false);
  k := pg_temp.match(m, w);

  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m, k));
  rid := (r->>'request_id')::uuid;
  tok := r->>'decline_token';
  r := pg_temp.svc(format('SELECT public.call_service_join(%L, %L)', m, rid));
  PERFORM pg_temp.ok('a new ring has not reached her phone: the caller sees Calling',
    r->>'outcome' = 'ringing' AND r->>'delivered' = 'false', r::text);
  r := pg_temp.svc(format('SELECT public.call_service_ring_delivered(%L, %L)', rid, repeat('0', 48)));
  PERFORM pg_temp.ok('a wrong token proves nothing',
    r->>'outcome' = 'not_found'
    AND (SELECT delivered_at FROM private.call_requests WHERE id = rid) IS NULL, r::text);
  r := pg_temp.svc(format('SELECT public.call_service_ring_delivered(%L, %L)', rid, tok));
  first_at := (SELECT delivered_at FROM private.call_requests WHERE id = rid);
  PERFORM pg_temp.ok('the ring token: delivered', r->>'outcome' = 'delivered' AND first_at IS NOT NULL, r::text);
  r := pg_temp.svc(format('SELECT public.call_service_join(%L, %L)', m, rid));
  PERFORM pg_temp.ok('the caller now sees Ringing', r->>'delivered' = 'true', r::text);
  r := pg_temp.svc(format('SELECT public.call_service_ring_delivered(%L, %L)', rid, tok));
  PERFORM pg_temp.ok('a second receipt keeps the first time',
    r->>'outcome' = 'delivered' AND (SELECT delivered_at FROM private.call_requests WHERE id = rid) = first_at, r::text);
  r := pg_temp.svc(format('SELECT public.call_service_decline_with_token(%L, %L)', rid, tok));
  PERFORM pg_temp.ok('Decline still works after a receipt (the token was not used up)',
    r->>'outcome' = 'declined', r::text);
  r := pg_temp.svc(format('SELECT public.call_service_ring_delivered(%L, %L)', rid, tok));
  PERFORM pg_temp.ok('a receipt after the ring ended changes nothing', r->>'outcome' <> 'delivered', r::text);
  PERFORM pg_temp.svc(format('SELECT public.call_service_join(%L, %L)', m, rid));

  -- The limit. Start from no history between them.
  DELETE FROM private.call_requests WHERE caller_id = m;
  FOR i IN 1..3 LOOP
    r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m, k));
    rid := (r->>'request_id')::uuid;
    UPDATE private.call_requests SET ring_expires_at = now() - interval '1 second' WHERE id = rid;
    PERFORM private.call_expire_ringing(m);
  END LOOP;
  r := pg_temp.svc(format('SELECT public.call_service_join(%L, %L)', m, rid));
  PERFORM pg_temp.ok('a ring that ran out unseen: missed, and the caller is told it never arrived',
    r->>'outcome' = 'missed' AND r->>'delivered' = 'false', r::text);
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m, k));
  PERFORM pg_temp.ok('3 rings that never reached her phone (data off): no limit',
    r->>'outcome' = 'ringing', r::text);
  PERFORM pg_temp.svc(format('SELECT public.call_service_end(%L, %L, %L)', m, (r->>'request_id')::uuid, 'cancelled'));
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m, k));
  PERFORM pg_temp.ok('a call cancelled before it reached her phone: no limit either',
    r->>'outcome' = 'ringing', r::text);
  PERFORM pg_temp.svc(format('SELECT public.call_service_end(%L, %L, %L)', m, (r->>'request_id')::uuid, 'cancelled'));

  FOR i IN 1..3 LOOP
    r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m, k));
    rid := (r->>'request_id')::uuid;
    PERFORM pg_temp.svc(format('SELECT public.call_service_ring_delivered(%L, %L)', rid, r->>'decline_token'));
    UPDATE private.call_requests SET ring_expires_at = now() - interval '1 second' WHERE id = rid;
    PERFORM private.call_expire_ringing(m);
  END LOOP;
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m, k));
  PERFORM pg_temp.ok('3 rings that reached her phone and went unanswered: blocked until tomorrow',
    r->>'outcome' = 'limit_reached' AND (r->>'retry_after')::timestamptz > now(), r::text);
END $$;

SELECT n, ok, name, detail FROM t_results ORDER BY n;
ROLLBACK;
