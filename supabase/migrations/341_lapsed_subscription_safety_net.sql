-- A subscription whose end date passed without the store's final update
-- stayed "active" forever. Members already lose Premium at
-- subscription_expires_at (has_active_premium checks it), but the bare
-- status also drives the "subscribers" campaign audience, the subscription
-- summary, the dashboard metrics and the member page.
--
-- Seen on production 28 Nov 2026: license-tester (SANDBOX) purchases from
-- 21 Nov whose EXPIRATION was rejected after REVENUECAT_SANDBOX_TESTER_IDS
-- was removed. The same would happen for a real member if a webhook were
-- lost, so: one day after the end date with no newer store event, the status
-- becomes 'none' and staff get an inbox item (a lost webhook is worth a look).
-- It runs inside the existing 15-minute staff check (340), no new job.

CREATE FUNCTION private.reconcile_lapsed_subscriptions()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  r record;
  v_n integer := 0;
BEGIN
  FOR r IN
    SELECT u.id, u.subscription_status, u.subscription_expires_at
    FROM public.users u
    WHERE u.subscription_status IN ('active', 'grace')
      AND u.subscription_expires_at < now() - interval '1 day'
      -- Nothing from the store since the end date (a late renewal or a
      -- billing-grace update would be newer).
      AND NOT EXISTS (
        SELECT 1 FROM public.subscription_events e
        WHERE e.user_id = u.id AND e.created_at > u.subscription_expires_at)
    ORDER BY u.subscription_expires_at
    LIMIT 200
    FOR UPDATE OF u SKIP LOCKED
  LOOP
    UPDATE public.users SET subscription_status = 'none' WHERE id = r.id;
    PERFORM private.notify_staff('subscription_lapsed_without_store_update',
      format('Premium ended %s but the store never sent its final update, so it is now marked ended (was %s). '
             'If the member says they still pay, check them in RevenueCat.',
             private.ist(r.subscription_expires_at), r.subscription_status),
      r.id);
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END;
$function$;
REVOKE ALL ON FUNCTION private.reconcile_lapsed_subscriptions() FROM PUBLIC, anon, authenticated;

-- The 15-minute staff check runs the safety net first, then the alerts.
DO $$
BEGIN
  IF to_regclass('cron.job') IS NULL THEN RETURN; END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'staff_deadline_alerts_15m') THEN
    PERFORM cron.alter_job(
      job_id := (SELECT jobid FROM cron.job WHERE jobname = 'staff_deadline_alerts_15m'),
      command := $cmd$SELECT private.run_guarded_sql('staff_deadline_alerts_15m', 'SELECT private.reconcile_lapsed_subscriptions(), private.capture_staff_deadline_alerts()', 120);$cmd$);
  END IF;
END $$;
