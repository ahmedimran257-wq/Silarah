-- Everything with a deadline or a safety impact now reaches staff, and
-- members hear back about privacy requests.
--
--  1. Privacy-rights requests (262): an admin inbox item and a staff email for
--     every new request, a reminder 2 days before due_at and another when it
--     is overdue, and member emails (received with the reference and due date;
--     answered when staff resolve it) through the account-email worker.
--     Staff decisions and legal holds are now in admin_audit_log too.
--  2. Inbox items for harassing-calls reports, member deletion requests,
--     Premium refunds and minute-pack refunds.
--  3. One 15-minute check (pg_cron, no new service) that raises operational
--     alerts (inbox + one staff email when an alert first fires) for: photo
--     checks near their 48-hour deadline, reports waiting over a day,
--     overdue or stuck account purges, member and staff emails not going out,
--     failed scheduled jobs and minute-pack refunds still waiting.
--  4. Fix: the daily 30-day purge cron (056) read app.supabase_url directly,
--     which is unset where the URL lives in Vault (278), so it failed every
--     night on staging and no scheduled deletion was purged. It now uses
--     private.invoke_edge_worker like every other worker.
--  5. admin_scheduled_jobs(): every cron job's last run and failures for the
--     System health page, so job failures are not visible only in SQL.

-- ---------------------------------------------------------------------------
-- 1. One way to tell staff
-- ---------------------------------------------------------------------------

