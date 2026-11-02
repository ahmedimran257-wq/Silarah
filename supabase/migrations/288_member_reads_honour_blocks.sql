-- Silarah — a block also ends profile reads, not just photos
--
-- Final pre-launch audit, November 2026. Migration 280 stopped a blocked
-- member loading the blocker's photos. The profile text itself was still
-- readable: get_authorized_member_profiles kept serving the blocker's full
-- profile (bio, profession, last active time) to the blocked member through
-- the old match row (a block sets status 'blocked', it does not remove it),
-- a bookmark, today's view record, and an explicit "they blocked me" clause.
-- Reproduced on staging in a rolled-back transaction: after A blocked B,
-- B still received A's profile.
--
-- Three neighbours had the same gap with less data:
--   * get_member_trust_summaries: verification and guardian badges through
--     an old interest or match;
--   * get_discovery_compatibility_preferences: partner preferences for any
--     visible profile id, ignoring blocks and Premium incognito;
--   * get_photo_access_context: photo privacy and photo count.
--
-- The rule now matches photos: once the owner has blocked you, every route
-- is closed (a guardian reading for a ward is treated as the ward). The
-- blocker can still read the person they blocked, which the blocked-members
-- list needs. Error messages stay the ones an unavailable profile already
-- gets, so a block is not revealed.

CREATE OR REPLACE FUNCTION public.get_authorized_member_profiles(p_user_ids uuid[])
RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := auth.uid();
  v_ids uuid[];
