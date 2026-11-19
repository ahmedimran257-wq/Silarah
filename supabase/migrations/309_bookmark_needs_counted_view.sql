-- APPLY TOGETHER WITH THE APP BUILD AFTER 42053 (the one whose Discover
-- bookmark records a view first). Applied to staging on 19 Nov 2026; not yet
-- on production, because build 42053 can save the first Discover card before
-- counting it, and that save would fail.
--
-- can_bookmark_member let a member save any live discovery profile without a
-- recorded view, and get_authorized_member_profiles then returned the full
-- profile through the bookmark: free members could read 30 extra full
-- profiles a day around the 15-profile limit. Saving now needs a profile
-- viewed today, an interest or a match; the app records the view first, so
-- saving from a Discover card counts like opening it.

DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  -- No bookmark straight from the pool without a counted view.
  v_def := pg_get_functiondef('public.can_bookmark_member(uuid)'::regprocedure);
  v_old := E'      AND s.viewed_on = current_date\n'
        || E'  ) OR EXISTS (\n'
        || E'    SELECT 1\n'
        || E'    FROM public.live_discovery_pool candidate\n'
        || E'    JOIN public.profiles viewer ON viewer.user_id = v_me\n'
        || E'    WHERE candidate.user_id = p_target\n'
        || E'      AND viewer.visibility = \'visible\'\n'
        || E'      AND coalesce(viewer.onboarding_completed, false) = true\n'
        || E'      AND viewer.approved_at IS NOT NULL\n'
        || E'      AND lower(candidate.gender::text) <> lower(viewer.gender::text)\n'
        || E'  );\n';
  v_new := E'      AND s.viewed_on = current_date\n'
        || E'  );\n';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION 'can_bookmark_member: pool branch not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);

END
$migration$;
