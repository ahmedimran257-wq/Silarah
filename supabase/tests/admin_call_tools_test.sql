-- Rollback test for migration 339 (staff tools for voice calling). STAGING only:
--   (echo 'BEGIN;'; cat supabase/migrations/339_admin_call_tools.sql; cat this file) > t.sql   # if 339 is not applied
--   supabase db query --remote=ykmgkrveucslglxvcyss --file t.sql --yes -o json
-- One transaction ending in ROLLBACK; the last SELECT prints one row per rule.
BEGIN;

CREATE TEMP TABLE t_results (n serial, name text, ok boolean, detail text) ON COMMIT DROP;

CREATE FUNCTION pg_temp.ok(p_name text, p_ok boolean, p_detail text DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO t_results(name, ok, detail) VALUES (p_name, coalesce(p_ok, false), p_detail);
$$;

-- Runs p_sql as p_user. p_staff adds the AAL2 claim and the session id that
-- public.is_active_admin checks.
CREATE FUNCTION pg_temp.as_user(p_user uuid, p_sql text, p_staff boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_user, 'role', 'authenticated')
     || CASE WHEN p_staff THEN jsonb_build_object('aal', 'aal2', 'session_id', p_user) ELSE '{}'::jsonb END)::text,
    true);
  PERFORM set_config('role', 'authenticated', true);
  EXECUTE p_sql INTO v;
  PERFORM set_config('role', 'postgres', true);
  RETURN v;
EXCEPTION WHEN OTHERS THEN
  PERFORM set_config('role', 'postgres', true);
  RETURN jsonb_build_object('error', SQLSTATE, 'message', SQLERRM);
END $$;

CREATE FUNCTION pg_temp.adm(p_user uuid, p_sql text) RETURNS jsonb LANGUAGE sql AS $$
  SELECT pg_temp.as_user(p_user, p_sql, true);
$$;

