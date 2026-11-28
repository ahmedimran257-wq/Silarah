-- Rollback test for migration 341 (lapsed subscription safety net). STAGING first:
--   (echo 'BEGIN;'; cat supabase/migrations/341_lapsed_subscription_safety_net.sql; cat this file) > t.sql   # if 341 is not applied
-- One transaction ending in ROLLBACK; the last SELECT prints one row per rule.
BEGIN;

CREATE TEMP TABLE t_results (n serial, name text, ok boolean, detail text) ON COMMIT DROP;
CREATE FUNCTION pg_temp.ok(p_name text, p_ok boolean, p_detail text DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO t_results(name, ok, detail) VALUES (p_name, coalesce(p_ok, false), p_detail);
$$;

CREATE FUNCTION pg_temp.member(p_id uuid, p_status text, p_expires timestamptz)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO auth.users(id, aud, role, email, email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data)
  VALUES (p_id, 'authenticated', 'authenticated',
    'vcqa.' || right(p_id::text, 4) || '@gmail.com', now(), now(), now(), '{}', '{}');
  INSERT INTO public.users(id, email, gender, country_code, timezone, subscription_status, subscription_expires_at)
  VALUES (p_id, 'vcqa.' || right(p_id::text, 4) || '@gmail.com', 'male', 'IN', 'Asia/Kolkata', p_status, p_expires);
END $$;

DO $$
DECLARE
  lapsed uuid := gen_random_uuid();
  grace uuid := gen_random_uuid();
  recent uuid := gen_random_uuid();
  renewed uuid := gen_random_uuid();
  live uuid := gen_random_uuid();
  n integer;
BEGIN
  PERFORM pg_temp.member(lapsed, 'active', now() - interval '3 days');
  PERFORM pg_temp.member(grace, 'grace', now() - interval '2 days');
  PERFORM pg_temp.member(recent, 'active', now() - interval '3 hours');
  PERFORM pg_temp.member(renewed, 'active', now() - interval '3 days');
  PERFORM pg_temp.member(live, 'active', now() + interval '20 days');
  -- A store event after the end date: the webhook is still working on it.
  INSERT INTO public.subscription_events(user_id, event_type, event_timestamp_ms, product_id, created_at)
  VALUES (renewed, 'BILLING_ISSUE', (extract(epoch FROM now()) * 1000)::bigint, 'silarah_monthly:monthly', now());

  n := private.reconcile_lapsed_subscriptions();
  PERFORM pg_temp.ok('a subscription a day past its end with no store update is ended',
    (SELECT subscription_status FROM public.users WHERE id = lapsed) = 'none', NULL);
  PERFORM pg_temp.ok('a lapsed billing grace is ended too',
    (SELECT subscription_status FROM public.users WHERE id = grace) = 'none', NULL);
  PERFORM pg_temp.ok('less than a day past the end date is left for the webhook',
    (SELECT subscription_status FROM public.users WHERE id = recent) = 'active', NULL);
  PERFORM pg_temp.ok('a newer store event leaves it for the webhook',
    (SELECT subscription_status FROM public.users WHERE id = renewed) = 'active', NULL);
  PERFORM pg_temp.ok('a running subscription is untouched',
    (SELECT subscription_status FROM public.users WHERE id = live) = 'active', NULL);
  PERFORM pg_temp.ok('the expiry date is kept',
    (SELECT subscription_expires_at < now() - interval '2 days' FROM public.users WHERE id = lapsed), NULL);
  PERFORM pg_temp.ok('staff get one inbox item per ended subscription',
    (SELECT count(*) FROM public.admin_notifications
     WHERE type = 'subscription_lapsed_without_store_update' AND related_user_id IN (lapsed, grace)) = 2
    AND NOT EXISTS (SELECT 1 FROM public.admin_notifications
                    WHERE type = 'subscription_lapsed_without_store_update' AND related_user_id IN (recent, renewed, live)),
    NULL);
  PERFORM pg_temp.ok('the count returned matches', n >= 2, n::text);
  PERFORM pg_temp.ok('no store event is invented',
    NOT EXISTS (SELECT 1 FROM public.subscription_events WHERE user_id IN (lapsed, grace)), NULL);
  n := private.reconcile_lapsed_subscriptions();
  PERFORM pg_temp.ok('a second run changes nothing for them',
    (SELECT count(*) FROM public.admin_notifications
     WHERE type = 'subscription_lapsed_without_store_update' AND related_user_id IN (lapsed, grace)) = 2, NULL);
  PERFORM pg_temp.ok('the 15-minute check runs the safety net first',
    (SELECT command LIKE '%reconcile_lapsed_subscriptions(), private.capture_staff_deadline_alerts()%'
     FROM cron.job WHERE jobname = 'staff_deadline_alerts_15m'), NULL);
END $$;

SELECT n, ok, name, detail FROM t_results ORDER BY n;
ROLLBACK;
