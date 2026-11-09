-- Fixes from the pre-testing audit.
--
-- Function edits patch the live definition on single-line anchors, and raise
-- if an anchor is missing or repeated, so a definition that has drifted stops
-- the migration instead of being half-changed.

CREATE FUNCTION pg_temp.swap(p_def text, p_old text, p_new text)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_count integer :=
    (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
BEGIN
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'anchor found % times: %', v_count, p_old;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END;
$$;

-- ---------------------------------------------------------------------------
-- Photo storage paths begin with the owner's user ID. Members only need these
-- columns; signing runs server-side with the service role.
-- ---------------------------------------------------------------------------
REVOKE SELECT ON public.photos FROM anon, authenticated;
GRANT SELECT (id, profile_id, blurhash, status, admin_approved, nsfw_cleared, order_index)
  ON public.photos TO authenticated;

-- ---------------------------------------------------------------------------
-- A member must not be able to learn they are shadowbanned.
-- ---------------------------------------------------------------------------
REVOKE SELECT ON public.users FROM anon, authenticated;
DO $$
DECLARE
  v_columns text;
BEGIN
  SELECT string_agg(quote_ident(column_name), ', ')
  INTO v_columns
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'users'
    AND column_name NOT IN ('is_shadowbanned', 'shadowbanned_at', 'shadowban_reason');
  EXECUTE format('GRANT SELECT (%s) ON public.users TO authenticated', v_columns);
END;
$$;

-- TRUNCATE ignores row-level security and no client needs it.
DO $$
DECLARE
  v_table text;
BEGIN
  FOR v_table IN
    SELECT quote_ident(c.relname)
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind IN ('r', 'p')
      AND c.relname <> 'spatial_ref_sys'
  LOOP
    EXECUTE format('REVOKE TRUNCATE ON public.%s FROM anon, authenticated', v_table);
  END LOOP;
END;
$$;

-- ---------------------------------------------------------------------------
-- Bookmarks authorise profile and photo reads, so a new one needs a real
-- reason to exist and a daily ceiling.
-- ---------------------------------------------------------------------------
CREATE FUNCTION public.can_bookmark_member(p_target uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_today integer;
BEGIN
  IF v_me IS NULL OR p_target IS NULL OR p_target = v_me THEN
    RETURN false;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.blocks b
    WHERE (b.blocker_id = v_me AND b.blocked_id = p_target)
       OR (b.blocker_id = p_target AND b.blocked_id = v_me)
  ) OR NOT private.can_access_incognito_profile(v_me, p_target) THEN
    RETURN false;
  END IF;

  SELECT count(*)::integer INTO v_today
  FROM public.profile_bookmarks b
  WHERE b.user_id = v_me
    AND b.created_at >= current_date;
  IF v_today >= (CASE WHEN public.has_active_premium(v_me) THEN 300 ELSE 30 END) THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.interests i
    WHERE (i.sender_id = v_me AND i.receiver_id = p_target)
       OR (i.receiver_id = v_me AND i.sender_id = p_target)
  ) OR EXISTS (
    SELECT 1
    FROM public.matches m
    WHERE (m.user_a = v_me AND m.user_b = p_target)
       OR (m.user_b = v_me AND m.user_a = p_target)
  ) OR EXISTS (
    SELECT 1
    FROM public.profile_view_daily_seen s
    JOIN public.profiles seen ON seen.id = s.viewed_profile_id
    WHERE s.viewer_user_id = v_me
      AND seen.user_id = p_target
      AND s.viewed_on = current_date
  ) OR EXISTS (
    SELECT 1
    FROM public.live_discovery_pool candidate
    JOIN public.profiles viewer ON viewer.user_id = v_me
    WHERE candidate.user_id = p_target
      AND viewer.visibility = 'visible'
      AND coalesce(viewer.onboarding_completed, false) = true
      AND viewer.approved_at IS NOT NULL
      AND lower(candidate.gender::text) <> lower(viewer.gender::text)
  );
END;
$$;
REVOKE ALL ON FUNCTION public.can_bookmark_member(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_bookmark_member(uuid) TO authenticated;

DROP POLICY profile_bookmarks_owner_insert ON public.profile_bookmarks;
CREATE POLICY profile_bookmarks_owner_insert ON public.profile_bookmarks
  FOR INSERT TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = user_id
    AND public.can_bookmark_member(saved_user_id)
  );