CREATE FUNCTION pg_temp.staff(p_id uuid, p_role text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO auth.users(id, aud, role, email, email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data)
  VALUES (p_id, 'authenticated', 'authenticated',
    'vcstaff.' || right(p_id::text, 4) || '@silarah.test', now(), now(), now(), '{}', '{}');
  -- Session id = user id, so the claim above matches it.
  INSERT INTO auth.sessions(id, user_id, created_at, updated_at, aal)
  VALUES (p_id, p_id, now(), now(), 'aal2');
  INSERT INTO public.admin_memberships(user_id, role, status) VALUES (p_id, p_role, 'active');
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
  VALUES (p_id, p_first, 'Qatest', date '1995-01-01', p_gender, 'IN', 'visible', true,
    (SELECT c.id FROM public.cities c JOIN public.regions r ON r.id = c.region_id
     WHERE upper(r.country_code) = 'IN' ORDER BY c.id LIMIT 1));
END $$;

DO $$
DECLARE
  super uuid := gen_random_uuid();
  mod uuid := gen_random_uuid();
  sup uuid := gen_random_uuid();
  m1 uuid := gen_random_uuid();   -- reported member (caller), has pack minutes
  w1 uuid := gen_random_uuid();   -- reporter
  x1 uuid := gen_random_uuid();   -- files a second, different report
  k uuid;
  rep uuid;
  rep2 uuid;
  job bigint;
  job2 bigint;
  r jsonb;
  n_audit integer;
  n_settings_audit integer;
  n_periods integer;
  v_hold integer;
BEGIN
  PERFORM pg_temp.staff(super, 'super_admin');
  PERFORM pg_temp.staff(mod, 'moderator');
  PERFORM pg_temp.staff(sup, 'support');
  PERFORM pg_temp.member(m1, 'male', 'Vcman', false);
  PERFORM pg_temp.member(w1, 'female', 'Vcwoman', true);
  PERFORM pg_temp.member(x1, 'female', 'Vcother', false);
  INSERT INTO public.matches(user_a, user_b, status, guardian_approved)
  VALUES (m1, w1, 'active', true) RETURNING id INTO k;
  SELECT max_hold_minutes INTO v_hold FROM private.call_settings WHERE id;

  -- 1. Reading the settings ----------------------------------------------
  r := pg_temp.adm(sup, 'SELECT public.admin_call_settings()');
  PERFORM pg_temp.ok('support can read call settings',
    jsonb_array_length(r->'values') = 13 AND r ? 'fixed' AND r ? 'effective_cap_minutes', left(r::text, 300));
  PERFORM pg_temp.ok('settings list bounds inside the table checks',
    (SELECT bool_and((v->>'min')::int <= (v->>'value')::int AND (v->>'value')::int <= (v->>'max')::int)
     FROM jsonb_array_elements(r->'values') v), left((r->'values')::text, 400));
  PERFORM pg_temp.ok('period length, retention and terms version are not tunable',
    NOT EXISTS (SELECT 1 FROM jsonb_array_elements(r->'values') v
                WHERE v->>'key' IN ('included_period_days', 'log_retention_months', 'calls_enabled')),
    NULL);
  r := pg_temp.as_user(m1, 'SELECT public.admin_call_settings()');
  PERFORM pg_temp.ok('members cannot read call settings', r->>'error' = '42501', r::text);
  r := pg_temp.as_user(sup, 'SELECT public.admin_call_settings()');
  PERFORM pg_temp.ok('staff without AAL2 cannot read call settings', r->>'error' = '42501', r::text);

  -- 2. Changing them -------------------------------------------------------
  SELECT count(*) INTO n_audit FROM public.admin_audit_log WHERE action_type = 'voice_call_settings_changed';
  SELECT count(*) INTO n_settings_audit FROM private.call_settings_audit;
  r := pg_temp.adm(mod, $q$SELECT public.admin_update_call_settings('{"max_hold_minutes": 45}', 'moderator try')$q$);
  PERFORM pg_temp.ok('moderators cannot change call settings', r->>'error' = '42501', r::text);
  r := pg_temp.adm(sup, $q$SELECT public.admin_update_call_settings('{"max_hold_minutes": 45}', 'support try')$q$);
  PERFORM pg_temp.ok('support cannot change call settings', r->>'error' = '42501', r::text);

  r := pg_temp.adm(super, $q$SELECT public.admin_update_call_settings('{"max_hold_minutes": 500}', 'too long a call')$q$);
  PERFORM pg_temp.ok('values outside the bounds are refused', r->>'error' = '22023' AND r->>'message' LIKE '%between%', r::text);
  r := pg_temp.adm(super, $q$SELECT public.admin_update_call_settings('{"included_period_days": 10}', 'shorter periods')$q$);
  PERFORM pg_temp.ok('period length cannot be changed', r->>'error' = '22023', r::text);
  r := pg_temp.adm(super, $q$SELECT public.admin_update_call_settings('{"calls_enabled": 0}', 'switch via editor')$q$);
  PERFORM pg_temp.ok('the switch is not part of the editor', r->>'error' = '22023', r::text);
  r := pg_temp.adm(super, $q$SELECT public.admin_update_call_settings('{"max_hold_minutes": 45.5}', 'half a minute')$q$);
  PERFORM pg_temp.ok('fractions are refused', r->>'error' = '22023', r::text);
  r := pg_temp.adm(super, $q$SELECT public.admin_update_call_settings('{"max_hold_minutes": 45}', 'no')$q$);
  PERFORM pg_temp.ok('a reason is required', r->>'error' = '22023', r::text);
  r := pg_temp.adm(super, format($q$SELECT public.admin_update_call_settings('{"max_hold_minutes": %s}', 'same value again')$q$, v_hold));
  PERFORM pg_temp.ok('an unchanged save is refused', r->>'error' = '22023' AND r->>'message' LIKE 'Nothing changed%', r::text);
  r := pg_temp.adm(super, $q$SELECT public.admin_update_call_settings('{"plan_reminder_minutes": 30, "plan_min_lead_minutes": 10}', 'reminder after lead')$q$);
  PERFORM pg_temp.ok('a reminder longer than the planning notice is refused', r->>'error' = '22023', r::text);
  PERFORM pg_temp.ok('refused saves write nothing',
    (SELECT count(*) FROM public.admin_audit_log WHERE action_type = 'voice_call_settings_changed') = n_audit
    AND (SELECT count(*) FROM private.call_settings_audit) = n_settings_audit, NULL);

  r := pg_temp.adm(super, format($q$SELECT public.admin_update_call_settings('{"max_hold_minutes": %s, "unanswered_call_limit": "4"}', 'Launch tuning, owner approved')$q$,
                                 CASE WHEN v_hold = 45 THEN 50 ELSE 45 END));
  PERFORM pg_temp.ok('super admin can change settings',
    r ? 'changed' AND (r->'changed') ? 'max_hold_minutes' AND (r->'changed'->'unanswered_call_limit'->>'to')::int = 4, r::text);
  PERFORM pg_temp.ok('new values are in force',
    (SELECT max_hold_minutes IN (45, 50) AND max_hold_minutes <> v_hold AND unanswered_call_limit = 4
     FROM private.call_settings WHERE id), NULL);
  PERFORM pg_temp.ok('the change is in the admin audit log with the reason',
    EXISTS (SELECT 1 FROM public.admin_audit_log a
            WHERE a.action_type = 'voice_call_settings_changed' AND a.admin_id = super
              AND a.actor_role = 'super_admin'
              AND a.details->>'reason' = 'Launch tuning, owner approved'
              AND a.details->'changes' ? 'unanswered_call_limit'), NULL);
  PERFORM pg_temp.ok('the settings history names the staff member',
    (SELECT changed_by = super FROM private.call_settings_audit ORDER BY id DESC LIMIT 1), NULL);

  -- The hourly auto cap writes an audit row; the last change is still ours.
  PERFORM private.call_refresh_month_cap();
  r := pg_temp.adm(mod, 'SELECT public.admin_call_settings()');
  PERFORM pg_temp.ok('last change skips the hourly auto-cap refresh',
    (r->'last_change'->>'changed_by')::uuid = super
    AND (SELECT count(*) FROM jsonb_array_elements(r->'last_change'->'changes')) = 2
    AND r->'last_change'->>'changed_by_email' LIKE 'vcstaff.%', left((r->'last_change')::text, 400));

  -- 3. Operations and failed jobs -----------------------------------------
  INSERT INTO private.call_jobs(kind, request_id, status, attempts, last_error)
  VALUES ('settle', gen_random_uuid(), 'dead', 30, 'stream 500: test failure') RETURNING id INTO job;
  INSERT INTO private.call_jobs(kind, user_id, status, attempts, last_error)
  VALUES ('seen_push', m1, 'dead', 30, 'fcm: unregistered') RETURNING id INTO job2;
  r := pg_temp.adm(sup, 'SELECT public.admin_call_operations()');
  PERFORM pg_temp.ok('support can see live calls and failed jobs',
    r ? 'live' AND r ? 'ringing' AND r ? 'months' AND r ? 'retrying_jobs'
    AND EXISTS (SELECT 1 FROM jsonb_array_elements(r->'dead_jobs') d
                WHERE (d->>'id')::bigint = job AND d->>'last_error' = 'stream 500: test failure'
                  AND (d->>'can_retry')::boolean)
    AND EXISTS (SELECT 1 FROM jsonb_array_elements(r->'dead_jobs') d
                WHERE (d->>'id')::bigint = job2 AND NOT (d->>'can_retry')::boolean), left(r::text, 400));
  r := pg_temp.as_user(m1, 'SELECT public.admin_call_operations()');
  PERFORM pg_temp.ok('members cannot see call operations', r->>'error' = '42501', r::text);

  r := pg_temp.adm(sup, format('SELECT public.admin_retry_call_job(%s, %L)', job, 'support retry'));
  PERFORM pg_temp.ok('support cannot retry jobs', r->>'error' = '42501', r::text);
  r := pg_temp.adm(super, format('SELECT public.admin_retry_call_job(%s, %L)', job2, 'retry a push'));
  PERFORM pg_temp.ok('notification jobs are not retried', r->>'error' = '22023', r::text);
  r := pg_temp.adm(super, format('SELECT public.admin_retry_call_job(%s, %L)', job, 'Stream outage over'));
  PERFORM pg_temp.ok('super admin can retry a failed settle job',
    (r->>'queued')::boolean
    AND (SELECT status = 'pending' AND attempts = 0 FROM private.call_jobs WHERE id = job), r::text);
  PERFORM pg_temp.ok('the retry is audited with the old error',
    EXISTS (SELECT 1 FROM public.admin_audit_log a
            WHERE a.action_type = 'voice_call_job_retried' AND a.admin_id = super
              AND (a.details->>'job_id')::bigint = job
              AND a.details->>'last_error' = 'stream 500: test failure'), NULL);
  r := pg_temp.adm(super, format('SELECT public.admin_retry_call_job(%s, %L)', job, 'Stream outage over'));
  PERFORM pg_temp.ok('a job already queued is not retried twice', r->>'error' = '22023', r::text);

  -- 4. A member's minutes --------------------------------------------------
  INSERT INTO private.call_wallets(user_id, pack_minutes) VALUES (m1, 20);
  INSERT INTO private.call_ledger(user_id, kind, pack_minutes_delta, product_id, transaction_id, provider_event_id)
  VALUES (m1, 'pack_purchase', 20, 'silarah_calls_20', 'GPA.vcqa-1', 'ev-vcqa-1');
  INSERT INTO private.call_ledger(user_id, kind, pack_minutes_delta, note)
  VALUES (m1, 'hold', -5, 'hold rows are hidden');
  INSERT INTO private.call_pack_pending_refunds(transaction_id, app_user_id, product_id, provider_event_id)
  VALUES ('GPA.vcqa-2', m1::text, 'silarah_calls_60', 'ev-vcqa-2');
  INSERT INTO private.call_pack_unclaimed(provider_event_id, app_user_id, aliases, product_id, reason)
  VALUES ('ev-vcqa-3', '$RCAnonymousID:vcqa', ARRAY[m1::text], 'silarah_calls_20', 'unknown_user');
  SELECT count(*) INTO n_periods FROM private.call_included_periods;

  r := pg_temp.adm(sup, format('SELECT public.admin_member_call_wallet(%L)', m1));
  PERFORM pg_temp.ok('support sees pack minutes, ledger and waiting packs',
    (r->>'pack_minutes')::int = 20 AND NOT (r->>'premium')::boolean
    AND jsonb_array_length(r->'ledger') = 1 AND r->'ledger'->0->>'transaction_id' = 'GPA.vcqa-1'
    AND jsonb_array_length(r->'pending_refunds') = 1
    AND jsonb_array_length(r->'packs_waiting') = 1, left(r::text, 500));
  r := pg_temp.adm(mod, format('SELECT public.admin_member_call_wallet(%L)', w1));
  PERFORM pg_temp.ok('a Premium member without a run shows no period, read only',
    (r->>'premium')::boolean AND r->'period' = 'null'::jsonb AND (r->>'pack_minutes')::int = 0
    AND (SELECT count(*) FROM private.call_included_periods) = n_periods
    AND NOT EXISTS (SELECT 1 FROM private.call_wallets WHERE user_id = w1), left(r::text, 300));
  r := pg_temp.adm(sup, format('SELECT public.admin_member_call_wallet(%L)', gen_random_uuid()));
  PERFORM pg_temp.ok('an unknown member returns nothing', r IS NULL OR r = 'null'::jsonb, coalesce(r::text, 'null'));
  r := pg_temp.as_user(m1, format('SELECT public.admin_member_call_wallet(%L)', m1));
  PERFORM pg_temp.ok('members cannot read wallets through the staff RPC', r->>'error' = '42501', r::text);

  -- 5. Reports by reason, with calls -------------------------------------
  INSERT INTO private.call_requests(match_id, caller_id, callee_id, status, reason, created_at, closed_at)
  VALUES (k, m1, w1, 'declined', 'declined', now() - interval '2 hours', now() - interval '2 hours'),
         (k, m1, w1, 'missed', 'timeout', now() - interval '90 minutes', now() - interval '90 minutes'),
         (k, m1, w1, 'cancelled', 'caller_cancelled', now() - interval '1 hour', now() - interval '1 hour');
  INSERT INTO public.reports(reporter_id, reported_user_id, reason, description, status)
  VALUES (w1, m1, 'harassing_calls', 'keeps calling', 'pending') RETURNING id INTO rep;
  INSERT INTO public.reports(reporter_id, reported_user_id, reason, status)
  VALUES (x1, m1, 'fake_profile', 'pending') RETURNING id INTO rep2;

  r := pg_temp.adm(mod, $q$SELECT public.admin_reports_by_reason('harassing_calls', 100)$q$);
  PERFORM pg_temp.ok('moderators can filter reports to harassing calls',
    EXISTS (SELECT 1 FROM jsonb_array_elements(r->'rows') x
            WHERE (x->>'report_id')::uuid = rep AND (x->>'unanswered_24h')::int = 3
              AND (x->>'calls_to_reporter_90d')::int = 3 AND (x->>'report_count')::int >= 2)
    AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(r->'rows') x WHERE x->>'reason' <> 'harassing_calls')
    AND (r->'counts'->>'harassing_calls')::int >= 1 AND (r->'counts'->>'fake_profile')::int >= 1, left(r::text, 500));
  r := pg_temp.adm(mod, 'SELECT public.admin_reports_by_reason(NULL, 100)');
  PERFORM pg_temp.ok('no reason lists every open report',
    EXISTS (SELECT 1 FROM jsonb_array_elements(r->'rows') x WHERE (x->>'report_id')::uuid = rep2), NULL);
  r := pg_temp.adm(sup, 'SELECT public.admin_reports_by_reason(NULL, 100)');
  PERFORM pg_temp.ok('support cannot read the reports queue', r->>'error' = '42501', r::text);

  -- 6. Overview keeps its keys and adds the dashboard ones -----------------
  r := pg_temp.adm(sup, 'SELECT public.admin_call_overview()');
  PERFORM pg_temp.ok('overview keeps the 324 keys',
    r ?& ARRAY['calls_enabled', 'monthly_cap_minutes', 'effective_cap_minutes', 'auto_cap_minutes',
               'estimated_stream_cost_usd', 'month_charged_minutes', 'open_hold_minutes',
               'live_calls', 'calls_today', 'dead_jobs'], r::text);
  PERFORM pg_temp.ok('overview adds packs waiting, refunds and retrying jobs',
    (r->>'unclaimed_packs')::int >= 1 AND (r->>'pending_refunds')::int >= 1
    AND (r->>'dead_jobs')::int >= 1 AND r ? 'retrying_jobs' AND r ? 'ringing_now' AND r ? 'auto_cap_at', r::text);
END $$;

SELECT n, ok, name, detail FROM t_results ORDER BY n;
ROLLBACK;
