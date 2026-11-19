-- Full surnames are shared only between members with an active match.
-- Everyone else sees the first name and the surname's initial ("Abdul A."),
-- which the app explains under the name ("Full surname is shared once you
-- match").
--
-- Before this, three reads sent the full surname outside an active match:
--   1. live_discovery_pool exposed p.last_name in its last_name_initial
--      column, so every Discover card showed the full surname to strangers.
--   2. get_incoming_photo_access_requests showed requesters' full surnames.
--   3. get_chat_inbox and get_guardian_dashboard_v2 kept the full surname
--      after a match ended, expired or was blocked.
-- get_authorized_member_profiles already followed the rule.

-- 1. Discover pool: the initial only. Same columns, types and options.
CREATE OR REPLACE VIEW public.live_discovery_pool
WITH (security_invoker = true) AS
 SELECT p.id AS profile_id,
    p.user_id,
    p.gender,
    p.first_name,
    left(COALESCE(p.last_name, ''::text), 1) AS last_name_initial,
    EXTRACT(year FROM age(p.date_of_birth::timestamp with time zone))::integer AS age,
    c.name AS city_name,
    p.country_code,
    p.city_id,
    p.sect,
    p.deen_level,
    p.profession,
    p.bio,
        CASE
            WHEN p.photo_privacy = 'public'::text THEN primary_photo.storage_path
            ELSE NULL::text
        END AS photo_url,
    photo_totals.photo_count,
    p.photo_privacy,
    p.is_verified,
    p.location,
    p.static_rank_score AS rank_score,
    p.marriage_timeline,
    p.height_cm,
    p.complexion,
    p.mother_tongue,
    p.smoking_habit,
    p.community,
    p.diet_type,
    p.living_expectation,
    p.quran_memorization,
    p.religious_education,
    p.willing_to_relocate,
    p.previously_married,
    p.family_type,
    p.children_count,
    p.education_rank,
    prefs.preferred_age_min,
    prefs.preferred_age_max,
    p.last_active_at,
        CASE
            WHEN p.photo_privacy = 'public'::text THEN primary_photo.blurhash
            ELSE NULL::text
        END AS blurhash
   FROM profiles p
     JOIN users account ON account.id = p.user_id
     JOIN launch_countries market ON market.country_code::text = upper(p.country_code::text) AND market.enabled = true
     LEFT JOIN cities c ON c.id = p.city_id
     LEFT JOIN profile_preferences prefs ON prefs.profile_id = p.id
     JOIN LATERAL ( SELECT count(*)::integer AS photo_count
           FROM photos ph
          WHERE ph.profile_id = p.id AND ph.status = 'active'::text AND ph.admin_approved = true AND ph.nsfw_cleared = true) photo_totals ON photo_totals.photo_count > 0
     JOIN LATERAL ( SELECT ph.id,
            ph.storage_path,
            ph.blurhash
           FROM photos ph
          WHERE ph.profile_id = p.id AND ph.order_index = 0 AND ph.status = 'active'::text AND ph.admin_approved = true AND ph.nsfw_cleared = true
          ORDER BY ph.created_at DESC
         LIMIT 1) primary_photo ON true
  WHERE p.visibility = 'visible'::text AND p.onboarding_completed = true AND p.approved_at IS NOT NULL AND account.deleted_at IS NULL AND COALESCE(account.is_banned, false) = false AND COALESCE(account.is_shadowbanned, false) = false;

-- 2-3. Edit the existing function bodies in place, so nothing else in them
-- changes. Each replacement must match exactly once or the migration stops.
DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  -- Photo access requests: the requester's initial.
  v_def := pg_get_functiondef('public.get_incoming_photo_access_requests()'::regprocedure);
  v_old := E'    coalesce(p.last_name, \'\'),\n';
  v_new := E'    left(coalesce(p.last_name, \'\'), 1),\n';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION 'get_incoming_photo_access_requests: surname line not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);

  -- Chat list: full surname only while the match is active.
  v_def := pg_get_functiondef('public.get_chat_inbox(integer, timestamp with time zone)'::regprocedure);
  v_old := E'      ELSE coalesce(nullif(inbox.last_name, \'\'), \'\') END,\n';
  v_new := E'      WHEN inbox.match_status = \'active\'\n'
        || E'        THEN coalesce(nullif(inbox.last_name, \'\'), \'\')\n'
        || E'      ELSE left(coalesce(inbox.last_name, \'\'), 1) END,\n';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION 'get_chat_inbox: surname line not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);

  -- Guardian dashboard: the other member's full surname only while the
  -- match is active. The ward's own name is unchanged.
  v_def := pg_get_functiondef('public.get_guardian_dashboard_v2(uuid)'::regprocedure);
  v_old := E'nullif(trim(concat_ws(\' \', other_p.first_name, other_p.last_name)), \'\')';
  v_new := E'nullif(trim(concat_ws(\' \', other_p.first_name, CASE WHEN m.status = \'active\' THEN other_p.last_name ELSE nullif(left(coalesce(other_p.last_name, \'\'), 1), \'\') || \'.\' END)), \'\')';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION 'get_guardian_dashboard_v2: other member name not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);
END
$migration$;
