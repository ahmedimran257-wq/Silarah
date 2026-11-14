-- Account deletion becomes visible and actionable for staff, and members are
-- told by email when deletion is requested, cancelled and completed.
-- Staff can also give testers temporary Premium from the console.

-- 1. Account emails ----------------------------------------------------------
-- No foreign key: the completion notice must outlive the member it is about.
-- The address is stored only for that notice and is erased once it is sent.
CREATE TABLE IF NOT EXISTS private.account_emails (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  event text NOT NULL CHECK (event IN (
    'deletion_requested', 'deletion_cancelled', 'deletion_completed'
  )),
  recipient_email text,
  purge_after timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  claimed_at timestamptz,
  attempts smallint NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  sent_at timestamptz,
  last_error text
);
ALTER TABLE private.account_emails ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.account_emails FROM PUBLIC, anon, authenticated;
CREATE INDEX IF NOT EXISTS account_emails_unsent
  ON private.account_emails (created_at) WHERE sent_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS account_emails_one_completion
  ON private.account_emails (user_id) WHERE event = 'deletion_completed';

CREATE OR REPLACE FUNCTION private.queue_account_deletion_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  IF NEW.deletion_status = 'pending_deletion'
     AND OLD.deletion_status IS DISTINCT FROM 'pending_deletion' THEN
    INSERT INTO private.account_emails(user_id, event, purge_after)
    VALUES (NEW.id, 'deletion_requested',
            coalesce(NEW.deleted_at, now()) + interval '30 days');
    PERFORM private.invoke_edge_worker('account-email', 'account_email_worker');
  ELSIF OLD.deletion_status = 'pending_deletion'
     AND NEW.deletion_status = 'active' THEN
    INSERT INTO private.account_emails(user_id, event)
    VALUES (NEW.id, 'deletion_cancelled');
    PERFORM private.invoke_edge_worker('account-email', 'account_email_worker');
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_queue_account_deletion_email ON public.users;
CREATE TRIGGER trg_queue_account_deletion_email
  AFTER UPDATE OF deletion_status ON public.users
  FOR EACH ROW EXECUTE FUNCTION private.queue_account_deletion_email();

-- The purge removes the sign-in account after storage. Capture the address
-- for the final notice just before that, and send it once the purge is done.
CREATE OR REPLACE FUNCTION private.capture_account_completion_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  IF NEW.phase = 'auth' AND OLD.phase IS DISTINCT FROM 'auth' THEN
    INSERT INTO private.account_emails(user_id, event, recipient_email)
    SELECT NEW.user_id, 'deletion_completed', lower(a.email)
    FROM auth.users a
    WHERE a.id = NEW.user_id AND nullif(trim(a.email), '') IS NOT NULL
    ON CONFLICT (user_id) WHERE event = 'deletion_completed' DO NOTHING;
  ELSIF NEW.phase = 'completed' AND OLD.phase IS DISTINCT FROM 'completed' THEN
    PERFORM private.invoke_edge_worker('account-email', 'account_email_worker');
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_capture_account_completion_email
  ON private.account_purge_jobs;
CREATE TRIGGER trg_capture_account_completion_email
  AFTER UPDATE OF phase ON private.account_purge_jobs
  FOR EACH ROW EXECUTE FUNCTION private.capture_account_completion_email();

CREATE OR REPLACE FUNCTION public.claim_account_emails(p_limit integer DEFAULT 10)
RETURNS TABLE(
  email_id uuid,
  email_event text,
  recipient text,
  purge_after_at timestamptz,
  first_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH candidates AS (
    SELECT e.id
    FROM private.account_emails e
    WHERE e.sent_at IS NULL
      AND e.attempts < 6
      AND (e.claimed_at IS NULL OR e.claimed_at < now() - interval '5 minutes')
      -- The completion notice waits until the member's data is really gone.
      AND (e.event <> 'deletion_completed'
           OR NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = e.user_id))
    ORDER BY e.created_at
    LIMIT least(greatest(p_limit, 1), 25)
    FOR UPDATE SKIP LOCKED
  ), claimed AS (
    UPDATE private.account_emails e
    SET claimed_at = now(), attempts = e.attempts + 1
    FROM candidates c
    WHERE e.id = c.id
    RETURNING e.id, e.event, e.user_id, e.recipient_email, e.purge_after
  )
  SELECT c.id,
         c.event,
         coalesce(c.recipient_email,
                  (SELECT lower(a.email) FROM auth.users a WHERE a.id = c.user_id)),
         c.purge_after,
         (SELECT p.first_name FROM public.profiles p WHERE p.user_id = c.user_id LIMIT 1)
  FROM claimed c;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_account_email(
  p_email_id uuid,
  p_success boolean,
  p_error text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  UPDATE private.account_emails
  SET sent_at = CASE WHEN p_success THEN now() ELSE NULL END,
      claimed_at = NULL,
      last_error = CASE WHEN p_success THEN NULL ELSE left(p_error, 200) END,
      -- A sent completion notice was the only reason to keep the address.
      recipient_email = CASE WHEN p_success OR attempts >= 6
                             THEN NULL ELSE recipient_email END
  WHERE id = p_email_id;
END;
$$;

CREATE OR REPLACE FUNCTION private.retry_account_emails()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM private.account_emails e
    WHERE e.sent_at IS NULL AND e.attempts < 6
      AND e.created_at < now() - interval '10 minutes'
      AND (e.claimed_at IS NULL OR e.claimed_at < now() - interval '5 minutes')
      AND (e.event <> 'deletion_completed'
           OR NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = e.user_id))
  ) THEN
    PERFORM private.invoke_edge_worker('account-email', 'account_email_worker');
  END IF;
  UPDATE private.account_emails SET recipient_email = NULL
  WHERE recipient_email IS NOT NULL AND created_at < now() - interval '45 days';
  DELETE FROM private.account_emails
  WHERE created_at < now() - interval '90 days';
