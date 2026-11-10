-- "See everyone who viewed your profile" lists viewers through
-- get_authorized_member_profiles, which had no rule for them: a viewer with no
-- interest, match or bookmark was dropped from the list. Photo signing already
-- allows the same members.

DO $$
DECLARE
  v_def text := pg_get_functiondef(
    'public.get_authorized_member_profiles(uuid[])'::regprocedure
  );
  v_anchor text := '-- The blocked-members list names the people you blocked.';
  v_count integer :=
    (length(v_def) - length(replace(v_def, v_anchor, ''))) / length(v_anchor);
BEGIN
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'anchor found % times', v_count;
  END IF;
  v_def := replace(
    v_def,
    v_anchor,
    '-- Premium members see who viewed them this week.' || chr(10) ||
    '      OR (public.has_active_premium(v_me) AND p.visibility = ''visible'' AND EXISTS (SELECT 1 FROM public.profile_views recent_view JOIN public.profiles mine ON mine.id = recent_view.viewed_profile_id WHERE mine.user_id = v_me AND recent_view.viewer_profile_id = p.id AND recent_view.viewed_at >= now() - interval ''7 days'') AND NOT EXISTS (SELECT 1 FROM public.blocks viewer_block WHERE viewer_block.blocker_id = v_me AND viewer_block.blocked_id = p.user_id))' || chr(10) ||
    '      ' || v_anchor
  );
  EXECUTE v_def;
END;
$$;