-- ---------------------------------------------------------------------------
-- Chat content follows the same rule as get_chat_messages: direct reads and
-- Realtime must not get past the Premium or suspension lock.
-- ---------------------------------------------------------------------------
CREATE FUNCTION public.can_read_my_chat_content()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
  SELECT coalesce((
    SELECT u.deleted_at IS NULL
      AND coalesce(u.is_banned, false) = false
      AND (u.messaging_suspended_until IS NULL OR u.messaging_suspended_until <= now())
      AND (u.gender = 'female' OR public.has_active_premium(u.id))
    FROM public.users u
    WHERE u.id = auth.uid()
  ), false);
$$;
REVOKE ALL ON FUNCTION public.can_read_my_chat_content() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_read_my_chat_content() TO authenticated;

DROP POLICY messages_select ON public.messages;
CREATE POLICY messages_select ON public.messages
  FOR SELECT TO authenticated
  USING (
    (
      (sender_id = (SELECT auth.uid()) OR receiver_id = (SELECT auth.uid()))
      AND (SELECT public.can_read_my_chat_content())
    )
    OR EXISTS (
      SELECT 1
      FROM public.guardian_chat_mirrors gcm
      WHERE gcm.match_id = messages.match_id
        AND gcm.guardian_id = (SELECT auth.uid())
        AND public.is_current_guardian_for_ward(gcm.ward_id, gcm.mode)
    )
  );

-- ---------------------------------------------------------------------------
-- Member names and birth dates: initials and age only until there is a match.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_def text := pg_get_functiondef(
    'public.get_authorized_member_profiles(uuid[])'::regprocedure
  );
BEGIN
  v_def := pg_temp.swap(v_def,
    $old$'last_name', p.last_name,$old$,
    $new$'last_name', CASE WHEN p.user_id = v_me OR p.guardian_user_id = v_me OR EXISTS (SELECT 1 FROM public.matches lm WHERE lm.status = 'active' AND ((lm.user_a = v_me AND lm.user_b = p.user_id) OR (lm.user_b = v_me AND lm.user_a = p.user_id))) THEN p.last_name END,$new$);
  v_def := pg_temp.swap(v_def,
    $old$WHERE b.user_id = v_me AND b.saved_user_id = p.user_id$old$,
    $new$WHERE b.user_id = v_me AND b.saved_user_id = p.user_id AND p.visibility = 'visible'$new$);
  EXECUTE v_def;
END;
$$;

DO $$
DECLARE
  v_def text := pg_get_functiondef(
    'public.get_my_profile_viewers(integer)'::regprocedure
  );
BEGIN
  v_def := pg_temp.swap(v_def,
    $old$viewer.last_name::text,$old$,
    $new$left(coalesce(viewer.last_name::text, ''), 1) AS last_name,$new$);
  v_def := pg_temp.swap(v_def,
    $old$viewer.date_of_birth,$old$,
    $new$NULL::date AS date_of_birth,$new$);
  EXECUTE v_def;
END;
$$;

-- ---------------------------------------------------------------------------
-- 'hidden' is not a valid visibility, so deleting a primary photo always
-- rolled back. Never overwrite a suspended or deactivated profile.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_def text := pg_get_functiondef(
    'public.request_profile_photo_deletion(uuid,integer)'::regprocedure
  );
BEGIN
  v_def := pg_temp.swap(v_def,
    $old$SET visibility = 'hidden'$old$,
    $new$SET visibility = 'paused'$new$);
  v_def := pg_temp.swap(v_def,
    $old$WHERE id = v_profile_id;$old$,
    $new$WHERE id = v_profile_id AND visibility = 'visible';$new$);
  EXECUTE v_def;
END;
$$;

