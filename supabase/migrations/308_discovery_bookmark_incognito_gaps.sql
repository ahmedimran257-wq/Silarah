-- Remaining gaps from the 19 Nov 2026 Premium audit.
--
-- 1. get_discovery_feed honoured any gender_pref filter, including the
--    viewer's own gender. Discovery is always opposite gender; gender_pref
--    can only narrow within it.
-- 2. (Bookmark limit: migration 309, applied with the app build that
--    records a view before saving.)
-- 3. process_premium_feature_maintenance switched incognito entitlement off
--    when the stored expiry passed without re-checking Premium, so a grant
--    that started later turned incognito off early. It now re-syncs from
--    has_active_premium.

DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  -- 1. Opposite gender always; gender_pref narrows within it.
  v_def := pg_get_functiondef('public.get_discovery_feed'::regproc);
  v_old := E'        (v_gender_pref IS NULL AND lower(dp.gender::text) <> lower(v_viewer_gender))\n'
        || E'        OR lower(dp.gender::text) = v_gender_pref\n';
  v_new := E'        lower(dp.gender::text) <> lower(v_viewer_gender)\n'
        || E'        AND (v_gender_pref IS NULL OR lower(dp.gender::text) = v_gender_pref)\n';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION 'get_discovery_feed: gender condition not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);

  -- 3. Incognito expiry re-checks real Premium.
  v_def := pg_get_functiondef('private.process_premium_feature_maintenance(integer)'::regprocedure);
  v_old := E'    UPDATE private.premium_privacy_settings settings\n'
        || E'    SET entitlement_active = false, updated_at = now()\n'
        || E'    WHERE settings.user_id = v_row.user_id;\n'
        || E'    PERFORM private.touch_member_discovery_segment(v_row.user_id);\n';
  v_new := E'    -- Re-sync from has_active_premium: a grant that started after the\n'
        || E'    -- stored expiry keeps incognito on; a real lapse turns it off.\n'
        || E'    PERFORM private.sync_incognito_entitlement(v_row.user_id);\n';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION 'process_premium_feature_maintenance: expiry update not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);
END
$migration$;
