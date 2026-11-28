-- Staff access that works end to end.
--
-- Before: "Send invite" called Supabase's inviteUserByEmail. For an address
-- that already had a Silarah account (most staff are members too) it failed
-- with "already registered", the panel added the role anyway and no email
-- was sent; for a new address the email linked to silarah.com (the admin
-- host is not an allowed redirect) and the panel had no page to set a first
-- password. There was no way to remove staff, resend an invite, reset a lost
-- authenticator, or recover a forgotten password.
--
-- Now the panel issues its own one-time links (invite 72 h, password reset
-- 1 h). Only a SHA-256 of the token is kept; the raw link sits in the email
-- queue until it is sent and is then erased. The link opens a page with a
-- Continue button (email scanners that open links cannot use it up); the
-- admin worker consumes the token, signs the person in, lets them choose a
-- password and sends them to the authenticator step. Emails go through the
-- account-email worker (Brevo), like member account emails.

-- ---------------------------------------------------------------------------
-- 1. Tokens and the email queue
-- ---------------------------------------------------------------------------

CREATE TABLE private.staff_access_tokens (
  token_hash text PRIMARY KEY CHECK (token_hash ~ '^[0-9a-f]{64}$'),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('invite', 'reset')),
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  used_at timestamptz
);
CREATE INDEX staff_access_tokens_user ON private.staff_access_tokens(user_id, created_at DESC);
ALTER TABLE private.staff_access_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.staff_access_tokens FROM PUBLIC, anon, authenticated;

CREATE TABLE private.staff_access_emails (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('invite', 'reset')),
  link text,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  claimed_at timestamptz,
  attempts smallint NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  sent_at timestamptz,
  last_error text
);
CREATE INDEX staff_access_emails_unsent ON private.staff_access_emails(created_at) WHERE sent_at IS NULL;
ALTER TABLE private.staff_access_emails ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.staff_access_emails FROM PUBLIC, anon, authenticated;

-- The admin site the link points at: production, the staging admin on
-- workers.dev, or a local dev server.
CREATE FUNCTION private.valid_admin_base_url(p_url text)
RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path TO ''
AS $function$
  SELECT coalesce(p_url ~ '^https://[a-z0-9-]+(\.[a-z0-9-]+)+$'
               OR p_url ~ '^http://localhost:[0-9]{2,5}$', false);
$function$;
REVOKE ALL ON FUNCTION private.valid_admin_base_url(text) FROM PUBLIC, anon, authenticated;

-- Creates one token and its email. Earlier unused links of the same kind
-- for this person stop working, so only the newest email is valid.
CREATE FUNCTION private.issue_staff_access(p_user uuid, p_kind text, p_base_url text, p_actor uuid)
RETURNS timestamptz
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_token text := encode(extensions.gen_random_bytes(32), 'hex');
  v_expires timestamptz := now() + CASE WHEN p_kind = 'invite' THEN interval '72 hours' ELSE interval '1 hour' END;
BEGIN
  IF p_kind NOT IN ('invite', 'reset') OR NOT private.valid_admin_base_url(p_base_url) THEN
    RAISE EXCEPTION 'invalid_staff_access_request' USING ERRCODE = '22023';
  END IF;
  UPDATE private.staff_access_tokens SET used_at = now()
  WHERE user_id = p_user AND kind = p_kind AND used_at IS NULL;
  UPDATE private.staff_access_emails SET link = NULL
  WHERE user_id = p_user AND kind = p_kind AND sent_at IS NULL;
  INSERT INTO private.staff_access_tokens(token_hash, user_id, kind, created_by, expires_at)
  VALUES (encode(extensions.digest(v_token, 'sha256'), 'hex'), p_user, p_kind, p_actor, v_expires);
  INSERT INTO private.staff_access_emails(user_id, kind, link, expires_at)
  VALUES (p_user, p_kind, p_base_url || '/auth/accept?token=' || v_token, v_expires);
  PERFORM private.invoke_edge_worker('account-email', 'account_email_worker');
  RETURN v_expires;
END;
$function$;
REVOKE ALL ON FUNCTION private.issue_staff_access(uuid, text, text, uuid) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. What staff (and the sign-in page) can call
-- ---------------------------------------------------------------------------