-- ---------------------------------------------------------------------------
-- These references blocked the final delete in the account purge.
-- ---------------------------------------------------------------------------
ALTER TABLE public.referrals
  DROP CONSTRAINT referrals_referrer_id_fkey,
  ADD CONSTRAINT referrals_referrer_id_fkey
    FOREIGN KEY (referrer_id) REFERENCES public.users(id) ON DELETE CASCADE,
  DROP CONSTRAINT referrals_referred_id_fkey,
  ADD CONSTRAINT referrals_referred_id_fkey
    FOREIGN KEY (referred_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.matches
  DROP CONSTRAINT matches_guardian_approved_by_fkey,
  ADD CONSTRAINT matches_guardian_approved_by_fkey
    FOREIGN KEY (guardian_approved_by) REFERENCES public.users(id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- Silarah is 18+ only. The app checks this too; the server must not rely on it.
-- ---------------------------------------------------------------------------
CREATE FUNCTION public.enforce_profile_adult()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $$
BEGIN
  IF NEW.date_of_birth IS NOT NULL
    AND (TG_OP = 'INSERT' OR NEW.date_of_birth IS DISTINCT FROM OLD.date_of_birth)
    AND NEW.date_of_birth > (current_date - interval '18 years')::date THEN
    RAISE EXCEPTION 'member_must_be_adult' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.enforce_profile_adult() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER trg_enforce_profile_adult
  BEFORE INSERT OR UPDATE OF date_of_birth ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.enforce_profile_adult();

-- ---------------------------------------------------------------------------
-- Profiles already seen today do not use up the daily allowance again. The
-- old LIMIT let a reload refill the page with them and hide new profiles.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_def text := pg_get_functiondef(
    'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure
  );
BEGIN
  v_def := pg_temp.swap(v_def,
    $old$FROM ranked r$old$,
    $new$FROM (SELECT page.*, CASE WHEN page.seen_today THEN 0 ELSE row_number() OVER (PARTITION BY page.seen_today ORDER BY page.recommendation_score DESC, page.profile_id DESC) END AS new_rank FROM (SELECT ranked.*, EXISTS (SELECT 1 FROM public.profile_view_daily_seen today WHERE today.viewer_user_id = p_viewer_id AND today.viewed_profile_id = ranked.profile_id AND today.viewed_on = current_date) AS seen_today FROM ranked WHERE p_cursor_score IS NULL OR ranked.recommendation_score < p_cursor_score OR (ranked.recommendation_score = p_cursor_score AND ranked.profile_id < p_cursor_id)) page) r$new$);
  v_def := pg_temp.swap(v_def,
    $old$WHERE p_cursor_score IS NULL$old$ || chr(10) || $old$    OR r.recommendation_score < p_cursor_score$old$,
    $new$WHERE (r.seen_today OR r.new_rank <= v_remaining) AND (p_cursor_score IS NULL$new$ || chr(10) || $new$    OR r.recommendation_score < p_cursor_score$new$);
  v_def := pg_temp.swap(v_def,
    $old$ORDER BY r.recommendation_score DESC, r.profile_id DESC$old$,
    $new$) ORDER BY r.recommendation_score DESC, r.profile_id DESC$new$);
  v_def := pg_temp.swap(v_def,
    $old$LIMIT least(v_page_size, v_remaining);$old$,
    $new$LIMIT v_page_size;$new$);
  EXECUTE v_def;
END;
$$;

-- ---------------------------------------------------------------------------
-- With no messages there is no last sender, so only user_b was warned.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_def text := pg_get_functiondef('public.expire_stale_matches()'::regprocedure);
BEGIN
  v_def := pg_temp.swap(v_def,
    $old$CASE WHEN m.user_a != msg_sender THEN m.user_a ELSE m.user_b END,$old$,
    $new$recipient.user_id,$new$);
  v_def := pg_temp.swap(v_def,
    $old$LEFT JOIN LATERAL ($old$,
    $new$CROSS JOIN LATERAL (VALUES (m.user_a), (m.user_b)) recipient(user_id) LEFT JOIN LATERAL ($new$);
  EXECUTE v_def;
END;
$$;

-- ---------------------------------------------------------------------------
-- A refund and its expiry arrive milliseconds apart. If the expiry wins the
-- row lock the refund is stale for access, but the member still gets its email.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_def text := pg_get_functiondef(
    'public.apply_revenuecat_subscription_event(uuid,text,text,bigint,text,timestamptz,text,text,numeric,timestamptz)'::regprocedure
  );
BEGIN
  v_def := pg_temp.swap(v_def,
    $old$IF p_event_timestamp_ms <= coalesce(v_last_ts, 0) THEN$old$,
    $new$IF p_event_timestamp_ms <= coalesce(v_last_ts, 0) THEN IF p_event_type = 'REFUND' THEN INSERT INTO public.transactional_email_outbox(dedupe_key, user_id, email_type, event_type, event_timestamp_ms, payload) VALUES (v_dedupe_key, p_user_id, 'subscription', p_event_type, p_event_timestamp_ms, jsonb_strip_nulls(jsonb_build_object('provider_event_id', p_provider_event_id, 'product_id', p_product_id, 'currency', p_currency, 'price', p_price, 'expires_at', p_event_expires_at))) ON CONFLICT (dedupe_key) DO NOTHING; END IF;$new$);
  EXECUTE v_def;
END;
$$;
