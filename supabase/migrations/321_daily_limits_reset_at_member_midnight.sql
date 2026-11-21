-- Daily profile-view, interest and bookmark limits reset at the member's
-- own midnight instead of UTC midnight (05:30 in India). Owner decision,
-- 21 Nov 2026.
--
-- 1. private.member_timezone / member_today / member_day_start give one
--    answer for "today" per member. users.timezone is used when it is a
--    real IANA name (private.timezone_names, the same check quiet hours
--    use); anything else falls back to UTC.
-- 2. Every daily limit now uses them: profile views (record, quota, the
--    feed's remaining count, authorised profiles and photos for profiles
--    seen today), interests (quota and the insert trigger) and bookmarks.
--    profile_view_daily_seen.viewed_on now stores the viewer's local date.
-- 3. users.timezone was freely writable through patch_my_user, so a member
--    could hop timezones for extra resets. A timezone can now change at most
--    once every 7 days (first change from the default is always allowed);
--    a refused change keeps the old value silently, because the app sends
--    the timezone together with other fields. Service and admin writes
--    (no auth.uid()) are not limited.
--
-- Rows written today before this migration carry the UTC date. Between the
-- member's midnight and 00:00 UTC that can count one boundary day twice or
-- not at all, once, at the switch.

CREATE OR REPLACE FUNCTION private.member_timezone(p_user uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT coalesce(
    (SELECT tz.name
     FROM public.users u
     JOIN private.timezone_names tz ON tz.name = u.timezone
     WHERE u.id = p_user),
    'UTC'
  );
$function$;

CREATE OR REPLACE FUNCTION private.member_today(p_user uuid)
RETURNS date
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT (now() AT TIME ZONE private.member_timezone(p_user))::date;
$function$;

CREATE OR REPLACE FUNCTION private.member_day_start(p_user uuid)
RETURNS timestamptz
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT date_trunc('day', now() AT TIME ZONE private.member_timezone(p_user))
         AT TIME ZONE private.member_timezone(p_user);
$function$;

REVOKE ALL ON FUNCTION private.member_timezone(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.member_today(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.member_day_start(uuid) FROM PUBLIC;

-- Patch each function in place; every anchor must match exactly as often as
-- expected or the migration stops.
CREATE OR REPLACE FUNCTION pg_temp.patch_function(
  p_signature text,
  p_old text,
  p_new text,
  p_expected integer
) RETURNS void
LANGUAGE plpgsql
AS $patch$
DECLARE
  v_def text := pg_get_functiondef(p_signature::regprocedure);
  v_found integer := (length(v_def) - length(replace(v_def, p_old, ''))) / length(p_old);
BEGIN
  IF v_found <> p_expected THEN
    RAISE EXCEPTION '%: expected % of "%", found %',
      p_signature, p_expected, p_old, v_found;
  END IF;
  EXECUTE replace(v_def, p_old, p_new);
END;
$patch$;

SELECT pg_temp.patch_function(
  'public.record_profile_view(uuid, boolean)',
  'current_date', 'private.member_today(v_me)', 5);

SELECT pg_temp.patch_function(
  'public.get_profile_view_quota()',
  'viewed_on = current_date', 'viewed_on = private.member_today(v_me)', 1);
-- It reads only the caller's own rows (auth.uid()); definer rights let it
-- reach the private helper.
ALTER FUNCTION public.get_profile_view_quota() SECURITY DEFINER;

SELECT pg_temp.patch_function(
  'public.get_discovery_feed(uuid, double precision, uuid, integer, jsonb)',
  'seen.viewed_on = current_date',
  'seen.viewed_on = private.member_today(p_viewer_id)', 1);

SELECT pg_temp.patch_function(
  'public.get_authorized_member_profiles(uuid[])',
  's.viewed_on = current_date',
  's.viewed_on = private.member_today(v_me)', 1);

SELECT pg_temp.patch_function(
  'public.get_authorized_photo_paths(uuid, uuid[], integer)',
  's.viewed_on = current_date',
  's.viewed_on = private.member_today(p_viewer_user_id)', 1);

SELECT pg_temp.patch_function(
  'public.can_bookmark_member(uuid)',
  'b.created_at >= current_date',
  'b.created_at >= private.member_day_start(v_me)', 1);
SELECT pg_temp.patch_function(
  'public.can_bookmark_member(uuid)',
  's.viewed_on = current_date',
  's.viewed_on = private.member_today(v_me)', 1);

SELECT pg_temp.patch_function(
  'public.get_interest_quota()',
  'date_trunc(''day'', now() AT TIME ZONE ''UTC'') AT TIME ZONE ''UTC''',
  'private.member_day_start(v_me)', 1);

SELECT pg_temp.patch_function(
  'public.enforce_interest_limits()',
  'date_trunc(''day'', now() AT TIME ZONE ''UTC'') AT TIME ZONE ''UTC''',
  'private.member_day_start(NEW.sender_id)', 1);

-- Timezone changes: at most one every 7 days for members.
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS timezone_changed_at timestamptz;

COMMENT ON COLUMN public.users.timezone_changed_at IS
  'Last member change of timezone; daily limits follow timezone, so members may change it once every 7 days.';

CREATE OR REPLACE FUNCTION private.limit_timezone_changes()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  IF NEW.timezone IS NOT DISTINCT FROM OLD.timezone THEN
    NEW.timezone_changed_at := OLD.timezone_changed_at;
    RETURN NEW;
  END IF;
  IF auth.uid() IS NULL THEN
    -- Service and admin writes.
    NEW.timezone_changed_at := now();
    RETURN NEW;
  END IF;
  IF OLD.timezone_changed_at IS NOT NULL
     AND OLD.timezone_changed_at > now() - interval '7 days' THEN
    NEW.timezone := OLD.timezone;
    NEW.timezone_changed_at := OLD.timezone_changed_at;
  ELSE
    NEW.timezone_changed_at := now();
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.limit_timezone_changes() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_limit_timezone_changes ON public.users;
CREATE TRIGGER trg_limit_timezone_changes
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION private.limit_timezone_changes();
