-- The on-device NSFW score comes from the client, so a modified app could
-- report a clean score and publish instantly. A photo from a device that App
-- Check cannot attest is held for staff review instead.

DO $$
DECLARE
  v_def text := pg_get_functiondef(
    'public.finalize_profile_photo_upload(uuid,text,text,integer,text,numeric)'::regprocedure
  );
  v_new_def text;
BEGIN
  v_new_def := replace(
    v_def,
    'p_client_nsfw_score numeric DEFAULT 0)',
    'p_client_nsfw_score numeric DEFAULT 0, p_device_attested boolean DEFAULT true)'
  );
  v_new_def := replace(
    v_new_def,
    'v_flagged := v_score > 0.50;',
    'v_flagged := v_score > 0.50 OR NOT coalesce(p_device_attested, false);'
  );
  v_new_def := replace(
    v_new_def,
    'CASE WHEN v_flagged THEN ''explicit_content'' ELSE ''unreviewed_upload'' END',
    'CASE WHEN v_score > 0.50 THEN ''explicit_content'' ELSE ''unreviewed_upload'' END'
  );
  IF v_new_def = v_def
    OR position('p_device_attested boolean' IN v_new_def) = 0
    OR position('NOT coalesce(p_device_attested' IN v_new_def) = 0
    OR position('CASE WHEN v_flagged THEN ''explicit_content''' IN v_new_def) > 0 THEN
    RAISE EXCEPTION 'finalize_profile_photo_upload definition has drifted';
  END IF;

  DROP FUNCTION public.finalize_profile_photo_upload(uuid, text, text, integer, text, numeric);
  EXECUTE v_new_def;
END;
$$;

REVOKE ALL ON FUNCTION public.finalize_profile_photo_upload(uuid, text, text, integer, text, numeric, boolean)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_profile_photo_upload(uuid, text, text, integer, text, numeric, boolean)
  TO service_role;
