-- Findings from an adversarial review of the member and anonymous API.
--
-- 1. public.spatial_ref_sys (PostGIS) has no row security and its write
--    grants belong to supabase_admin, so they cannot be revoked here. Anyone,
--    even without an account, could delete or rewrite projection definitions
--    and break distance matching. A trigger now refuses writes from API roles;
--    reads and server-side maintenance are unchanged.
-- 2. interest_daily_limit and profile_view_daily_limit answered for any
--    member id, revealing whether that member pays for Premium. They now
--    answer only about the caller (server jobs without a member are unchanged).

CREATE OR REPLACE FUNCTION private.block_spatial_ref_sys_writes()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $$
BEGIN
  IF current_user IN ('anon', 'authenticated') THEN
    RAISE EXCEPTION 'spatial_ref_sys is read-only' USING ERRCODE = '42501';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

DROP TRIGGER IF EXISTS block_member_writes ON public.spatial_ref_sys;
CREATE TRIGGER block_member_writes
  BEFORE INSERT OR UPDATE OR DELETE ON public.spatial_ref_sys
  FOR EACH ROW EXECUTE FUNCTION private.block_spatial_ref_sys_writes();

DROP TRIGGER IF EXISTS block_member_truncate ON public.spatial_ref_sys;
CREATE TRIGGER block_member_truncate
  BEFORE TRUNCATE ON public.spatial_ref_sys
  FOR EACH STATEMENT EXECUTE FUNCTION private.block_spatial_ref_sys_writes();

CREATE OR REPLACE FUNCTION public.interest_daily_limit(p_user_id uuid)
RETURNS integer
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $$
  SELECT CASE
    WHEN auth.uid() IS NOT NULL AND p_user_id IS DISTINCT FROM auth.uid()
      THEN NULL
    WHEN public.has_active_premium(p_user_id) THEN 25
    ELSE 5
  END;
$$;

CREATE OR REPLACE FUNCTION public.profile_view_daily_limit(p_user_id uuid)
RETURNS integer
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $$
  SELECT CASE
    WHEN auth.uid() IS NOT NULL AND p_user_id IS DISTINCT FROM auth.uid()
      THEN NULL
    WHEN public.has_active_premium(p_user_id) THEN 2147483647
    ELSE 15
  END;
$$;

-- An event-trigger function; it can never be called usefully over the API.
DO $$
BEGIN
  IF to_regprocedure('public.rls_auto_enable()') IS NOT NULL THEN
    REVOKE EXECUTE ON FUNCTION public.rls_auto_enable()
      FROM PUBLIC, anon, authenticated;
  END IF;
END;
$$;
