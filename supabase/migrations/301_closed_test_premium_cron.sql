-- Closed test (Testers Community, started 16 Nov 2026): every tester was
-- promised free Premium within a day of signing up. This used to run as a
-- laptop task, which skips runs while the owner's laptop is off. It now runs
-- hourly in the database.
--
-- Each run gives 7-day test Premium (the most one grant allows) to every
-- account created since 16 Nov 2026 that has no grant lasting more than
-- 30 more hours, so grants renew before they run out. Staff, banned and
-- deleting accounts are skipped. It mirrors public.admin_grant_test_premium:
-- revoke the current grant, insert a new one, sync entitlements, write an
-- audit entry under the owner's super_admin account.
--
-- Temporary: after 4 Dec 2026 (the 16-day test plus buffer) the job
-- unschedules itself and grants nothing more.

CREATE OR REPLACE FUNCTION private.grant_closed_test_premium()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_owner uuid;
  v_user uuid;
  v_expires timestamptz;
  v_count integer := 0;
BEGIN
  IF now() > timestamptz '2026-12-04 18:30+00' THEN
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'closed_test_premium_hourly';
    RETURN 0;
  END IF;

  SELECT m.user_id INTO v_owner
  FROM public.admin_memberships m
  WHERE m.role = 'super_admin' AND m.status = 'active'
  ORDER BY m.created_at
  LIMIT 1;
  IF v_owner IS NULL THEN
    RETURN 0;
  END IF;

  FOR v_user IN
    SELECT u.id
    FROM public.users u
    WHERE u.created_at >= timestamptz '2026-11-16 00:00+00'
      AND u.deletion_status = 'active'
      AND coalesce(u.is_banned, false) = false
      AND NOT EXISTS (SELECT 1 FROM public.admin_memberships m
                      WHERE m.user_id = u.id AND m.status = 'active')
      AND NOT EXISTS (SELECT 1 FROM private.test_premium_grants g
                      WHERE g.user_id = u.id AND g.revoked_at IS NULL
                        AND g.expires_at > now() + interval '30 hours')
  LOOP
    UPDATE private.test_premium_grants SET revoked_at = now()
    WHERE user_id = v_user AND revoked_at IS NULL AND expires_at > now();

    INSERT INTO private.test_premium_grants(batch_id, user_id, starts_at, expires_at)
    VALUES ('device-test-closed-test-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16),
            v_user, now(), now() + interval '7 days')
    RETURNING expires_at INTO v_expires;

    PERFORM private.sync_incognito_entitlement(v_user);

    INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
    VALUES (v_owner, 'super_admin', 'test_premium_granted', v_user,
            jsonb_build_object('days', 7, 'expires_at', v_expires,
                               'note', 'Automatic: Play closed test tester'));
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION private.grant_closed_test_premium() FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'closed_test_premium_hourly';
  PERFORM cron.schedule('closed_test_premium_hourly', '17 * * * *',
                        'SELECT private.grant_closed_test_premium();');
END;
$$;