-- An inbox item, and with p_email_key also one email to every active staff
-- member through the staff-alert-email worker (283).
CREATE FUNCTION private.notify_staff(
  p_type text, p_message text, p_user uuid DEFAULT NULL, p_email_key text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.admin_notifications(type, message, related_user_id)
  VALUES (p_type, left(p_message, 2000), p_user);
  IF p_email_key IS NOT NULL THEN
    INSERT INTO private.staff_alert_emails(alert_key, message)
    VALUES (p_email_key, left(p_message, 2000));
    PERFORM private.invoke_edge_worker('staff-alert-email', 'staff_alert_email_worker');
  END IF;
END;
$function$;
REVOKE ALL ON FUNCTION private.notify_staff(text, text, uuid, text) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION private.ist(p_at timestamptz)
RETURNS text
LANGUAGE sql IMMUTABLE SET search_path TO ''
AS $function$
  SELECT to_char(p_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH24:MI') || ' IST';
$function$;
REVOKE ALL ON FUNCTION private.ist(timestamptz) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION private.privacy_kind_label(p_kind text)
RETURNS text
LANGUAGE sql IMMUTABLE SET search_path TO ''
AS $function$
  SELECT CASE p_kind
    WHEN 'access' THEN 'data access'
    WHEN 'correction' THEN 'correction'
    WHEN 'erasure' THEN 'erasure'
    WHEN 'withdrawal' THEN 'consent withdrawal'
    WHEN 'nomination' THEN 'nomination'
    WHEN 'grievance' THEN 'grievance'
    ELSE coalesce(p_kind, 'privacy') END;
$function$;
REVOKE ALL ON FUNCTION private.privacy_kind_label(text) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Privacy-rights requests
-- ---------------------------------------------------------------------------

-- Member emails about a request. Separate from private.account_emails so the
-- account-email worker that is live now never picks these up and renders
-- them as a deletion notice; only the updated worker claims them.
CREATE TABLE private.privacy_request_emails (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.privacy_requests(id) ON DELETE CASCADE,
  event text NOT NULL CHECK (event IN ('received', 'resolved')),
  created_at timestamptz NOT NULL DEFAULT now(),
  claimed_at timestamptz,
  attempts smallint NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  sent_at timestamptz,
  last_error text,
  UNIQUE (request_id, event)
);
CREATE INDEX privacy_request_emails_unsent ON private.privacy_request_emails(created_at)
  WHERE sent_at IS NULL;
ALTER TABLE private.privacy_request_emails ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.privacy_request_emails FROM PUBLIC, anon, authenticated;

-- Which staff reminders went out, so each fires once per request.
CREATE TABLE private.privacy_request_reminders (
  request_id uuid PRIMARY KEY REFERENCES public.privacy_requests(id) ON DELETE CASCADE,
  due_soon_at timestamptz,
  overdue_at timestamptz
);
ALTER TABLE private.privacy_request_reminders ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.privacy_request_reminders FROM PUBLIC, anon, authenticated;

CREATE FUNCTION private.on_privacy_request_created()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  -- No member details in the alert: staff read them on /privacy.
  PERFORM private.notify_staff(
    'privacy_request_received',
    format('New %s request (reference %s). Answer by %s.',
           private.privacy_kind_label(NEW.kind), NEW.id, private.ist(NEW.due_at)),
    NEW.user_id,
    'privacy_request_received');
  INSERT INTO private.privacy_request_emails(request_id, event) VALUES (NEW.id, 'received')
  ON CONFLICT DO NOTHING;
  PERFORM private.invoke_edge_worker('account-email', 'account_email_worker');
  RETURN NULL;
END;
$function$;
REVOKE ALL ON FUNCTION private.on_privacy_request_created() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER trg_privacy_request_created AFTER INSERT ON public.privacy_requests
FOR EACH ROW EXECUTE FUNCTION private.on_privacy_request_created();

CREATE FUNCTION private.on_privacy_request_resolved()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF NEW.status = 'resolved' AND OLD.status IS DISTINCT FROM 'resolved' AND NEW.user_id IS NOT NULL THEN
    INSERT INTO private.privacy_request_emails(request_id, event) VALUES (NEW.id, 'resolved')
    ON CONFLICT DO NOTHING;
    PERFORM private.invoke_edge_worker('account-email', 'account_email_worker');
  END IF;
  RETURN NULL;
END;
$function$;
REVOKE ALL ON FUNCTION private.on_privacy_request_resolved() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER trg_privacy_request_resolved AFTER UPDATE OF status ON public.privacy_requests
FOR EACH ROW EXECUTE FUNCTION private.on_privacy_request_resolved();

CREATE FUNCTION public.claim_privacy_request_emails(p_limit integer DEFAULT 10)
RETURNS TABLE(
  email_id uuid, email_event text, recipient text, first_name text,
  request_id uuid, request_kind text, due_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH candidates AS (
    SELECT e.id FROM private.privacy_request_emails e
    WHERE e.sent_at IS NULL AND e.attempts < 6
      AND (e.claimed_at IS NULL OR e.claimed_at < now() - interval '5 minutes')
    ORDER BY e.created_at
    LIMIT least(greatest(coalesce(p_limit, 10), 1), 25)
    FOR UPDATE SKIP LOCKED
  ), claimed AS (
    UPDATE private.privacy_request_emails e
    SET claimed_at = now(), attempts = e.attempts + 1
    FROM candidates c WHERE e.id = c.id
    RETURNING e.id, e.event, e.request_id
  )
  SELECT c.id, c.event,
         (SELECT lower(a.email) FROM auth.users a WHERE a.id = r.user_id),
         (SELECT p.first_name FROM public.profiles p WHERE p.user_id = r.user_id LIMIT 1),
         r.id, r.kind, r.due_at
  FROM claimed c JOIN public.privacy_requests r ON r.id = c.request_id;
END;
$function$;

CREATE FUNCTION public.complete_privacy_request_email(p_email_id uuid, p_success boolean, p_error text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  UPDATE private.privacy_request_emails
  SET sent_at = CASE WHEN p_success THEN now() ELSE NULL END,
      claimed_at = NULL,
      last_error = CASE WHEN p_success THEN NULL ELSE left(p_error, 200) END
  WHERE id = p_email_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.claim_privacy_request_emails(integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_privacy_request_email(uuid, boolean, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_privacy_request_emails(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_privacy_request_email(uuid, boolean, text) TO service_role;

-- Requests still open from before this migration were never announced:
-- one inbox item each (no email, no member mail: they were filed earlier).
INSERT INTO public.admin_notifications(type, message, related_user_id)
SELECT 'privacy_request_received',
       format('Open %s request from before staff alerts existed (reference %s). Answer by %s.',
              private.privacy_kind_label(pr.kind), pr.id, private.ist(pr.due_at)),
       pr.user_id
FROM public.privacy_requests pr
WHERE pr.status <> 'resolved';

-- The hourly retry (297) also covers privacy emails.
CREATE OR REPLACE FUNCTION private.retry_account_emails()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF EXISTS (
    SELECT 1 FROM private.account_emails e
    WHERE e.sent_at IS NULL AND e.attempts < 6
      AND e.created_at < now() - interval '10 minutes'
      AND (e.claimed_at IS NULL OR e.claimed_at < now() - interval '5 minutes')
      AND (e.event <> 'deletion_completed' OR NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = e.user_id))
  ) OR EXISTS (
    -- 340
    SELECT 1 FROM private.privacy_request_emails e
    WHERE e.sent_at IS NULL AND e.attempts < 6
      AND e.created_at < now() - interval '10 minutes'
      AND (e.claimed_at IS NULL OR e.claimed_at < now() - interval '5 minutes')
  ) THEN
    PERFORM private.invoke_edge_worker('account-email', 'account_email_worker');
  END IF;
  UPDATE private.account_emails SET recipient_email = NULL
  WHERE recipient_email IS NOT NULL AND created_at < now() - interval '45 days';
  DELETE FROM private.account_emails WHERE created_at < now() - interval '90 days';
  DELETE FROM private.privacy_request_emails WHERE created_at < now() - interval '90 days';
END;
$function$;

-- Staff decisions on a request (262) and legal holds (263), unchanged except
-- for the admin audit log entry ("340:").
CREATE OR REPLACE FUNCTION public.review_privacy_request(p_id uuid, p_status text, p_response text, p_expected_updated_at timestamptz)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_before public.privacy_requests%ROWTYPE;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','support']) THEN RAISE EXCEPTION 'privacy_staff_required'; END IF;
  IF p_status IS NULL OR p_status NOT IN ('reviewing','resolved') OR p_response IS NULL
    OR char_length(trim(p_response)) NOT BETWEEN 10 AND 2000 THEN RAISE EXCEPTION 'response_required'; END IF;
  SELECT * INTO v_before FROM public.privacy_requests WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'privacy_request_missing'; END IF;
  -- Repeating the exact completed action is harmless, including a network retry.
  IF v_before.status = p_status AND v_before.response = trim(p_response) THEN RETURN; END IF;
  IF p_expected_updated_at IS NULL OR v_before.updated_at <> p_expected_updated_at THEN RAISE EXCEPTION 'privacy_request_changed_reload'; END IF;
  IF v_before.status = 'resolved' THEN RAISE EXCEPTION 'privacy_request_already_resolved'; END IF;
  UPDATE public.privacy_requests SET status = p_status, response = trim(p_response), updated_at = clock_timestamp(),
    resolved_at = CASE WHEN p_status = 'resolved' THEN now() ELSE NULL END WHERE id = p_id;
  INSERT INTO private.privacy_request_events(request_id, actor_id, from_status, to_status)
  VALUES (p_id, auth.uid(), v_before.status, p_status);
  -- 340: the response text stays on the request; the log records the decision.
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(), 'privacy_request_reviewed', v_before.user_id,
          jsonb_build_object('request_id', p_id, 'kind', v_before.kind,
                             'from', v_before.status, 'to', p_status,
                             'late', now() > v_before.due_at));
END;
$$;

CREATE OR REPLACE FUNCTION public.set_privacy_request_hold(p_id uuid, p_until timestamptz, p_reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_old private.privacy_request_holds%ROWTYPE;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN RAISE EXCEPTION 'privacy_super_admin_required'; END IF;
  IF p_reason IS NULL OR char_length(trim(p_reason)) NOT BETWEEN 10 AND 500
    OR (p_until IS NOT NULL AND (p_until <= now() OR p_until > now() + interval '1 year')) THEN
    RAISE EXCEPTION 'invalid_privacy_hold';
  END IF;
  PERFORM 1 FROM public.privacy_requests WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'privacy_request_missing'; END IF;
  SELECT * INTO v_old FROM private.privacy_request_holds WHERE request_id = p_id;
  IF p_until IS NULL AND NOT FOUND THEN RETURN; END IF;
  IF p_until IS NOT NULL AND v_old.hold_until = p_until AND v_old.reason = trim(p_reason) THEN RETURN; END IF;
  IF p_until IS NULL THEN
    DELETE FROM private.privacy_request_holds WHERE request_id = p_id;
  ELSE
    INSERT INTO private.privacy_request_holds(request_id, hold_until, reason, updated_by)
    VALUES (p_id, p_until, trim(p_reason), auth.uid())
    ON CONFLICT (request_id) DO UPDATE SET hold_until = EXCLUDED.hold_until,
      reason = EXCLUDED.reason, updated_by = EXCLUDED.updated_by, updated_at = clock_timestamp();
  END IF;
  INSERT INTO private.privacy_retention_events(request_id, actor_id, hold_until, reason)
  VALUES (p_id, auth.uid(), p_until, trim(p_reason));
  -- 340
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(),
          CASE WHEN p_until IS NULL THEN 'privacy_request_hold_released' ELSE 'privacy_request_hold_set' END,
          (SELECT r.user_id FROM public.privacy_requests r WHERE r.id = p_id),
          jsonb_build_object('request_id', p_id, 'hold_until', p_until, 'reason', left(trim(p_reason), 500)));
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. Inbox items for single events
-- ---------------------------------------------------------------------------

-- submit_user_report already files a generic "member report" item; a
-- harassing-calls report gets its own so it stands out.
CREATE FUNCTION private.notify_staff_harassing_calls_report()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  PERFORM private.notify_staff('harassing_calls_report',
    'A member reported harassing calls. Their live calls were ended; the calls between them are on the review page.',
    NEW.reported_user_id);
  RETURN NULL;
END;
$function$;
REVOKE ALL ON FUNCTION private.notify_staff_harassing_calls_report() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER trg_notify_staff_harassing_calls AFTER INSERT ON public.reports
FOR EACH ROW WHEN (NEW.reason = 'harassing_calls')
EXECUTE FUNCTION private.notify_staff_harassing_calls_report();

-- A member asked in the app to delete their account (staff and email
-- requests are recorded by staff, so they are already known).
CREATE FUNCTION private.notify_staff_member_deletion()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF NEW.deletion_status = 'pending_deletion' AND OLD.deletion_status IS DISTINCT FROM 'pending_deletion'
     AND coalesce(NEW.deletion_source, 'member') = 'member' THEN
    PERFORM private.notify_staff('account_deletion_requested',
      format('A member asked to delete their account. It is purged on %s unless they sign in again.',
             private.ist(coalesce(NEW.deleted_at, now()) + interval '30 days')),
      NEW.id);
  END IF;
  RETURN NULL;
END;
$function$;
REVOKE ALL ON FUNCTION private.notify_staff_member_deletion() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER trg_notify_staff_member_deletion AFTER UPDATE OF deletion_status ON public.users
FOR EACH ROW EXECUTE FUNCTION private.notify_staff_member_deletion();

CREATE FUNCTION private.notify_staff_subscription_refund()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  PERFORM private.notify_staff('subscription_refunded',
    format('A Premium purchase (%s) was refunded through Google Play; Premium ended.', coalesce(NEW.product_id, 'unknown plan')),
    NEW.user_id);
  RETURN NULL;
END;
$function$;
REVOKE ALL ON FUNCTION private.notify_staff_subscription_refund() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER trg_notify_staff_subscription_refund AFTER INSERT ON public.subscription_events
FOR EACH ROW WHEN (NEW.event_type = 'REFUND')
EXECUTE FUNCTION private.notify_staff_subscription_refund();

CREATE FUNCTION private.notify_staff_pack_refund()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_balance integer;
BEGIN
  SELECT w.pack_minutes INTO v_balance FROM private.call_wallets w WHERE w.user_id = NEW.user_id;
  PERFORM private.notify_staff('call_pack_refunded',
    format('A minute pack (%s, %s minutes) was refunded. Pack balance now %s%s.',
           coalesce(NEW.product_id, 'pack'), abs(NEW.pack_minutes_delta), coalesce(v_balance, 0),
           CASE WHEN coalesce(v_balance, 0) < 0 THEN ': below zero, calling is blocked until they top up' ELSE '' END),
    NEW.user_id);
  RETURN NULL;
END;
$function$;
REVOKE ALL ON FUNCTION private.notify_staff_pack_refund() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER trg_notify_staff_pack_refund AFTER INSERT ON private.call_ledger
FOR EACH ROW WHEN (NEW.kind = 'pack_refund')
EXECUTE FUNCTION private.notify_staff_pack_refund();

-- ---------------------------------------------------------------------------
-- 4. Deadlines and failures, every 15 minutes
-- ---------------------------------------------------------------------------

CREATE FUNCTION private.capture_staff_deadline_alerts()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  r record;
  v_n bigint;
  v_m bigint;
  v_names text;
  v_max_run bigint;
BEGIN
  -- Privacy requests: once at 2 days before due, once when overdue.
  FOR r IN
    SELECT pr.id, pr.kind, pr.due_at, pr.user_id
    FROM public.privacy_requests pr
    LEFT JOIN private.privacy_request_reminders m ON m.request_id = pr.id
    WHERE pr.status <> 'resolved' AND pr.due_at > now() AND pr.due_at <= now() + interval '2 days'
      AND m.due_soon_at IS NULL
    ORDER BY pr.due_at LIMIT 50
  LOOP
    PERFORM private.notify_staff('privacy_request_due_soon',
      format('A %s request (reference %s) is due %s and is not answered yet.',
             private.privacy_kind_label(r.kind), r.id, private.ist(r.due_at)),
      r.user_id, 'privacy_request_due_soon');
    INSERT INTO private.privacy_request_reminders(request_id, due_soon_at) VALUES (r.id, now())
    ON CONFLICT (request_id) DO UPDATE SET due_soon_at = now();
  END LOOP;
  FOR r IN
    SELECT pr.id, pr.kind, pr.due_at, pr.user_id
    FROM public.privacy_requests pr
    LEFT JOIN private.privacy_request_reminders m ON m.request_id = pr.id
    WHERE pr.status <> 'resolved' AND pr.due_at <= now() AND m.overdue_at IS NULL
    ORDER BY pr.due_at LIMIT 50
  LOOP
    PERFORM private.notify_staff('privacy_request_overdue',
      format('OVERDUE: a %s request (reference %s) was due %s. Answer it today.',
             private.privacy_kind_label(r.kind), r.id, private.ist(r.due_at)),
      r.user_id, 'privacy_request_overdue');
    INSERT INTO private.privacy_request_reminders(request_id, due_soon_at, overdue_at) VALUES (r.id, now(), now())
    ON CONFLICT (request_id) DO UPDATE SET overdue_at = now(),
      due_soon_at = coalesce(private.privacy_request_reminders.due_soon_at, now());
  END LOOP;

  -- Photo checks: members are promised a decision within 48 hours.
  SELECT count(*) FILTER (WHERE s.review_deadline < now() + interval '12 hours'),
         count(*) FILTER (WHERE s.review_deadline < now())
  INTO v_n, v_m
  FROM public.photo_verification_submissions s
  WHERE s.status = 'pending' AND s.reviewed_at IS NULL;
  PERFORM private.set_operational_alert('photo_checks_due',
    format('%s photo %s due within 12 hours (%s past the 48-hour promise). Open Photo checks.',
           v_n, CASE WHEN v_n = 1 THEN 'check is' ELSE 'checks are' END, v_m),
    v_n, v_n > 0);

  -- Reports waiting more than a day.
  SELECT count(*), count(*) FILTER (WHERE rp.reason IN ('harassing_calls', 'harassment', 'underage', 'intimate_image'))
  INTO v_n, v_m
  FROM public.reports rp
  WHERE rp.status = 'pending' AND rp.created_at < now() - interval '24 hours';
  PERFORM private.set_operational_alert('reports_waiting_24h',
    format('%s member %s waited more than 24 hours (%s about harassment, calls, minors or intimate images). Open Moderation.',
           v_n, CASE WHEN v_n = 1 THEN 'report has' ELSE 'reports have' END, v_m),
    v_n, v_n > 0);

  -- Account purges: past the 30 days, or a purge job not finishing.
  SELECT count(*) INTO v_n FROM public.users u
  WHERE u.deletion_status = 'pending_deletion' AND u.deleted_at < now() - interval '31 days';
  PERFORM private.set_operational_alert('account_purge_overdue',
    format('%s %s past the 30-day deletion date and not purged yet. Check Deletions and the purge worker.',
           v_n, CASE WHEN v_n = 1 THEN 'account is' ELSE 'accounts are' END),
    v_n, v_n > 0);
  SELECT count(*) INTO v_n FROM private.account_purge_jobs j
  WHERE j.completed_at IS NULL AND j.created_at < now() - interval '1 day';
  PERFORM private.set_operational_alert('account_purge_stuck',
    format('%s account %s not finished after a day. See Deletions for the error.',
           v_n, CASE WHEN v_n = 1 THEN 'purge has' ELSE 'purges have' END),
    v_n, v_n > 0);

  -- Member emails (deletion notices, privacy replies) not going out.
  SELECT (SELECT count(*) FROM private.account_emails e
          WHERE e.sent_at IS NULL AND (e.attempts >= 6 OR e.created_at < now() - interval '6 hours')
            AND (e.event <> 'deletion_completed' OR NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = e.user_id)))
       + (SELECT count(*) FROM private.privacy_request_emails e
          WHERE e.sent_at IS NULL AND (e.attempts >= 6 OR e.created_at < now() - interval '6 hours'))
  INTO v_n;
  PERFORM private.set_operational_alert('member_emails_failing',
    format('%s account or privacy %s to members not sent after 6 hours. Check the Brevo key and the account-email function.',
           v_n, CASE WHEN v_n = 1 THEN 'email is' ELSE 'emails are' END),
    v_n, v_n > 0);

  -- Staff alert emails themselves not going out (the inbox still works).
  SELECT count(*) INTO v_n FROM private.staff_alert_emails e
  WHERE e.sent_at IS NULL AND (e.attempts >= 5 OR e.created_at < now() - interval '6 hours');
  PERFORM private.set_operational_alert('staff_alert_emails_failing',
    format('%s staff alert %s not sent by email. Rely on this inbox and check the staff-alert-email function.',
           v_n, CASE WHEN v_n = 1 THEN 'email was' ELSE 'emails were' END),
    v_n, v_n > 0);

  -- Scheduled jobs that failed in the last 24 hours (pg_cron and guarded
  -- runs). Only the newest runs are read so this stays cheap.
  SELECT max(d.runid) INTO v_max_run FROM cron.job_run_details d;
  SELECT count(*), string_agg(DISTINCT x.name, ', ')
  INTO v_n, v_names
  FROM (
    SELECT coalesce(j.jobname, 'removed job ' || d.jobid) AS name
    FROM cron.job_run_details d LEFT JOIN cron.job j ON j.jobid = d.jobid
    WHERE d.runid > coalesce(v_max_run, 0) - 30000 AND d.status = 'failed'
      AND d.start_time > now() - interval '24 hours'
    UNION ALL
    SELECT jr.job_name FROM private.job_runs jr
    WHERE jr.status = 'failed' AND jr.started_at > now() - interval '24 hours'
  ) x;
  PERFORM private.set_operational_alert('scheduled_jobs_failing',
    format('Scheduled jobs failed %s %s in the last 24 hours: %s. See System health.',
           v_n, CASE WHEN v_n = 1 THEN 'time' ELSE 'times' END, left(coalesce(v_names, ''), 400)),
    v_n, v_n > 0);

  -- A minute-pack refund whose purchase never arrived.
  SELECT count(*) INTO v_n FROM private.call_pack_pending_refunds pr
  WHERE pr.applied_at IS NULL AND pr.reversed_at IS NULL AND pr.received_at < now() - interval '1 day';
  PERFORM private.set_operational_alert('call_pack_refunds_waiting',
    format('%s minute-pack %s waited over a day for the purchase to arrive. Check the order in Play Console.',
           v_n, CASE WHEN v_n = 1 THEN 'refund has' ELSE 'refunds have' END),
    v_n, v_n > 0);
END;
$function$;
REVOKE ALL ON FUNCTION private.capture_staff_deadline_alerts() FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. Schedules
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF to_regclass('cron.job') IS NULL THEN RETURN; END IF;
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'staff_deadline_alerts_15m';
  PERFORM cron.schedule('staff_deadline_alerts_15m', '7-59/15 * * * *',
    $cmd$SELECT private.run_guarded_sql('staff_deadline_alerts_15m', 'SELECT private.capture_staff_deadline_alerts()', 120);$cmd$);
  -- 4. The daily purge of accounts past their 30 days, through the same
  -- Vault-backed helper as every other worker. Same job id, so its run
  -- history stays attached.
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'trigger_purge_deleted_accounts') THEN
    PERFORM cron.alter_job(
      job_id := (SELECT jobid FROM cron.job WHERE jobname = 'trigger_purge_deleted_accounts'),
      schedule := '15 3 * * *',
      command := $cmd$SELECT private.invoke_edge_worker('admin-purge-deleted-users', 'account_purge_worker');$cmd$);
  ELSE
    PERFORM cron.schedule('trigger_purge_deleted_accounts', '15 3 * * *',
      $cmd$SELECT private.invoke_edge_worker('admin-purge-deleted-users', 'account_purge_worker');$cmd$);
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 6. Scheduled jobs for System health
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.admin_scheduled_jobs()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_max_run bigint;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator', 'support']) THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  SELECT max(d.runid) INTO v_max_run FROM cron.job_run_details d;
  RETURN jsonb_build_object(
    'jobs', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'name', j.jobname, 'schedule', j.schedule, 'active', j.active,
        'last_run_at', last.start_time, 'last_status', last.status,
        -- First line only: the DETAIL lines can echo the failing row, which
        -- for HTTP jobs includes request headers.
        'last_error', left(CASE WHEN last.status = 'failed' THEN split_part(last.return_message, E'\n', 1) END, 200),
        'failures_24h', coalesce(f.n, 0)
      ) ORDER BY coalesce(f.n, 0) DESC, j.jobname)
      FROM cron.job j
      LEFT JOIN LATERAL (
        SELECT d.start_time, d.status, d.return_message FROM cron.job_run_details d
        WHERE d.jobid = j.jobid AND d.runid > coalesce(v_max_run, 0) - 30000
        ORDER BY d.runid DESC LIMIT 1
      ) last ON true
      LEFT JOIN LATERAL (
        SELECT count(*) AS n FROM cron.job_run_details d
        WHERE d.jobid = j.jobid AND d.runid > coalesce(v_max_run, 0) - 30000
          AND d.status = 'failed' AND d.start_time > now() - interval '24 hours'
      ) f ON true
    ), '[]'::jsonb),
    'active_alerts', coalesce((
      SELECT jsonb_agg(jsonb_build_object('key', s.alert_key, 'value', s.last_value,
                                          'since', s.last_alerted_at) ORDER BY s.alert_key)
      FROM private.operational_alert_state s WHERE s.is_active
    ), '[]'::jsonb)
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.admin_scheduled_jobs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_scheduled_jobs() TO authenticated;

NOTIFY pgrst, 'reload schema';
