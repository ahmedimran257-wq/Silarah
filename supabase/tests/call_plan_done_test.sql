-- Rollback test for migration 330: a planned call is done as soon as its
-- call is settled (docs/voice_calling_spec.md 13.4). STAGING only, same runner.
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
  m1 uuid := '00000000-0000-4000-8000-000000140001'; -- man, Premium
  w1 uuid := '00000000-0000-4000-8000-000000140002';
  m2 uuid := '00000000-0000-4000-8000-000000140003'; -- another pair
  w2 uuid := '00000000-0000-4000-8000-000000140004';
  k2 uuid;
  k uuid; rid uuid; r jsonb; plan uuid; later uuid;
BEGIN
  PERFORM pg_temp.member(m1, 'male', 'Arif', true);
  PERFORM pg_temp.member(w1, 'female', 'Sana', false);
  k := pg_temp.match(m1, w1);

  -- Accepted for 5 minutes from now: Call now is showing.
  INSERT INTO private.call_plans(match_id, proposer_id, invitee_id, planned_for, status, responded_at)
  VALUES (k, m1, w1, now() + interval '5 minutes', 'accepted', now()) RETURNING id INTO plan;

  -- A call that never connected leaves the plan open.
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k));
  rid := (r->>'request_id')::uuid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w1, rid));
  UPDATE private.call_sessions SET status = 'ended', ended_at = now() WHERE request_id = rid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_settle(%L, 0, %L)', rid, 'test'));
  PERFORM pg_temp.ok('a call that never connected leaves the plan open',
    (SELECT status FROM private.call_plans WHERE id = plan) = 'accepted');

  -- They talk: the plan is done when the call is settled, not 30 minutes later.
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k));
  rid := (r->>'request_id')::uuid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w1, rid));
  UPDATE private.call_sessions SET status = 'ended', both_joined_at = accepted_at, ended_at = now()
  WHERE request_id = rid;
  r := pg_temp.svc(format('SELECT public.call_service_settle(%L, 24, %L)', rid, 'test'));
  PERFORM pg_temp.ok('settled', r->>'outcome' = 'settled', r::text);
  PERFORM pg_temp.ok('the plan is done as soon as its call is settled',
    (SELECT status = 'done' AND closed_at IS NOT NULL FROM private.call_plans WHERE id = plan));
  r := pg_temp.usr(m1, 'SELECT to_jsonb(public.get_my_call_overview())');
  PERFORM pg_temp.ok('it is no longer pinned as an open plan',
    NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(r->'plans', '[]')) p WHERE p->>'plan_id' = plan::text
                OR p->>'id' = plan::text), (r->'plans')::text);

  -- A plan for later the same day is not fulfilled by a call now.
  PERFORM pg_temp.member(m2, 'male', 'Bilal', true);
  PERFORM pg_temp.member(w2, 'female', 'Hiba', false);
  k2 := pg_temp.match(m2, w2);
  INSERT INTO private.call_plans(match_id, proposer_id, invitee_id, planned_for, status, responded_at)
  VALUES (k2, m2, w2, now() + interval '3 hours', 'accepted', now()) RETURNING id INTO later;
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m2, k2));
  rid := (r->>'request_id')::uuid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w2, rid));
  UPDATE private.call_sessions SET status = 'ended', both_joined_at = accepted_at, ended_at = now()
  WHERE request_id = rid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_settle(%L, 30, %L)', rid, 'test'));
  PERFORM pg_temp.ok('a call hours before a plan leaves that plan open',
    (SELECT status FROM private.call_plans WHERE id = later) = 'accepted');

  -- The sweep uses the same rule: an accepted plan whose window passed with a
  -- connected call in it is done, without one expired.
  UPDATE private.call_plans SET planned_for = now() - interval '31 minutes', status = 'accepted', closed_at = NULL
  WHERE id = plan;
  UPDATE private.call_requests SET created_at = now() - interval '35 minutes'
  WHERE match_id = k AND id = (SELECT request_id FROM private.call_sessions s
                               JOIN private.call_requests q ON q.id = s.request_id
                               WHERE q.match_id = k AND s.connected_seconds = 24);
  PERFORM private.call_close_due_plans();
  PERFORM pg_temp.ok('sweep: a connected call in the window makes it done',
    (SELECT status FROM private.call_plans WHERE id = plan) = 'done');
END $$;