-- Super admin: send an invite (first sign-in) or a password-reset link to an
-- active staff member. Audited.
CREATE FUNCTION public.admin_send_staff_access(p_user_id uuid, p_kind text, p_base_url text)
RETURNS timestamptz
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_expires timestamptz;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'aal2_super_admin_required' USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.admin_memberships m WHERE m.user_id = p_user_id AND m.status = 'active') THEN
    RAISE EXCEPTION 'staff_member_not_found' USING ERRCODE = 'P0001';
  END IF;
  v_expires := private.issue_staff_access(p_user_id, p_kind, p_base_url, auth.uid());
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(),
          CASE WHEN p_kind = 'invite' THEN 'staff_invite_sent' ELSE 'staff_password_reset_sent' END,
          p_user_id, jsonb_build_object('expires_at', v_expires));
  RETURN v_expires;
END;
$function$;

-- Sign-in page "Forgot password" (service role, after the login throttle).
-- Says nothing about whether the address is staff. At most 3 a day per person.
CREATE FUNCTION public.request_staff_password_reset(p_email text, p_base_url text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_user uuid;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT m.user_id INTO v_user
  FROM public.admin_memberships m JOIN auth.users u ON u.id = m.user_id
  WHERE m.status = 'active' AND lower(u.email::text) = lower(trim(coalesce(p_email, '')));
  IF v_user IS NULL THEN RETURN; END IF;
  IF (SELECT count(*) FROM private.staff_access_tokens t
      WHERE t.user_id = v_user AND t.kind = 'reset' AND t.created_at > now() - interval '1 day') >= 3 THEN
    RETURN;
  END IF;
  PERFORM private.issue_staff_access(v_user, 'reset', p_base_url, NULL);
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (v_user, (SELECT m.role FROM public.admin_memberships m WHERE m.user_id = v_user),
          'staff_password_reset_requested', v_user, '{}'::jsonb);
END;
$function$;

-- The admin worker consumes a token once (service role). Returns the person
-- only while they are still active staff and the link is fresh.
CREATE FUNCTION public.consume_staff_access_token(p_token text)
RETURNS TABLE(user_id uuid, email text, kind text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_row private.staff_access_tokens%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF coalesce(p_token, '') !~ '^[0-9a-f]{64}$' THEN RETURN; END IF;
  SELECT * INTO v_row FROM private.staff_access_tokens t
  WHERE t.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
  FOR UPDATE;
  IF NOT FOUND OR v_row.used_at IS NOT NULL OR v_row.expires_at <= now() THEN RETURN; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.admin_memberships m WHERE m.user_id = v_row.user_id AND m.status = 'active') THEN
    RETURN;
  END IF;
  UPDATE private.staff_access_tokens SET used_at = now() WHERE token_hash = v_row.token_hash;
  RETURN QUERY SELECT v_row.user_id, (SELECT lower(a.email::text) FROM auth.users a WHERE a.id = v_row.user_id), v_row.kind;
END;
$function$;

-- Super admin: take someone off the staff list entirely (their member
-- account, if any, is untouched). Audited; never yourself or the last
-- active super admin.
CREATE FUNCTION public.admin_remove_staff_member(p_user_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_before public.admin_memberships%ROWTYPE;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'aal2_super_admin_required' USING ERRCODE = 'P0001';
  END IF;
  IF length(trim(coalesce(p_reason, ''))) < 6 THEN
    RAISE EXCEPTION 'Give a reason of at least 6 characters for the audit log.' USING ERRCODE = '22023';
  END IF;
  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'You cannot remove yourself. Ask another super admin.' USING ERRCODE = '22023';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('active-super-admin', 74));
  SELECT * INTO v_before FROM public.admin_memberships WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'staff_member_not_found' USING ERRCODE = 'P0001';
  END IF;
  IF v_before.role = 'super_admin' AND v_before.status = 'active'
     AND (SELECT count(*) FROM public.admin_memberships WHERE role = 'super_admin' AND status = 'active') <= 1 THEN
    RAISE EXCEPTION 'cannot_remove_last_super_admin' USING ERRCODE = 'P0001';
  END IF;
  DELETE FROM public.admin_memberships WHERE user_id = p_user_id;
  UPDATE private.staff_access_tokens SET used_at = now() WHERE user_id = p_user_id AND used_at IS NULL;
  DELETE FROM private.staff_access_emails WHERE user_id = p_user_id AND sent_at IS NULL;
  -- End their admin sessions (AAL2); app sessions (AAL1) are left alone.
  DELETE FROM auth.sessions s WHERE s.user_id = p_user_id AND s.aal = 'aal2';
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, before_state, details)
  VALUES (auth.uid(), public.current_admin_role(), 'staff_removed', p_user_id, to_jsonb(v_before),
          jsonb_build_object('reason', left(trim(p_reason), 500)));
