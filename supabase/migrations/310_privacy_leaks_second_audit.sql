-- Privacy leaks found by the second audit (19 Nov 2026). Callers checked
-- first: the app reads the same columns from every function below, and the
-- removed entry points (legacy guardian dashboard, name search) have no
-- caller in the app, the admin panel or the edge functions.
--
-- 1. Location: Discover returned the exact distance to every card, and any
--    member can move their own Discover origin, so three moves pinned down
--    another member's stored point. Device positions were kept to ~110 m.
--    Now: no distance leaves the server, device positions are kept to
--    ~11 km (one decimal), and the Premium radius filter starts at 10 km,
--    so it cannot be used as a precise yes/no probe.
-- 2. Legacy get_guardian_dashboard (both overloads) skipped the 307
--    entitlement gate and returned message previews and storage paths.
--    The app uses only get_guardian_dashboard_v2; execute is revoked.
-- 3. Profile viewers listed incognito, banned, deleted and shadowbanned
--    viewers, and the "someone viewed you" push fired for them.
-- 4. Discover cards and full profiles carried last-active time to the
--    microsecond. It is now kept to 5-minute steps, which is all the app
--    shows ("Online now", "x min ago").
-- 5. Photo rows were readable across a block, through incognito, and for
--    banned or deleted owners (can_view_photo). Photo access context and
--    incoming photo requests had the same gaps.
-- 6. search_profiles_by_name_city (unused) listed members city by city.
-- 7. Former guardians kept full-profile access through mirror rows.
-- 8. Query statistics (SQL text) were readable by every database role.