-- 331: a planned call still unfinished when its window ends (gate 14,
-- 24 Nov 2026). The sweep expired the plan while they were still talking.
DO $$
DECLARE
  m3 uuid := '00000000-0000-4000-8000-000000140005'; -- still talking at the window's end
  w3 uuid := '00000000-0000-4000-8000-000000140006';
  m4 uuid := '00000000-0000-4000-8000-000000140007'; -- answered, never connected
  w4 uuid := '00000000-0000-4000-8000-000000140008';
  m5 uuid := '00000000-0000-4000-8000-000000140009'; -- a call that never settles
  w5 uuid := '00000000-0000-4000-8000-00000014000a';
  k uuid; rid uuid; r jsonb; plan uuid;
BEGIN
  PERFORM pg_temp.member(m3, 'male', 'Hamza', true);
  PERFORM pg_temp.member(w3, 'female', 'Maryam', false);
  k := pg_temp.match(m3, w3);
  INSERT INTO private.call_plans(match_id, proposer_id, invitee_id, planned_for, status, responded_at)
  VALUES (k, m3, w3, now() - interval '31 minutes', 'accepted', now() - interval '1 hour') RETURNING id INTO plan;
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m3, k));
  rid := (r->>'request_id')::uuid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w3, rid));
  UPDATE private.call_requests SET created_at = now() - interval '31 minutes' WHERE id = rid;
  UPDATE private.call_sessions SET status = 'active', both_joined_at = now() - interval '31 minutes'
  WHERE request_id = rid;
  PERFORM private.call_close_due_plans();
  PERFORM pg_temp.ok('331: still talking when the window ends: the plan stays open',
    (SELECT status FROM private.call_plans WHERE id = plan) = 'accepted');
  UPDATE private.call_sessions SET status = 'ended', ended_at = now() WHERE request_id = rid;
  PERFORM private.call_close_due_plans();
  PERFORM pg_temp.ok('331: ended but not yet settled: still open',
    (SELECT status FROM private.call_plans WHERE id = plan) = 'accepted');
  PERFORM pg_temp.svc(format('SELECT public.call_service_settle(%L, 1860, %L)', rid, 'test'));
  PERFORM pg_temp.ok('331: once settled, the plan is done',
    (SELECT status FROM private.call_plans WHERE id = plan) = 'done');

  -- Answered after the window passed but never connected: expired once settled.
  PERFORM pg_temp.member(m4, 'male', 'Idris', true);
  PERFORM pg_temp.member(w4, 'female', 'Huda', false);
  k := pg_temp.match(m4, w4);
  INSERT INTO private.call_plans(match_id, proposer_id, invitee_id, planned_for, status, responded_at)
  VALUES (k, m4, w4, now() - interval '31 minutes', 'accepted', now() - interval '1 hour') RETURNING id INTO plan;
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m4, k));
  rid := (r->>'request_id')::uuid;
  UPDATE private.call_requests SET created_at = now() - interval '30 minutes' WHERE id = rid;
  PERFORM private.call_close_due_plans();
  PERFORM pg_temp.ok('331: still ringing when the window ends: the plan stays open',
    (SELECT status FROM private.call_plans WHERE id = plan) = 'accepted');
  PERFORM pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w4, rid));
  UPDATE private.call_sessions SET status = 'ended', ended_at = now() WHERE request_id = rid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_settle(%L, 0, %L)', rid, 'test'));
  PERFORM private.call_close_due_plans();
  PERFORM pg_temp.ok('331: never connected: the next sweep expires it',
    (SELECT status FROM private.call_plans WHERE id = plan) = 'expired');

  -- A call stuck unsettled cannot keep a plan open past the longest call.
  PERFORM pg_temp.member(m5, 'male', 'Junaid', true);
  PERFORM pg_temp.member(w5, 'female', 'Khadija', false);
  k := pg_temp.match(m5, w5);
  INSERT INTO private.call_plans(match_id, proposer_id, invitee_id, planned_for, status, responded_at)
  VALUES (k, m5, w5, now() - interval '3 hours', 'accepted', now() - interval '4 hours') RETURNING id INTO plan;
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m5, k));
  rid := (r->>'request_id')::uuid;
  PERFORM pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w5, rid));
  UPDATE private.call_requests SET created_at = now() - interval '3 hours' WHERE id = rid;
  UPDATE private.call_sessions SET status = 'active' WHERE request_id = rid;
  PERFORM private.call_close_due_plans();
  PERFORM pg_temp.ok('331: a call stuck unsettled hours later does not keep the plan open',
    (SELECT status FROM private.call_plans WHERE id = plan) = 'expired');
END $$;

SELECT n, ok, name, detail FROM t_results ORDER BY n;
ROLLBACK;