END;
$function$;

-- Super admin: a staff member lost their phone. Their authenticator is
-- removed and their admin sessions end; at the next sign-in they set up a
-- new one. Their member app sessions stay. Audited; never yourself.
CREATE FUNCTION public.admin_reset_staff_mfa(p_user_id uuid, p_reason text)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_n integer;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'aal2_super_admin_required' USING ERRCODE = 'P0001';
  END IF;
  IF length(trim(coalesce(p_reason, ''))) < 6 THEN
    RAISE EXCEPTION 'Give a reason of at least 6 characters for the audit log.' USING ERRCODE = '22023';
  END IF;
  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Use your own Security check page to replace your authenticator.' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.admin_memberships m WHERE m.user_id = p_user_id) THEN
    RAISE EXCEPTION 'staff_member_not_found' USING ERRCODE = 'P0001';
  END IF;
  DELETE FROM auth.mfa_factors f WHERE f.user_id = p_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  DELETE FROM auth.sessions s WHERE s.user_id = p_user_id AND s.aal = 'aal2';
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(), 'staff_mfa_reset', p_user_id,
          jsonb_build_object('factors_removed', v_n, 'reason', left(trim(p_reason), 500)));
  RETURN v_n;
END;
$function$;

-- The staff list also says who has set up an authenticator, who has never
-- signed in to the panel, and whether a link is waiting.
DROP FUNCTION public.admin_staff_members(integer);
CREATE FUNCTION public.admin_staff_members(p_limit integer DEFAULT 100)
RETURNS TABLE(user_id uuid, email text, role text, status text, mfa_required boolean,
  created_at timestamptz, last_sign_in_at timestamptz, has_authenticator boolean,
  link_pending_until timestamptz, link_pending_kind text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT m.user_id, au.email::text, m.role, m.status, m.mfa_required,
    m.created_at, au.last_sign_in_at,
    EXISTS (SELECT 1 FROM auth.mfa_factors f WHERE f.user_id = m.user_id AND f.status = 'verified'),
    t.expires_at, t.kind
  FROM public.admin_memberships m
  JOIN auth.users au ON au.id = m.user_id
  LEFT JOIN LATERAL (
    SELECT tk.expires_at, tk.kind FROM private.staff_access_tokens tk
    WHERE tk.user_id = m.user_id AND tk.used_at IS NULL AND tk.expires_at > now()
    ORDER BY tk.created_at DESC LIMIT 1
  ) t ON true
  WHERE public.is_active_admin(ARRAY['super_admin'])
  ORDER BY m.created_at DESC
  LIMIT least(greatest(p_limit, 1), 100);
$function$;

-- Moderators: end every sign-in of a member (lost phone, account taken
-- over). They must sign in again; nothing else changes. Audited.
CREATE FUNCTION public.admin_sign_out_member(p_user_id uuid, p_reason text)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_n integer;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator']) THEN
    RAISE EXCEPTION 'Moderator authorization required' USING ERRCODE = '42501';
  END IF;
  IF length(trim(coalesce(p_reason, ''))) < 6 THEN
    RAISE EXCEPTION 'Give a reason of at least 6 characters for the audit log.' USING ERRCODE = '22023';
  END IF;
  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Sign yourself out from the menu instead.' USING ERRCODE = '22023';
  END IF;
  DELETE FROM auth.sessions s WHERE s.user_id = p_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(), 'member_signed_out_everywhere', p_user_id,
          jsonb_build_object('sessions_ended', v_n, 'reason', left(trim(p_reason), 500)));
  RETURN v_n;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3. The email worker's side
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.claim_staff_access_emails(p_limit integer DEFAULT 10)
RETURNS TABLE(email_id uuid, email_kind text, recipient text, first_name text, staff_role text,
  link text, expires_at timestamptz, is_member boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH candidates AS (
    SELECT e.id FROM private.staff_access_emails e
    WHERE e.sent_at IS NULL AND e.attempts < 6 AND e.link IS NOT NULL AND e.expires_at > now()
      AND (e.claimed_at IS NULL OR e.claimed_at < now() - interval '5 minutes')
    ORDER BY e.created_at
    LIMIT least(greatest(coalesce(p_limit, 10), 1), 25)
    FOR UPDATE SKIP LOCKED
  ), claimed AS (
    UPDATE private.staff_access_emails e SET claimed_at = now(), attempts = e.attempts + 1
    FROM candidates c WHERE e.id = c.id
    RETURNING e.id, e.kind, e.user_id, e.link, e.expires_at
  )
  SELECT c.id, c.kind,
         (SELECT lower(a.email::text) FROM auth.users a WHERE a.id = c.user_id),
         (SELECT p.first_name FROM public.profiles p WHERE p.user_id = c.user_id LIMIT 1),
         (SELECT m.role FROM public.admin_memberships m WHERE m.user_id = c.user_id),
         c.link, c.expires_at,
         EXISTS (SELECT 1 FROM public.users u WHERE u.id = c.user_id)
  FROM claimed c;
END;
$function$;

CREATE FUNCTION public.complete_staff_access_email(p_email_id uuid, p_success boolean, p_error text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  -- The link is only needed until it is sent.
  UPDATE private.staff_access_emails
  SET sent_at = CASE WHEN p_success THEN now() ELSE NULL END,
      claimed_at = NULL,
      link = CASE WHEN p_success OR attempts >= 6 THEN NULL ELSE link END,
      last_error = CASE WHEN p_success THEN NULL ELSE left(p_error, 200) END
  WHERE id = p_email_id;
END;
$function$;

-- The hourly retry (297, 340) also covers staff links and clears old rows.
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
    SELECT 1 FROM private.privacy_request_emails e
    WHERE e.sent_at IS NULL AND e.attempts < 6
      AND e.created_at < now() - interval '10 minutes'
      AND (e.claimed_at IS NULL OR e.claimed_at < now() - interval '5 minutes')
  ) OR EXISTS (
    -- 342
    SELECT 1 FROM private.staff_access_emails e
    WHERE e.sent_at IS NULL AND e.attempts < 6 AND e.link IS NOT NULL AND e.expires_at > now()
      AND e.created_at < now() - interval '10 minutes'
      AND (e.claimed_at IS NULL OR e.claimed_at < now() - interval '5 minutes')
  ) THEN
    PERFORM private.invoke_edge_worker('account-email', 'account_email_worker');
  END IF;
  UPDATE private.account_emails SET recipient_email = NULL
  WHERE recipient_email IS NOT NULL AND created_at < now() - interval '45 days';
  DELETE FROM private.account_emails WHERE created_at < now() - interval '90 days';
  DELETE FROM private.privacy_request_emails WHERE created_at < now() - interval '90 days';
  -- 342: links die with their expiry; rows go after 30 days.
  UPDATE private.staff_access_emails SET link = NULL WHERE link IS NOT NULL AND expires_at <= now();
  DELETE FROM private.staff_access_emails WHERE created_at < now() - interval '30 days';
  DELETE FROM private.staff_access_tokens WHERE created_at < now() - interval '30 days';
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4. Grants
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.admin_send_staff_access(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_remove_staff_member(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_reset_staff_mfa(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_staff_members(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_sign_out_member(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_send_staff_access(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_remove_staff_member(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reset_staff_mfa(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_staff_members(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_sign_out_member(uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.request_staff_password_reset(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.consume_staff_access_token(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.claim_staff_access_emails(integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_staff_access_email(uuid, boolean, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.request_staff_password_reset(text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.consume_staff_access_token(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.claim_staff_access_emails(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_staff_access_email(uuid, boolean, text) TO service_role;

NOTIFY pgrst, 'reload schema';
