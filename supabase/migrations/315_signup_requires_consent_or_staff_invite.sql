-- Sign-up code spam (third audit, 20 Nov 2026).
--
-- Supabase created an account, and emailed a sign-up code, for any address
-- sent to the public auth endpoint. A script could mail thousands of
-- strangers, burn the shared Brevo quota (sign-in codes, subscription and
-- deletion emails) and damage the sender reputation.
--
-- The app always binds the address to a signup consent transaction before
-- asking for a sign-up code (AuthCubit.sendOtp -> bind_signup_consent_
-- transaction -> signInWithOtp). Creating that transaction is rate-limited
-- per network and each binds one address. So the before-user-created hook
-- now creates an account only when:
--   * an unexpired, unconsumed consent transaction is bound to this exact
--     address, or
--   * a super admin prepared a staff invitation for it in the last hour
--     (admin panel: admin_prepare_staff_invite, then inviteUserByEmail).
-- Sign-ins never create accounts and are unaffected. All existing checks
-- (valid address, disposable domains, enforcement tombstones, fail closed)
-- are kept.

CREATE TABLE IF NOT EXISTS private.staff_invite_allowlist (
  email_hash text PRIMARY KEY,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT now() + interval '1 hour'
);
ALTER TABLE private.staff_invite_allowlist ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.staff_invite_allowlist FROM PUBLIC, anon, authenticated;

-- Same hash bind_signup_consent_transaction stores.
CREATE OR REPLACE FUNCTION private.signup_email_hash(p_email text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path TO ''
AS $function$
  SELECT encode(
    extensions.digest(
      convert_to(lower(trim(coalesce(p_email, ''))), 'UTF8'),
      'sha256'
    ),
    'hex'
  );
$function$;
REVOKE ALL ON FUNCTION private.signup_email_hash(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_prepare_staff_invite(p_email text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'aal2_super_admin_required' USING ERRCODE = 'P0001';
  END IF;
  IF lower(trim(coalesce(p_email, '')))
      !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
    RAISE EXCEPTION 'invalid_staff_email' USING ERRCODE = 'P0001';
  END IF;

  DELETE FROM private.staff_invite_allowlist WHERE expires_at <= now();
  INSERT INTO private.staff_invite_allowlist(email_hash, created_by)
  VALUES (private.signup_email_hash(p_email), auth.uid())
  ON CONFLICT (email_hash) DO UPDATE
    SET created_by = excluded.created_by,
        created_at = now(),
        expires_at = now() + interval '1 hour';
END;
$function$;
REVOKE ALL ON FUNCTION public.admin_prepare_staff_invite(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_prepare_staff_invite(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.hook_before_user_created(event jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_email text;
  v_hash text;
BEGIN
  v_email := lower(trim(coalesce(event->'user'->>'email', '')));

  IF v_email = '' OR position('@' IN v_email) = 0 THEN
    RETURN jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 400,
        'message', 'Please enter a valid email address.'
      )
    );
  END IF;

  IF public.is_disposable_email_domain(v_email) THEN
    RETURN jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 400,
        'message', 'Temporary or disposable email addresses are not allowed. Please use a real personal email address.'
      )
    );
  END IF;

  IF EXISTS (
    SELECT 1
    FROM private.enforcement_tombstones t
    WHERE t.email_hash = private.enforcement_email_hash(v_email)
      AND (t.expires_at IS NULL OR t.expires_at > now())
  ) THEN
    RETURN jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 403,
        'message', 'This email address cannot be used to create a Silarah account. Contact support@silarah.com if you think this is a mistake.'
      )
    );
  END IF;

  -- A new account needs the in-app consent step (or a staff invitation)
  -- for this exact address, so scripts cannot mail sign-up codes to
  -- strangers.
  v_hash := private.signup_email_hash(v_email);
  IF NOT EXISTS (
    SELECT 1
    FROM private.signup_consent_transactions c
    WHERE c.bound_email_hash = v_hash
      AND c.consumed_at IS NULL
      AND c.expires_at > now()
  ) AND NOT EXISTS (
    SELECT 1
    FROM private.staff_invite_allowlist s
    WHERE s.email_hash = v_hash
      AND s.expires_at > now()
  ) THEN
    RETURN jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 403,
        'message', 'Please create your account in the Silarah app and accept the terms before requesting a code.'
      )
    );
  END IF;

  RETURN '{}'::jsonb;
EXCEPTION
  WHEN others THEN
    -- Fail closed so fake-account protection is not bypassed during lookup
    -- failures. The message is intentionally user-safe.
    RETURN jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 503,
        'message', 'We could not validate this email address. Please try again.'
      )
    );
END;
$function$;