-- 1a. Device positions to one decimal (~11 km).
CREATE OR REPLACE FUNCTION public.update_discovery_location(
  p_latitude double precision,
  p_longitude double precision
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_lat numeric;
  v_lng numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;
  IF p_latitude IS NULL OR p_longitude IS NULL
      OR p_latitude NOT BETWEEN -90 AND 90
      OR p_longitude NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION 'Invalid coordinates.';
  END IF;

  -- One decimal place is about 11 km: enough for "within 25 km", never a
  -- street or a building.
  v_lat := round(p_latitude::numeric, 1);
  v_lng := round(p_longitude::numeric, 1);
  UPDATE public.profiles
  SET location = public.ST_SetSRID(
        public.ST_MakePoint(v_lng, v_lat), 4326)::public.geography,
      location_source = 'device_coarse',
      location_updated_at = now()
  WHERE user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found.';
  END IF;
END;
$function$;

-- Positions already stored from devices get the same coarsening.
UPDATE public.profiles
SET location = public.ST_SetSRID(public.ST_MakePoint(
      round(public.ST_X(location::public.geometry)::numeric, 1),
      round(public.ST_Y(location::public.geometry)::numeric, 1)
    ), 4326)::public.geography
WHERE location_source = 'device_coarse'
  AND location IS NOT NULL;

-- 1b, 4. Discover feed and pool, 7. guardian mirror access: exact edits.
DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  -- No distance leaves the server; ranking still uses it internally.
  v_def := pg_get_functiondef('public.get_discovery_feed'::regproc);
  v_old := E'r.is_verified, r.distance_km, r.recommendation_score,';
  v_new := E'r.is_verified, NULL::double precision, r.recommendation_score,';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION 'get_discovery_feed: distance output not found exactly once';
  END IF;
  v_def := replace(v_def, v_old, v_new);
  -- The radius filter starts at 10 km (the app's smallest choice).
  v_old := E'      RAISE EXCEPTION \'invalid_distance_radius\' USING ERRCODE = \'22023\';\n    END IF;\n';
  v_new := v_old
        || E'    -- Below 10 km a moving origin turns the filter into a location probe.\n'
        || E'    v_max_distance_km := greatest(v_max_distance_km, 10);\n';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION 'get_discovery_feed: radius check not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);

  -- Discover pool: last active in 5-minute steps.
  v_def := pg_get_viewdef('public.live_discovery_pool'::regclass, true);
  v_old := E'    p.last_active_at,\n';
  v_new := E'    date_bin(\'00:05:00\'::interval, p.last_active_at, \'2000-01-01 00:00:00+00\'::timestamp with time zone) AS last_active_at,\n';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION 'live_discovery_pool: last_active_at not found exactly once';
  END IF;
  EXECUTE 'CREATE OR REPLACE VIEW public.live_discovery_pool WITH (security_invoker = true) AS '
       || replace(v_def, v_old, v_new);

  -- Full profiles: last active in 5-minute steps; former guardians lose
  -- mirror access.
  v_def := pg_get_functiondef('public.get_authorized_member_profiles(uuid[])'::regprocedure);
  v_old := E'\'last_active_at\', p.last_active_at,';
  v_new := E'\'last_active_at\', date_bin(\'00:05:00\'::interval, p.last_active_at, \'2000-01-01 00:00:00+00\'::timestamptz),';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION 'get_authorized_member_profiles: last_active_at not found exactly once';
  END IF;
  v_def := replace(v_def, v_old, v_new);
  v_old := E'        WHERE gcm.guardian_id = v_me\n';
  v_new := v_old || E'          AND public.is_current_guardian_for_ward(gcm.ward_id, gcm.mode)\n';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION 'get_authorized_member_profiles: mirror branch not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);
END
$migration$;

-- 2. Legacy guardian dashboard and 6. name search: no member access.
DO $migration$
DECLARE
  v_fn regprocedure;
BEGIN
  FOR v_fn IN
    SELECT p.oid::regprocedure
    FROM pg_proc p
    WHERE p.pronamespace = 'public'::regnamespace
      AND p.proname IN ('get_guardian_dashboard', 'search_profiles_by_name_city')
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', v_fn);
  END LOOP;
END
$migration$;

-- 3. Who viewed me: only members this member may see.
CREATE OR REPLACE FUNCTION public.get_my_profile_viewers(p_limit integer DEFAULT 50)
RETURNS TABLE(
  viewer_user_id uuid,
  first_name text,
  last_name text,
  date_of_birth date,
  gender text,
  is_verified boolean,
  bio text,
  photo_privacy text,
  sect text,
  deen_level text,
  city_name text,
  viewed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := auth.uid();
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;
  IF NOT public.has_active_premium(v_me) THEN
    RAISE EXCEPTION 'premium_required' USING ERRCODE = 'P0001';
  END IF;

  RETURN QUERY
  SELECT recent.viewer_user_id,
         recent.first_name,
         recent.last_name,
         recent.date_of_birth,
         recent.gender,
         recent.is_verified,
         recent.bio,
         recent.photo_privacy,
         recent.sect,
         recent.deen_level,
         recent.city_name,
         recent.viewed_at
  FROM (
    SELECT DISTINCT ON (pv.viewer_profile_id)
      viewer.user_id AS viewer_user_id,
      viewer.first_name::text,
      left(coalesce(viewer.last_name::text, ''), 1) AS last_name,
      NULL::date AS date_of_birth,
      viewer.gender::text,
      coalesce(viewer.is_verified, false) AS is_verified,
      coalesce(viewer.bio, '')::text AS bio,
      viewer.photo_privacy::text,
      viewer.sect::text,
      viewer.deen_level::text,
      city.name::text AS city_name,
      pv.viewed_at
    FROM public.profile_views pv
    JOIN public.profiles mine ON mine.id = pv.viewed_profile_id
    JOIN public.profiles viewer ON viewer.id = pv.viewer_profile_id
    JOIN public.users viewer_account ON viewer_account.id = viewer.user_id
    LEFT JOIN public.cities city ON city.id = viewer.city_id
    WHERE mine.user_id = v_me
      AND pv.viewed_at >= now() - interval '7 days'
      AND viewer.visibility = 'visible'
      AND viewer_account.deleted_at IS NULL
      AND coalesce(viewer_account.is_banned, false) = false
      AND coalesce(viewer_account.is_shadowbanned, false) = false
      AND private.can_access_incognito_profile(v_me, viewer.user_id)
      AND NOT EXISTS (
        SELECT 1 FROM public.blocks b
        WHERE (b.blocker_id = v_me AND b.blocked_id = viewer.user_id)
           OR (b.blocker_id = viewer.user_id AND b.blocked_id = v_me)
      )
    ORDER BY pv.viewer_profile_id, pv.viewed_at DESC
  ) recent
  ORDER BY recent.viewed_at DESC
  LIMIT least(greatest(coalesce(p_limit, 50), 1), 100);
END;
$function$;

-- The free weekly count uses exactly the same viewer rule.
CREATE OR REPLACE FUNCTION public.get_my_profile_view_summary()
RETURNS TABLE(viewer_count bigint, unseen_viewer_count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_last_seen_at timestamptz;
BEGIN
  INSERT INTO private.profile_view_activity_state(user_id)
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT state.last_seen_at
  INTO v_last_seen_at
  FROM private.profile_view_activity_state state
  WHERE state.user_id = v_user_id;

  RETURN QUERY
  SELECT
    count(DISTINCT pv.viewer_profile_id)::bigint AS viewer_count,
    count(DISTINCT pv.viewer_profile_id)
      FILTER (WHERE pv.viewed_at > v_last_seen_at)::bigint
      AS unseen_viewer_count
  FROM public.profile_views pv
  JOIN public.profiles mine ON mine.id = pv.viewed_profile_id
  JOIN public.profiles viewer ON viewer.id = pv.viewer_profile_id
  JOIN public.users viewer_account ON viewer_account.id = viewer.user_id
  WHERE mine.user_id = v_user_id
    AND pv.viewed_at >= now() - interval '7 days'
    AND viewer.visibility = 'visible'
    AND viewer_account.deleted_at IS NULL
    AND coalesce(viewer_account.is_banned, false) = false
    AND coalesce(viewer_account.is_shadowbanned, false) = false
    AND private.can_access_incognito_profile(v_user_id, viewer.user_id)
    AND NOT EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (b.blocker_id = v_user_id AND b.blocked_id = viewer.user_id)
         OR (b.blocker_id = viewer.user_id AND b.blocked_id = v_user_id)
    );
END;
$function$;

-- And no "someone viewed you" push from a viewer the owner could not see.
CREATE OR REPLACE FUNCTION private.maybe_queue_profile_view_notification(
  p_viewer_user_id uuid,
  p_viewed_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF p_viewer_user_id IS NULL
    OR p_viewed_user_id IS NULL
    OR p_viewer_user_id = p_viewed_user_id THEN
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.blocks b
    WHERE (b.blocker_id = p_viewer_user_id AND b.blocked_id = p_viewed_user_id)
       OR (b.blocker_id = p_viewed_user_id AND b.blocked_id = p_viewer_user_id)
  ) THEN
    RETURN;
  END IF;

  -- Incognito, shadowbanned, banned or deleted viewers stay silent.
  IF NOT private.can_access_incognito_profile(p_viewed_user_id, p_viewer_user_id)
    OR EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = p_viewer_user_id
        AND (u.deleted_at IS NOT NULL
             OR coalesce(u.is_banned, false)
             OR coalesce(u.is_shadowbanned, false))
    ) THEN
    RETURN;
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_viewed_user_id::text, 186)
  );

  IF EXISTS (
    SELECT 1
    FROM public.notifications n
    WHERE n.user_id = p_viewed_user_id
      AND n.type = 'profile_view'
      AND n.created_at >= now() - interval '6 hours'
  ) THEN
    RETURN;
  END IF;

  PERFORM public.queue_notification(
    p_viewed_user_id,
    'profile_view',
    'New profile activity',
    'Someone viewed your profile.',
    'silarah://profile-views'
  );
