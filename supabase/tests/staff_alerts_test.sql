-- Rollback test for migration 340 (staff alerts, privacy-request emails,
-- purge cron fix). STAGING only:
--   (echo 'BEGIN;'; cat supabase/migrations/340_staff_alerts_and_privacy_emails.sql; cat this file) > t.sql   # if 340 is not applied
--   supabase db query --remote=ykmgkrveucslglxvcyss --file t.sql --yes -o json
-- One transaction ending in ROLLBACK; the last SELECT prints one row per rule.
-- No email is sent: rows are queued and the worker wake-ups are rolled back.
BEGIN;

CREATE TEMP TABLE t_results (n serial, name text, ok boolean, detail text) ON COMMIT DROP;

CREATE FUNCTION pg_temp.ok(p_name text, p_ok boolean, p_detail text DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO t_results(name, ok, detail) VALUES (p_name, coalesce(p_ok, false), p_detail);
$$;

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

CREATE FUNCTION pg_temp.staff(p_id uuid, p_role text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO auth.users(id, aud, role, email, email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data)
  VALUES (p_id, 'authenticated', 'authenticated',
    'vcstaff.' || right(p_id::text, 4) || '@silarah.test', now(), now(), now(), '{}', '{}');
  INSERT INTO auth.sessions(id, user_id, created_at, updated_at, aal)
  VALUES (p_id, p_id, now(), now(), 'aal2');
  INSERT INTO public.admin_memberships(user_id, role, status) VALUES (p_id, p_role, 'active');
END $$;

CREATE FUNCTION pg_temp.member(p_id uuid, p_gender text, p_first text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO auth.users(id, aud, role, email, email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data)
  VALUES (p_id, 'authenticated', 'authenticated',
    'vcqa.' || right(p_id::text, 4) || '@gmail.com', now(), now(), now(), '{}', '{}');
  INSERT INTO public.users(id, email, gender, country_code, timezone, subscription_status)
  VALUES (p_id, 'vcqa.' || right(p_id::text, 4) || '@gmail.com', p_gender, 'IN', 'Asia/Kolkata', 'none');
  INSERT INTO public.profiles(user_id, first_name, last_name, date_of_birth, gender,
    country_code, visibility, onboarding_completed, city_id)
  VALUES (p_id, p_first, 'Qatest', date '1995-01-01', p_gender, 'IN', 'visible', true,
    (SELECT c.id FROM public.cities c JOIN public.regions r ON r.id = c.region_id
     WHERE upper(r.country_code) = 'IN' ORDER BY c.id LIMIT 1));
END $$;

CREATE FUNCTION pg_temp.inbox(p_type text, p_user uuid) RETURNS bigint LANGUAGE sql AS $$
  SELECT count(*) FROM public.admin_notifications WHERE type = p_type AND related_user_id = p_user;
$$;

DO $$
DECLARE
  super uuid := gen_random_uuid();
  sup uuid := gen_random_uuid();
  m1 uuid := gen_random_uuid();
  m2 uuid := gen_random_uuid();
  m3 uuid := gen_random_uuid();
  req uuid;
  req2 uuid;
  r jsonb;
  v_email uuid;
  v_updated timestamptz;
  n bigint;
BEGIN
  PERFORM pg_temp.staff(super, 'super_admin');
  PERFORM pg_temp.staff(sup, 'support');
  PERFORM pg_temp.member(m1, 'female', 'Prfirst');
  PERFORM pg_temp.member(m2, 'male', 'Prsecond');
  PERFORM pg_temp.member(m3, 'male', 'Prthird');

  -- 1. A new privacy request ------------------------------------------------
  r := pg_temp.as_user(m1, format(
    'SELECT to_jsonb(public.submit_my_privacy_request(%L, %L, %L))',
    gen_random_uuid(), 'erasure', 'Please erase my messages and photos, sensitive detail here.'));
  req := (r #>> '{}')::uuid;
  PERFORM pg_temp.ok('member can file a privacy request', req IS NOT NULL, r::text);
  PERFORM pg_temp.ok('new request reaches the staff inbox',
    EXISTS (SELECT 1 FROM public.admin_notifications a
            WHERE a.type = 'privacy_request_received' AND a.related_user_id = m1
              AND a.message LIKE '%erasure request (reference ' || req || ')%'
              AND a.message LIKE '%IST.'), NULL);
  PERFORM pg_temp.ok('the alert does not carry the member''s details',
    NOT EXISTS (SELECT 1 FROM public.admin_notifications a
                WHERE a.related_user_id = m1 AND a.message LIKE '%sensitive detail%')
    AND NOT EXISTS (SELECT 1 FROM private.staff_alert_emails e WHERE e.message LIKE '%sensitive detail%'), NULL);
  PERFORM pg_temp.ok('new request queues one staff email',
    (SELECT count(*) FROM private.staff_alert_emails e
     WHERE e.alert_key = 'privacy_request_received' AND e.message LIKE '%' || req || '%') = 1, NULL);
  PERFORM pg_temp.ok('new request queues the member confirmation email',
    EXISTS (SELECT 1 FROM private.privacy_request_emails e WHERE e.request_id = req AND e.event = 'received'), NULL);

  r := pg_temp.as_user(m1, 'SELECT to_jsonb(count(*)) FROM public.claim_privacy_request_emails(10)');
  PERFORM pg_temp.ok('members cannot claim privacy emails', r->>'error' = '42501', r::text);
  r := pg_temp.svc('SELECT coalesce(jsonb_agg(to_jsonb(c)), ''[]''::jsonb) FROM public.claim_privacy_request_emails(25) c');
  PERFORM pg_temp.ok('the worker gets address, reference, kind and due date',
    EXISTS (SELECT 1 FROM jsonb_array_elements(r) x
            WHERE (x->>'request_id')::uuid = req AND x->>'email_event' = 'received'
              AND x->>'recipient' = 'vcqa.' || right(m1::text, 4) || '@gmail.com'
              AND x->>'first_name' = 'Prfirst' AND x->>'request_kind' = 'erasure'
              AND (x->>'due_at')::timestamptz > now() + interval '6 days'), left(r::text, 400));
  SELECT e.id INTO v_email FROM private.privacy_request_emails e WHERE e.request_id = req AND e.event = 'received';
  r := pg_temp.svc(format('SELECT to_jsonb(public.complete_privacy_request_email(%L, true, NULL))', v_email));
  PERFORM pg_temp.ok('a sent email is marked sent',
    (SELECT sent_at IS NOT NULL AND claimed_at IS NULL FROM private.privacy_request_emails WHERE id = v_email), r::text);
  r := pg_temp.svc('SELECT to_jsonb(count(*)) FROM public.claim_privacy_request_emails(25) c WHERE c.request_id = ' || quote_literal(req));
  PERFORM pg_temp.ok('a sent email is not claimed again', (r #>> '{}')::int = 0, r::text);

  -- 2. Staff answer it, audited, and the member is told -----------------------
  SELECT updated_at INTO v_updated FROM public.privacy_requests WHERE id = req;
  r := pg_temp.as_user(sup, format(
    'SELECT to_jsonb(public.review_privacy_request(%L, %L, %L, %L))',
    req, 'resolved', 'Your messages and photos were erased on request.', v_updated), true);
  PERFORM pg_temp.ok('support can resolve a request', NOT (r ? 'error'), r::text);
  PERFORM pg_temp.ok('the decision is in the admin audit log',
    EXISTS (SELECT 1 FROM public.admin_audit_log a
            WHERE a.action_type = 'privacy_request_reviewed' AND a.admin_id = sup AND a.target_user_id = m1
              AND a.details->>'to' = 'resolved' AND (a.details->>'request_id')::uuid = req
              AND NOT (a.details ? 'response')), NULL);
  PERFORM pg_temp.ok('resolving queues the member "answered" email',
    EXISTS (SELECT 1 FROM private.privacy_request_emails e WHERE e.request_id = req AND e.event = 'resolved'), NULL);
  r := pg_temp.as_user(super, format(
    'SELECT to_jsonb(public.set_privacy_request_hold(%L, now() + interval ''30 days'', %L))',
    req, 'Legal hold for an open court order'), true);
  PERFORM pg_temp.ok('a legal hold is audited',
    NOT (r ? 'error') AND EXISTS (SELECT 1 FROM public.admin_audit_log a
            WHERE a.action_type = 'privacy_request_hold_set' AND a.admin_id = super
              AND (a.details->>'request_id')::uuid = req), r::text);

  -- 3. Reminders: once before the due date, once when overdue ----------------
  r := pg_temp.as_user(m2, format(
    'SELECT to_jsonb(public.submit_my_privacy_request(%L, %L, %L))',
    gen_random_uuid(), 'access', 'Send me a copy of all my data please.'));
  req2 := (r #>> '{}')::uuid;
  UPDATE public.privacy_requests SET due_at = now() + interval '1 day' WHERE id = req2;
  PERFORM private.capture_staff_deadline_alerts();
  PERFORM private.capture_staff_deadline_alerts();
  PERFORM pg_temp.ok('due-soon reminder fires once, with a staff email',
    pg_temp.inbox('privacy_request_due_soon', m2) = 1
    AND (SELECT count(*) FROM private.staff_alert_emails e
         WHERE e.alert_key = 'privacy_request_due_soon' AND e.message LIKE '%' || req2 || '%') = 1, NULL);
  UPDATE public.privacy_requests SET due_at = now() - interval '1 hour' WHERE id = req2;
  PERFORM private.capture_staff_deadline_alerts();
  PERFORM private.capture_staff_deadline_alerts();
  PERFORM pg_temp.ok('overdue reminder fires once, with a staff email',
    pg_temp.inbox('privacy_request_overdue', m2) = 1
    AND (SELECT count(*) FROM private.staff_alert_emails e
         WHERE e.alert_key = 'privacy_request_overdue' AND e.message LIKE '%' || req2 || '%') = 1, NULL);
  PERFORM pg_temp.ok('a resolved request gets no reminders',
    pg_temp.inbox('privacy_request_due_soon', m1) = 0 AND pg_temp.inbox('privacy_request_overdue', m1) = 0, NULL);

  -- 4. Single events -----------------------------------------------------------
  INSERT INTO public.reports(reporter_id, reported_user_id, reason, status)
  VALUES (m1, m2, 'harassing_calls', 'pending');
  PERFORM pg_temp.ok('a harassing-calls report gets its own inbox item',
    pg_temp.inbox('harassing_calls_report', m2) = 1, NULL);
  INSERT INTO public.reports(reporter_id, reported_user_id, reason, status)
  VALUES (m1, m3, 'fake_profile', 'pending');
  PERFORM pg_temp.ok('other reasons do not', pg_temp.inbox('harassing_calls_report', m3) = 0, NULL);

  UPDATE public.users SET deletion_status = 'pending_deletion', deletion_source = 'member',
    deletion_requested_at = now(), deleted_at = now() WHERE id = m3;
  PERFORM pg_temp.ok('a member deletion request reaches the inbox',
    pg_temp.inbox('account_deletion_requested', m3) = 1, NULL);
  UPDATE public.users SET deletion_status = 'pending_deletion', deletion_source = 'staff',
    deletion_requested_at = now(), deleted_at = now() WHERE id = m2;
  PERFORM pg_temp.ok('staff-started deletions do not (already audited)',
    pg_temp.inbox('account_deletion_requested', m2) = 0, NULL);
  UPDATE public.users SET deletion_status = 'active', deletion_source = NULL,
    deletion_requested_at = NULL, deleted_at = NULL WHERE id = m2;

  INSERT INTO public.subscription_events(user_id, event_type, event_timestamp_ms, product_id)
  VALUES (m1, 'REFUND', (extract(epoch FROM now()) * 1000)::bigint, 'silarah_premium_monthly');
  PERFORM pg_temp.ok('a Premium refund reaches the inbox',
    EXISTS (SELECT 1 FROM public.admin_notifications a
            WHERE a.type = 'subscription_refunded' AND a.related_user_id = m1
              AND a.message LIKE '%silarah_premium_monthly%'), NULL);

  INSERT INTO private.call_wallets(user_id, pack_minutes) VALUES (m1, -5);
  INSERT INTO private.call_ledger(user_id, kind, pack_minutes_delta, product_id, transaction_id)
  VALUES (m1, 'pack_refund', -20, 'silarah_calls_20', 'GPA.alerts-1');
  PERFORM pg_temp.ok('a pack refund reaches the inbox with the balance',
    EXISTS (SELECT 1 FROM public.admin_notifications a
            WHERE a.type = 'call_pack_refunded' AND a.related_user_id = m1
              AND a.message LIKE '%20 minutes%' AND a.message LIKE '%-5: below zero%'), NULL);

  -- 5. Deadline and failure alerts ------------------------------------------------
  UPDATE public.reports SET created_at = now() - interval '25 hours'
  WHERE reporter_id = m1 AND reported_user_id = m2;
  UPDATE public.users SET deletion_status = 'pending_deletion', deletion_source = 'member',
    deletion_requested_at = now() - interval '32 days', deleted_at = now() - interval '32 days' WHERE id = m3;
  INSERT INTO private.call_pack_pending_refunds(transaction_id, app_user_id, product_id, provider_event_id, received_at)
  VALUES ('GPA.alerts-2', m1::text, 'silarah_calls_60', 'ev-alerts-2', now() - interval '2 days');
  PERFORM private.capture_staff_deadline_alerts();
  PERFORM pg_temp.ok('reports waiting over a day raise an alert',
    (SELECT is_active AND last_value >= 1 FROM private.operational_alert_state WHERE alert_key = 'reports_waiting_24h'), NULL);
  PERFORM pg_temp.ok('an account past 30 days raises the purge alert',
    (SELECT is_active FROM private.operational_alert_state WHERE alert_key = 'account_purge_overdue'), NULL);
  PERFORM pg_temp.ok('a pack refund waiting a day raises an alert',
    (SELECT is_active FROM private.operational_alert_state WHERE alert_key = 'call_pack_refunds_waiting'), NULL);
  PERFORM pg_temp.ok('every check keeps an alert state',
    (SELECT count(*) FROM private.operational_alert_state WHERE alert_key IN (
      'photo_checks_due', 'reports_waiting_24h', 'account_purge_overdue', 'account_purge_stuck',
      'member_emails_failing', 'staff_alert_emails_failing', 'scheduled_jobs_failing',
      'call_pack_refunds_waiting')) = 8, NULL);
  PERFORM pg_temp.ok('a newly fired alert reaches the inbox and one staff email',
    EXISTS (SELECT 1 FROM public.admin_notifications a
            WHERE a.type = 'system_health_alert' AND a.message LIKE '%past the 30-day deletion date%')
    AND EXISTS (SELECT 1 FROM private.staff_alert_emails e WHERE e.alert_key = 'account_purge_overdue'), NULL);
  SELECT count(*) INTO n FROM private.staff_alert_emails WHERE alert_key = 'account_purge_overdue';
  PERFORM private.capture_staff_deadline_alerts();
  PERFORM pg_temp.ok('an alert that stays active is not emailed again',
    (SELECT count(*) FROM private.staff_alert_emails WHERE alert_key = 'account_purge_overdue') = n, NULL);

  -- 6. Schedules ------------------------------------------------------------------
  PERFORM pg_temp.ok('the 30-day purge cron uses the Vault-backed helper',
    (SELECT command LIKE '%private.invoke_edge_worker(''admin-purge-deleted-users''%'
            AND command NOT LIKE '%app.supabase_url%' AND schedule = '15 3 * * *'
     FROM cron.job WHERE jobname = 'trigger_purge_deleted_accounts'), NULL);
  PERFORM pg_temp.ok('the deadline check runs every 15 minutes',
    (SELECT schedule = '7-59/15 * * * *' AND active FROM cron.job WHERE jobname = 'staff_deadline_alerts_15m'), NULL);
  PERFORM private.retry_account_emails();
  PERFORM pg_temp.ok('the hourly email retry still runs', true, NULL);

  r := pg_temp.as_user(sup, 'SELECT public.admin_scheduled_jobs()', true);
  PERFORM pg_temp.ok('staff can see every scheduled job',
    jsonb_array_length(r->'jobs') = (SELECT count(*) FROM cron.job) AND r ? 'active_alerts', left(r::text, 300));
  PERFORM pg_temp.ok('job errors shown to staff are one line, no request headers',
    NOT EXISTS (SELECT 1 FROM jsonb_array_elements(r->'jobs') j
                WHERE j->>'last_error' LIKE '%' || chr(10) || '%' OR j->>'last_error' ILIKE '%secret%'), NULL);
  r := pg_temp.as_user(m1, 'SELECT public.admin_scheduled_jobs()');
  PERFORM pg_temp.ok('members cannot see scheduled jobs', r->>'error' = '42501', r::text);
END $$;

SELECT n, ok, name, detail FROM t_results ORDER BY n;
ROLLBACK;
