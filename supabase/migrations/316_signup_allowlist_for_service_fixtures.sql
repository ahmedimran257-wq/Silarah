-- Server-side address preparation (20 Nov 2026).
--
-- 315 lets the public sign-up path create an account only after the in-app
-- consent step or a prepared staff invitation. The service role already
-- holds full database authority, so server scripts may prepare an address
-- too; members still cannot. The function now returns true so REST callers
-- get a normal 200 JSON response.
--
-- Verified live on 20 Nov 2026: the Auth admin API (POST /auth/v1/admin/users,
-- used by the fixture scripts) does not run the before-user-created hook, so
-- those scripts never needed preparing. The public /auth/v1/otp path does.

DROP FUNCTION IF EXISTS public.admin_prepare_staff_invite(text);

CREATE FUNCTION public.admin_prepare_staff_invite(p_email text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role'
    AND NOT public.is_active_admin(ARRAY['super_admin']) THEN
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
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.admin_prepare_staff_invite(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_prepare_staff_invite(text)
  TO authenticated, service_role;