BEGIN
  PERFORM private.assert_authenticated();
  v_ids := ARRAY(
    SELECT DISTINCT requested_id
    FROM unnest(coalesce(p_user_ids, ARRAY[]::uuid[])) requested_id
    WHERE requested_id IS NOT NULL
    LIMIT 50
  );
  IF cardinality(v_ids) = 0 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT jsonb_build_object(
    'id', p.id,
    'user_id', p.user_id,
    'first_name', p.first_name,
    'last_name', p.last_name,
    'last_name_initial', left(coalesce(p.last_name, ''), 1),
    'age', date_part('year', age(current_date, p.date_of_birth))::integer,
    'gender', p.gender,
    'city_name', c.name,
    'country_code', p.country_code,
    'sect', p.sect,
    'deen_level', p.deen_level,
    'photo_privacy', p.photo_privacy,
    'bio', p.bio,
    'profession', p.profession,
    'education_level', p.education_level,
    'education_rank', p.education_rank,
    'family_type', p.family_type,
    'previously_married', p.previously_married,
    'children_count', p.children_count,
    'mother_tongue', p.mother_tongue,
    'community', p.community,
    'diet_type', p.diet_type,
    'living_expectation', p.living_expectation,
    'quran_memorization', p.quran_memorization,
    'religious_education', p.religious_education,
    'marriage_timeline', p.marriage_timeline,
    'willing_to_relocate', p.willing_to_relocate,
    'height_cm', p.height_cm,
    'complexion', p.complexion,
    'smoking_habit', p.smoking_habit,
    'vaping_habit', p.vaping_habit,
    'hookah_habit', p.hookah_habit,
    'languages', coalesce(p.languages, ARRAY[]::text[]),
    'interests', coalesce(p.interests, ARRAY[]::text[]),
    'last_active_at', p.last_active_at,
    'is_verified', p.is_verified,
    'guardian_managed', p.profile_owner_type::text = 'guardian',
    'guardian_connected', p.guardian_user_id IS NOT NULL
      AND p.guardian_user_id <> p.user_id
  )
  FROM public.profiles p
  JOIN public.users u ON u.id = p.user_id
  LEFT JOIN public.cities c ON c.id = p.city_id
  WHERE p.user_id = ANY(v_ids)
    AND private.can_access_incognito_profile(v_me, p.user_id)
    AND coalesce(u.is_banned, false) = false
    AND u.deleted_at IS NULL
    -- A member who blocked you is closed to you by every route below.
    AND (
      p.user_id = v_me
      OR NOT EXISTS (
        SELECT 1 FROM public.blocks owner_block
        WHERE owner_block.blocker_id = p.user_id
          AND owner_block.blocked_id = v_me
      )
    )
    AND (
      p.user_id = v_me
      OR EXISTS (
        SELECT 1 FROM public.profile_view_daily_seen s
        WHERE s.viewer_user_id = v_me
          AND s.viewed_profile_id = p.id
          AND s.viewed_on = current_date
      )
      OR EXISTS (
        SELECT 1 FROM public.interests i
        WHERE (i.sender_id = v_me AND i.receiver_id = p.user_id)
           OR (i.receiver_id = v_me AND i.sender_id = p.user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.matches m
        WHERE (m.user_a = v_me AND m.user_b = p.user_id)
           OR (m.user_b = v_me AND m.user_a = p.user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.profile_bookmarks b
        WHERE b.user_id = v_me AND b.saved_user_id = p.user_id
      )
      OR EXISTS (
        SELECT 1 FROM public.photo_access_requests par
        WHERE par.requester_id = v_me
          AND par.owner_id = p.user_id
          AND par.status = 'granted'
      )
      -- The blocked-members list names the people you blocked.
      OR EXISTS (
        SELECT 1 FROM public.blocks b
        WHERE b.blocker_id = v_me AND b.blocked_id = p.user_id
      )
      OR EXISTS (
        SELECT 1 FROM public.reports r
        WHERE r.reporter_id = v_me AND r.reported_user_id = p.user_id
      )
      OR p.guardian_user_id = v_me
      OR EXISTS (
        SELECT 1
        FROM public.guardian_chat_mirrors gcm
        JOIN public.matches gm ON gm.id = gcm.match_id
        WHERE gcm.guardian_id = v_me
          AND (
            p.user_id = gcm.ward_id
            OR (gm.user_a = gcm.ward_id AND p.user_id = gm.user_b)
            OR (gm.user_b = gcm.ward_id AND p.user_id = gm.user_a)
          )
          -- A guardian reads for the ward: closed once the other member
          -- has blocked the ward.
          AND NOT EXISTS (
            SELECT 1 FROM public.blocks ward_block
            WHERE ward_block.blocker_id = p.user_id
              AND ward_block.blocked_id = gcm.ward_id
          )
      )
    )
  ORDER BY array_position(v_ids, p.user_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_member_trust_summaries(p_user_ids uuid[])
RETURNS TABLE(
  user_id uuid,
  photo_verified boolean,
  guardian_connected boolean,
  guardian_managed boolean,
  established_member boolean
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_ids uuid[];
BEGIN
  v_ids := ARRAY(
    SELECT DISTINCT requested
    FROM unnest(coalesce(p_user_ids, ARRAY[]::uuid[])) requested
    WHERE requested IS NOT NULL LIMIT 20
  );
  IF cardinality(v_ids) = 0 THEN RETURN; END IF;

  RETURN QUERY
  SELECT
    p.user_id,
    (p.photo_verified_at IS NOT NULL
      AND p.photo_verification_paused_at IS NULL)::boolean,
    (p.guardian_user_id IS NOT NULL AND p.guardian_user_id <> p.user_id)::boolean,
    (p.profile_owner_type::text = 'guardian')::boolean,
    (u.created_at <= now() - interval '30 days'
      AND u.deleted_at IS NULL
      AND coalesce(u.is_banned, false) = false)::boolean
  FROM public.profiles p
  JOIN public.users u ON u.id = p.user_id
  WHERE p.user_id = ANY(v_ids)
    AND private.can_access_incognito_profile(v_me, p.user_id)
    AND (
      p.user_id = v_me
      OR NOT EXISTS (
        SELECT 1 FROM public.blocks owner_block
        WHERE owner_block.blocker_id = p.user_id
          AND owner_block.blocked_id = v_me
      )
    )
    AND (
      p.user_id = v_me
      OR EXISTS (
        SELECT 1 FROM public.live_discovery_pool candidate
        WHERE candidate.user_id = p.user_id
      )
      OR EXISTS (
        SELECT 1 FROM public.interests i
        WHERE (i.sender_id = v_me AND i.receiver_id = p.user_id)
           OR (i.receiver_id = v_me AND i.sender_id = p.user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.matches m
        WHERE (m.user_a = v_me AND m.user_b = p.user_id)
           OR (m.user_b = v_me AND m.user_a = p.user_id)
      )
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_discovery_compatibility_preferences(p_profile_ids uuid[])
RETURNS TABLE(
  profile_id uuid,
  sect_preference text,
  deen_preference text,
  min_education_rank integer
)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT
    p.id,
    pr.sect_preference,
    pr.deen_preference,
    pr.min_education_rank
  FROM public.profiles p
  JOIN public.profile_preferences pr ON pr.profile_id = p.id
  WHERE auth.uid() IS NOT NULL
    AND p.id = ANY(COALESCE(p_profile_ids, ARRAY[]::uuid[]))
    AND p.user_id <> auth.uid()
    AND p.visibility = 'visible'
    AND p.onboarding_completed = true
    AND private.can_access_incognito_profile(auth.uid(), p.user_id)
    AND NOT EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (b.blocker_id = p.user_id AND b.blocked_id = auth.uid())
         OR (b.blocker_id = auth.uid() AND b.blocked_id = p.user_id)
    );
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
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_viewer uuid := auth.uid();
  v_profile_id uuid;
  v_privacy text;
BEGIN
  IF v_viewer IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  SELECT p.id, p.photo_privacy
  INTO v_profile_id, v_privacy
  FROM public.profiles p
  WHERE (p.user_id = p_owner_id OR p.id = p_owner_id)
    AND (p.user_id = v_viewer OR p.visibility = 'visible')
    AND (
      p.user_id = v_viewer
      OR NOT EXISTS (
        SELECT 1 FROM public.blocks owner_block
        WHERE owner_block.blocker_id = p.user_id
          AND owner_block.blocked_id = v_viewer
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
      JOIN public.profiles owner_profile ON owner_profile.id = v_profile_id
      WHERE m.status = 'active'
        AND (
          (m.user_a = v_viewer AND m.user_b = owner_profile.user_id)
          OR (m.user_b = v_viewer AND m.user_a = owner_profile.user_id)
        )
    ),
    (
      SELECT par.status
      FROM public.photo_access_requests par
      JOIN public.profiles owner_profile ON owner_profile.id = v_profile_id
      WHERE par.requester_id = v_viewer
        AND par.owner_id = owner_profile.user_id
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

-- CREATE OR REPLACE keeps existing grants; restate them so a fresh database
-- matches production (members and the service role only).
REVOKE ALL ON FUNCTION public.get_authorized_member_profiles(uuid[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_member_trust_summaries(uuid[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_discovery_compatibility_preferences(uuid[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_photo_access_context(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_authorized_member_profiles(uuid[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_member_trust_summaries(uuid[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_discovery_compatibility_preferences(uuid[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_photo_access_context(uuid) TO authenticated, service_role;