END;
$function$;

-- 5. Photo rows: privacy plus blocks, incognito and account standing.
-- Also used by get_authorized_photo_paths (service role, explicit viewer)
-- and the photos_select policy; every check below uses p_viewer.
CREATE OR REPLACE FUNCTION public.can_view_photo(p_viewer uuid, p_owner_profile uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_owner_user_id uuid;
  v_privacy text;
BEGIN
  IF p_viewer IS NULL OR p_owner_profile IS NULL THEN
    RETURN false;
  END IF;

  -- Members may only ask about themselves; workers may ask about anyone.
  IF p_viewer IS DISTINCT FROM auth.uid()
     AND coalesce(auth.role(), '') <> 'service_role' THEN
    RETURN false;
  END IF;

  -- Own photos: always visible.
  IF EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = p_owner_profile AND user_id = p_viewer
  ) THEN
    RETURN true;
  END IF;

  SELECT pr.photo_privacy, pr.user_id
  INTO v_privacy, v_owner_user_id
  FROM public.profiles pr
  JOIN public.users owner_account ON owner_account.id = pr.user_id
  WHERE pr.id = p_owner_profile
    AND pr.visibility = 'visible'
    AND owner_account.deleted_at IS NULL
    AND coalesce(owner_account.is_banned, false) = false;

  IF v_owner_user_id IS NULL OR v_privacy IS NULL THEN
    RETURN false;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.blocks b
    WHERE (b.blocker_id = p_viewer AND b.blocked_id = v_owner_user_id)
       OR (b.blocker_id = v_owner_user_id AND b.blocked_id = p_viewer)
  ) THEN
    RETURN false;
  END IF;

  IF NOT private.can_access_incognito_profile(p_viewer, v_owner_user_id) THEN
    RETURN false;
  END IF;

  IF v_privacy = 'public' THEN
    RETURN true;
  END IF;

  IF v_privacy = 'mutual_only' THEN
    RETURN EXISTS (
      SELECT 1
      FROM public.matches m
      WHERE m.status = 'active'
        AND (
          (m.user_a = p_viewer AND m.user_b = v_owner_user_id)
          OR (m.user_b = p_viewer AND m.user_a = v_owner_user_id)
        )
    );
  END IF;

  IF v_privacy = 'request_only' THEN
    RETURN EXISTS (
      SELECT 1 FROM public.photo_access_requests par
      WHERE par.requester_id = p_viewer
        AND par.owner_id = v_owner_user_id
        AND par.status = 'granted'
    );
  END IF;

  RETURN false;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_photo_access_context(p_owner_id uuid)