END;
$$;

REVOKE ALL ON FUNCTION public.claim_account_emails(integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_account_email(uuid, boolean, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_account_emails(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_account_email(uuid, boolean, text) TO service_role;
REVOKE ALL ON FUNCTION private.queue_account_deletion_email() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.capture_account_completion_email() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.retry_account_emails() FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'retry_account_emails_hourly';
  PERFORM cron.schedule('retry_account_emails_hourly', '29 * * * *',
                        'SELECT private.retry_account_emails();');
END;
$$;

-- 2. Staff: deletion queue and actions -------------------------------------
CREATE OR REPLACE FUNCTION public.admin_account_deletions(p_limit integer DEFAULT 100)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_pending jsonb;
  v_stuck jsonb;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'support']) THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  SELECT coalesce(jsonb_agg(row_data ORDER BY (row_data->>'purgeAfter')), '[]'::jsonb)
  INTO v_pending
  FROM (
    SELECT jsonb_build_object(
      'userId', u.id,
      'email', public.mask_admin_email(u.email),
      'name', nullif(trim(concat_ws(' ', p.first_name,
                nullif(left(coalesce(p.last_name, ''), 1), '') || '.')), ''),
      'requestedAt', u.deletion_requested_at,
      'purgeAfter', u.deleted_at + interval '30 days',
      'reason', u.deletion_reason,
      'byStaff', coalesce(u.deletion_reason, '') LIKE 'Staff:%',
      'purgePhase', j.phase,
      'purgeStatus', j.status,
      'purgeAttempts', j.attempt_count,
      'purgeError', j.last_error_code
    ) AS row_data
    FROM public.users u
    LEFT JOIN public.profiles p ON p.user_id = u.id
    LEFT JOIN private.account_purge_jobs j ON j.user_id = u.id
    WHERE u.deletion_status = 'pending_deletion'
    ORDER BY u.deleted_at
    LIMIT least(greatest(p_limit, 1), 500)
  ) rows;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'userId', j.user_id, 'phase', j.phase, 'status', j.status,
           'attempts', j.attempt_count, 'error', j.last_error_code,
           'nextAttemptAt', j.next_attempt_at)), '[]'::jsonb)
  INTO v_stuck
  FROM private.account_purge_jobs j
  WHERE j.status IN ('failed', 'dead_letter');
  RETURN jsonb_build_object(
    'pending', v_pending,
    'stuck', v_stuck,
    'completedLast30Days', (
      SELECT count(*) FROM private.account_purge_jobs j
      WHERE j.status = 'completed' AND j.completed_at > now() - interval '30 days'
    ),
    'emailsWaiting', (
      SELECT count(*) FROM private.account_emails e
      WHERE e.sent_at IS NULL AND e.attempts < 6
    ),
    'emailsFailed', (
      SELECT count(*) FROM private.account_emails e
      WHERE e.sent_at IS NULL AND e.attempts >= 6
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_member_account_state(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  SELECT jsonb_build_object(
    'deletionStatus', u.deletion_status,
    'requestedAt', u.deletion_requested_at,
    'purgeAfter', CASE WHEN u.deletion_status = 'pending_deletion'
                       THEN u.deleted_at + interval '30 days' END,
    'deletionReason', u.deletion_reason,
    'purgePhase', j.phase,
    'purgeStatus', j.status,
    'canCancelDeletion', u.deletion_status = 'pending_deletion' AND j.user_id IS NULL,
    'paidStatus', u.subscription_status,
    'paidUntil', u.subscription_expires_at,
    'testPremiumUntil', (
      SELECT max(g.expires_at) FROM private.test_premium_grants g
      WHERE g.user_id = u.id AND g.revoked_at IS NULL AND g.expires_at > now()
    )
  )
  INTO v_result
  FROM public.users u
  LEFT JOIN private.account_purge_jobs j ON j.user_id = u.id
  WHERE u.id = p_user_id;
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_schedule_account_deletion(
  p_user_id uuid,
  p_reason text,
  p_immediate boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_status text;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_purge_after timestamptz;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'Super admin authorization required' USING ERRCODE = '42501';
  END IF;
  IF v_reason IS NULL OR char_length(v_reason) < 6 THEN
    RAISE EXCEPTION 'A reason of at least 6 characters is required' USING ERRCODE = '22023';
  END IF;
  SELECT deletion_status INTO v_status FROM public.users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_status = 'active' THEN
    UPDATE public.users
    SET deletion_status = 'pending_deletion',
        deletion_reason = left('Staff: ' || v_reason, 500),
        deletion_requested_at = now(),
        deleted_at = CASE WHEN p_immediate
                          THEN now() - interval '30 days 1 minute' ELSE now() END
    WHERE id = p_user_id;
  ELSIF v_status = 'pending_deletion' AND p_immediate THEN
    UPDATE public.users
    SET deleted_at = least(deleted_at, now() - interval '30 days 1 minute')
    WHERE id = p_user_id;
  ELSE
    RAISE EXCEPTION 'This account is already scheduled or removed' USING ERRCODE = 'P0001';
  END IF;
  SELECT deleted_at + interval '30 days' INTO v_purge_after FROM public.users WHERE id = p_user_id;
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(),
          CASE WHEN p_immediate THEN 'account_deletion_immediate' ELSE 'account_deletion_scheduled' END,
          p_user_id,
          jsonb_build_object('reason', v_reason, 'purge_after', v_purge_after));
  IF p_immediate THEN
    PERFORM private.invoke_edge_worker('admin-purge-deleted-users', 'account_purge_worker');
  END IF;
  RETURN jsonb_build_object('purgeAfter', v_purge_after, 'immediate', p_immediate);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_cancel_account_deletion(p_user_id uuid, p_reason text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'Super admin authorization required' USING ERRCODE = '42501';
  END IF;
  IF v_reason IS NULL OR char_length(v_reason) < 6 THEN
    RAISE EXCEPTION 'A reason of at least 6 characters is required' USING ERRCODE = '22023';
  END IF;
  PERFORM 1 FROM private.account_purge_jobs WHERE user_id = p_user_id FOR UPDATE;
  IF FOUND THEN
    -- Once the purge has started, a restore could only be partial.
    RAISE EXCEPTION 'The purge has already started and cannot be undone' USING ERRCODE = 'P0001';
  END IF;
  UPDATE public.users
  SET deletion_status = 'active', deletion_reason = NULL,
      deletion_requested_at = NULL, deleted_at = NULL
  WHERE id = p_user_id AND deletion_status = 'pending_deletion';
  IF NOT FOUND THEN
    RETURN false;
  END IF;
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(), 'account_deletion_cancelled',
          p_user_id, jsonb_build_object('reason', v_reason));
  RETURN true;
END;
$$;

-- 3. Staff: tester Premium ---------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_grant_test_premium(
  p_user_id uuid,
  p_days integer,
  p_note text DEFAULT NULL
)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_expires timestamptz;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'Super admin authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_days IS NULL OR p_days NOT BETWEEN 1 AND 7 THEN
    RAISE EXCEPTION 'Test Premium lasts 1 to 7 days; grant again to extend' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = p_user_id AND deletion_status = 'active' AND coalesce(is_banned, false) = false
  ) THEN
    RAISE EXCEPTION 'Only an active, unbanned member can receive test Premium' USING ERRCODE = 'P0001';
  END IF;
  UPDATE private.test_premium_grants SET revoked_at = now()
  WHERE user_id = p_user_id AND revoked_at IS NULL AND expires_at > now();
  INSERT INTO private.test_premium_grants(batch_id, user_id, starts_at, expires_at)
  VALUES ('device-test-staff-' || replace(gen_random_uuid()::text, '-', ''),
          p_user_id, now(), now() + make_interval(days => p_days))
  RETURNING expires_at INTO v_expires;
  PERFORM private.sync_incognito_entitlement(p_user_id);
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(), 'test_premium_granted', p_user_id,
          jsonb_build_object('days', p_days, 'expires_at', v_expires,
                             'note', nullif(trim(coalesce(p_note, '')), '')));
  RETURN v_expires;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_revoke_test_premium(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_count integer;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'Super admin authorization required' USING ERRCODE = '42501';
  END IF;
  UPDATE private.test_premium_grants SET revoked_at = now()
  WHERE user_id = p_user_id AND revoked_at IS NULL AND expires_at > now();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  PERFORM private.sync_incognito_entitlement(p_user_id);
  IF v_count > 0 THEN
    INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
    VALUES (auth.uid(), public.current_admin_role(), 'test_premium_revoked', p_user_id,
            jsonb_build_object('grants', v_count));
  END IF;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_account_deletions(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_member_account_state(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_schedule_account_deletion(uuid, text, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_cancel_account_deletion(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_grant_test_premium(uuid, integer, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_revoke_test_premium(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_account_deletions(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_member_account_state(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_schedule_account_deletion(uuid, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_cancel_account_deletion(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_grant_test_premium(uuid, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_revoke_test_premium(uuid) TO authenticated;
