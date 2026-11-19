-- "Viewed profiles" gallery: the profiles a member opened in discovery during
-- the last 30 days, newest first, one row per profile.
--
-- Read-only. It reuses public.profile_views (already written by
-- record_profile_view), so it adds no storage. It returns the same light card
-- a member saw in discovery (first name, last initial, age, city, verified)
-- and nothing more: the full profile still opens through record_profile_view
-- and get_authorized_member_profiles, so the free daily view limit is
-- unchanged.
--
-- A profile drops out of the gallery when it is no longer live (hidden,
-- paused, unfinished or unapproved), its owner was banned or deleted, either
-- member blocked the other, or incognito hides it from this member.
-- A blurhash is returned only for public photos, so a private photo is never
-- hinted at; signed photo links still come from the get-signed-url function.

CREATE OR REPLACE FUNCTION public.get_my_viewed_profiles(p_limit integer DEFAULT 60)
RETURNS TABLE(
  user_id uuid,
  first_name text,
  last_name_initial text,
  age integer,
  city_name text,
  is_verified boolean,
  photo_privacy text,
  photo_count integer,
  blurhash text,
  last_viewed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := auth.uid();
  v_my_profile_id uuid;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  SELECT p.id INTO v_my_profile_id
  FROM public.profiles p
  WHERE p.user_id = v_me
  LIMIT 1;

  IF v_my_profile_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH recent AS (
    SELECT pv.viewed_profile_id, max(pv.viewed_at) AS last_viewed_at
    FROM public.profile_views pv
    WHERE pv.viewer_profile_id = v_my_profile_id
      AND pv.viewed_profile_id <> v_my_profile_id
      AND pv.viewed_at >= now() - interval '30 days'
    GROUP BY pv.viewed_profile_id
  )
  SELECT
    owner.user_id,
    owner.first_name::text,
    left(coalesce(owner.last_name::text, ''), 1),
    date_part('year', age(current_date, owner.date_of_birth))::integer,
    city.name::text,
    coalesce(owner.is_verified, false),
    coalesce(owner.photo_privacy::text, 'public'),
    coalesce(photo_stats.photo_count, 0)::integer,
    CASE
      WHEN coalesce(owner.photo_privacy::text, 'public') = 'public'
        THEN photo_stats.primary_blurhash
    END,
    recent.last_viewed_at
  FROM recent
  JOIN public.profiles owner ON owner.id = recent.viewed_profile_id
  JOIN public.users owner_account ON owner_account.id = owner.user_id
  LEFT JOIN public.cities city ON city.id = owner.city_id
  LEFT JOIN LATERAL (
    SELECT
      count(*) AS photo_count,
      (array_agg(ph.blurhash ORDER BY ph.order_index))[1] AS primary_blurhash
    FROM public.photos ph
    WHERE ph.profile_id = owner.id
      AND ph.status = 'active'
      AND ph.admin_approved = true
      AND ph.nsfw_cleared = true
  ) photo_stats ON true
  WHERE owner.visibility = 'visible'
    AND coalesce(owner.onboarding_completed, false) = true
    AND owner.approved_at IS NOT NULL
    AND owner_account.deleted_at IS NULL
    AND coalesce(owner_account.is_banned, false) = false
    AND private.can_access_incognito_profile(v_me, owner.user_id)
    AND NOT EXISTS (
      SELECT 1
      FROM public.blocks b
      WHERE (b.blocker_id = v_me AND b.blocked_id = owner.user_id)
         OR (b.blocker_id = owner.user_id AND b.blocked_id = v_me)
    )
  ORDER BY recent.last_viewed_at DESC
  LIMIT least(greatest(coalesce(p_limit, 60), 1), 100);
END;
$function$;

REVOKE ALL ON FUNCTION public.get_my_viewed_profiles(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_viewed_profiles(integer) TO authenticated;