RETURNS TABLE(
  photo_privacy text,
  is_mutual boolean,
  request_status text,
  can_view boolean,
  photo_count integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_viewer uuid := auth.uid();
  v_profile_id uuid;
  v_owner_user_id uuid;
  v_privacy text;
BEGIN
  IF v_viewer IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  SELECT p.id, p.user_id, p.photo_privacy
  INTO v_profile_id, v_owner_user_id, v_privacy
  FROM public.profiles p
  JOIN public.users owner_account ON owner_account.id = p.user_id
  WHERE (p.user_id = p_owner_id OR p.id = p_owner_id)
    AND (
      p.user_id = v_viewer
      OR (
        p.visibility = 'visible'
        AND owner_account.deleted_at IS NULL
        AND coalesce(owner_account.is_banned, false) = false
        AND private.can_access_incognito_profile(v_viewer, p.user_id)
        AND NOT EXISTS (
          SELECT 1 FROM public.blocks b
          WHERE (b.blocker_id = p.user_id AND b.blocked_id = v_viewer)
             OR (b.blocker_id = v_viewer AND b.blocked_id = p.user_id)
        )
      )
    )
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'Profile is unavailable.';
  END IF;

  RETURN QUERY
  SELECT
    v_privacy,
    EXISTS (
      SELECT 1
      FROM public.matches m
      WHERE m.status = 'active'
        AND (
          (m.user_a = v_viewer AND m.user_b = v_owner_user_id)
          OR (m.user_b = v_viewer AND m.user_a = v_owner_user_id)
        )
    ),
    (
      SELECT par.status
      FROM public.photo_access_requests par
      WHERE par.requester_id = v_viewer
        AND par.owner_id = v_owner_user_id
      LIMIT 1
    ),
    public.can_view_photo(v_viewer, v_profile_id),
    (
      SELECT count(*)::integer
      FROM public.photos ph
      WHERE ph.profile_id = v_profile_id
        AND ph.status = 'active'
        AND ph.admin_approved = true
        AND ph.nsfw_cleared = true
    );
END;
$function$;

-- Incoming photo requests: none from members you blocked or who blocked
-- you, or whose account is banned or deleted.
CREATE OR REPLACE FUNCTION public.get_incoming_photo_access_requests()
RETURNS TABLE(
  request_id uuid,
  requester_id uuid,
  first_name text,
  last_name_initial text,
  status text,
  created_at timestamptz,
  responded_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT
    par.id,
    par.requester_id,
    coalesce(p.first_name, 'Member'),
    left(coalesce(p.last_name, ''), 1),
    par.status,
    par.created_at,
    par.responded_at
  FROM public.photo_access_requests par
  JOIN public.users requester ON requester.id = par.requester_id
  LEFT JOIN public.profiles p ON p.user_id = par.requester_id
  WHERE par.owner_id = auth.uid()
    AND requester.deleted_at IS NULL
    AND coalesce(requester.is_banned, false) = false
    AND NOT EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (b.blocker_id = auth.uid() AND b.blocked_id = par.requester_id)
         OR (b.blocker_id = par.requester_id AND b.blocked_id = auth.uid())
    )
  ORDER BY
    CASE par.status WHEN 'pending' THEN 0 WHEN 'granted' THEN 1 ELSE 2 END,
    par.created_at DESC;
$function$;

-- 8. Query statistics: the dashboard keeps its own grants.
REVOKE SELECT ON extensions.pg_stat_statements FROM PUBLIC, anon, authenticated;
REVOKE SELECT ON extensions.pg_stat_statements_info FROM PUBLIC, anon, authenticated;
