-- Deletion requests that arrive by email (privacy@silarah.com) get a home in
-- the console. Staff enter the sender's address; only an exact match with the
-- account's registered email is accepted, which is the ownership check the
-- public deletion page promises. The queue shows where each request came from.

CREATE OR REPLACE FUNCTION public.admin_record_email_deletion_request(
  p_email text,
  p_received_at timestamptz DEFAULT NULL,
  p_note text DEFAULT NULL,
  p_immediate boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_email text := lower(trim(coalesce(p_email, '')));
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_received timestamptz := coalesce(p_received_at, now());
  v_user uuid;
  v_matches integer;
  v_status text;
  v_purge_after timestamptz;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'support']) THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_immediate AND NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'Only a super admin can delete immediately' USING ERRCODE = '42501';
  END IF;
  IF v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
    RAISE EXCEPTION 'Enter the full email address the request came from' USING ERRCODE = '22023';
  END IF;
  IF v_received > now() + interval '1 hour' OR v_received < now() - interval '90 days' THEN
    RAISE EXCEPTION 'The received date must be within the last 90 days' USING ERRCODE = '22023';
  END IF;

  SELECT count(*), min(a.id::text)::uuid INTO v_matches, v_user
  FROM auth.users a
  WHERE lower(a.email) = v_email;
  IF v_matches = 0 THEN
    RAISE EXCEPTION 'No account uses this email address. Reply asking them to write from their registered address' USING ERRCODE = 'P0002';
  END IF;
  IF v_matches > 1 THEN
    RAISE EXCEPTION 'More than one account matches this address. Escalate to a super admin' USING ERRCODE = 'P0001';
  END IF;

  SELECT deletion_status INTO v_status FROM public.users WHERE id = v_user FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No account uses this email address. Reply asking them to write from their registered address' USING ERRCODE = 'P0002';
  END IF;

  IF v_status = 'pending_deletion' AND NOT p_immediate THEN
    SELECT deleted_at + interval '30 days' INTO v_purge_after FROM public.users WHERE id = v_user;
    RETURN jsonb_build_object('status', 'already_pending', 'userId', v_user,
                              'purgeAfter', v_purge_after);
  END IF;

  IF v_status = 'active' THEN
    UPDATE public.users
    SET deletion_status = 'pending_deletion',
        deletion_reason = left('Email request: ' || coalesce(v_note, 'verified from the registered address'), 500),
        deletion_requested_at = v_received,
        deleted_at = CASE WHEN p_immediate THEN now() - interval '30 days 1 minute' ELSE now() END
    WHERE id = v_user;
  ELSIF v_status = 'pending_deletion' THEN
    UPDATE public.users
    SET deleted_at = least(deleted_at, now() - interval '30 days 1 minute')
    WHERE id = v_user;
  ELSE
    RAISE EXCEPTION 'This account is already removed' USING ERRCODE = 'P0001';
  END IF;

  SELECT deleted_at + interval '30 days' INTO v_purge_after FROM public.users WHERE id = v_user;
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(), 'account_deletion_email_request', v_user,
          jsonb_build_object('received_at', v_received, 'immediate', p_immediate,
                             'note', v_note, 'purge_after', v_purge_after));
  IF p_immediate THEN
    PERFORM private.invoke_edge_worker('admin-purge-deleted-users', 'account_purge_worker');
  END IF;
  RETURN jsonb_build_object('status', CASE WHEN p_immediate THEN 'deleting_now' ELSE 'scheduled' END,
                            'userId', v_user, 'purgeAfter', v_purge_after);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_record_email_deletion_request(text, timestamptz, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_record_email_deletion_request(text, timestamptz, text, boolean) TO authenticated;

-- The queue now says where each request came from.
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
  SELECT coalesce(jsonb_agg(row_data ORDER BY (row_data->>'purgeAfter')), '[]'::jsonb) INTO v_pending
  FROM (
    SELECT jsonb_build_object(
      'userId', u.id,
      'email', public.mask_admin_email(u.email),
      'name', nullif(trim(concat_ws(' ', p.first_name, nullif(left(coalesce(p.last_name, ''), 1), '') || '.')), ''),
      'requestedAt', u.deletion_requested_at,
      'purgeAfter', u.deleted_at + interval '30 days',
      'reason', u.deletion_reason,
      'byStaff', coalesce(u.deletion_reason, '') LIKE 'Staff:%',
      'source', CASE
        WHEN coalesce(u.deletion_reason, '') LIKE 'Email request:%' THEN 'email'
        WHEN coalesce(u.deletion_reason, '') LIKE 'Staff:%' THEN 'staff'
        ELSE 'app' END,
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
  SELECT coalesce(jsonb_agg(jsonb_build_object('userId', j.user_id, 'phase', j.phase, 'status', j.status,
           'attempts', j.attempt_count, 'error', j.last_error_code, 'nextAttemptAt', j.next_attempt_at)), '[]'::jsonb)
  INTO v_stuck FROM private.account_purge_jobs j WHERE j.status IN ('failed', 'dead_letter');
  RETURN jsonb_build_object(
    'pending', v_pending,
    'stuck', v_stuck,
    'completedLast30Days', (SELECT count(*) FROM private.account_purge_jobs j WHERE j.status = 'completed' AND j.completed_at > now() - interval '30 days'),
    'emailsWaiting', (SELECT count(*) FROM private.account_emails e WHERE e.sent_at IS NULL AND e.attempts < 6),
    'emailsFailed', (SELECT count(*) FROM private.account_emails e WHERE e.sent_at IS NULL AND e.attempts >= 6)
  );
END;
$$;
