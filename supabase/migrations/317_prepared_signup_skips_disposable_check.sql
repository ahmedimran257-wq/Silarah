-- Prepared addresses skip the disposable-domain list (20 Nov 2026).
--
-- An address a super admin or the service role prepared
-- (admin_prepare_staff_invite) was authorised on purpose, so it skips the
-- disposable-domain list (which also rejects reserved .invalid test
-- addresses). Everything else is unchanged: public sign-ups still need a
-- valid, non-disposable address and the in-app consent step, and enforcement
-- tombstones block every path.

CREATE OR REPLACE FUNCTION public.hook_before_user_created(event jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_email text;
  v_hash text;
  v_prepared boolean;
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

  v_hash := private.signup_email_hash(v_email);
  v_prepared := EXISTS (
    SELECT 1
    FROM private.staff_invite_allowlist s
    WHERE s.email_hash = v_hash
      AND s.expires_at > now()
  );

  IF NOT v_prepared AND public.is_disposable_email_domain(v_email) THEN
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

  -- A new account needs the in-app consent step (or a prepared address) so
  -- scripts cannot mail sign-up codes to strangers.
  IF NOT v_prepared AND NOT EXISTS (
    SELECT 1
    FROM private.signup_consent_transactions c
    WHERE c.bound_email_hash = v_hash
      AND c.consumed_at IS NULL
      AND c.expires_at > now()
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
