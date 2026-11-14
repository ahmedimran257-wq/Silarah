-- Staff tools that the console was missing: take down a published photo,
-- manage the chat word filter, message one member, keep private case notes,
-- review referral rewards, remove a guardian link and produce exports.
-- Every write is limited to the right staff roles and written to the audit log.

-- 1. Take down a published photo (copyright, impersonation, rule breaks) ----
CREATE OR REPLACE FUNCTION public.admin_remove_member_photo(p_photo_id uuid, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_photo public.photos%ROWTYPE;
  v_user_id uuid;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator']) THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  IF v_reason IS NULL OR char_length(v_reason) < 6 THEN
    RAISE EXCEPTION 'A reason of at least 6 characters is required' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_photo FROM public.photos WHERE id = p_photo_id FOR UPDATE;
  IF NOT FOUND OR v_photo.status NOT IN ('active', 'pending_review', 'rejected') THEN
    RAISE EXCEPTION 'This photo is already removed' USING ERRCODE = 'P0001';
  END IF;
  SELECT user_id INTO v_user_id FROM public.profiles WHERE id = v_photo.profile_id;
  UPDATE public.photos
  SET status = 'deletion_pending', admin_approved = false
  WHERE id = p_photo_id;
  UPDATE public.photo_moderation_queue
  SET status = 'rejected'
  WHERE photo_id = p_photo_id AND status = 'pending_review';
  INSERT INTO private.storage_deletion_jobs(bucket_id, storage_path, photo_id, user_id, reason)
  VALUES ('profile-photos', v_photo.storage_path, v_photo.id, v_user_id, 'staff_removed')
  ON CONFLICT (bucket_id, storage_path) DO UPDATE
    SET status = 'pending', next_attempt_at = now(), lease_token = NULL;
  IF v_photo.order_index = 0 THEN
    UPDATE public.profiles SET visibility = 'paused'
    WHERE id = v_photo.profile_id AND visibility = 'visible';
  END IF;
  PERFORM public.queue_notification(
    v_user_id,
    'photo_rejected',
    'A photo was removed',
    'One of your photos was removed because it did not meet our photo rules. You can add a different photo at any time.',
    'silarah://photos'
  );
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(), 'photo_removed', v_user_id,
          jsonb_build_object('photo_id', p_photo_id, 'slot', v_photo.order_index, 'reason', v_reason));
  RETURN jsonb_build_object('removed', true, 'mainPhoto', v_photo.order_index = 0);
END;
$$;

-- 2. Chat word filter ---------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_upsert_blocked_term(p_term text, p_severity text, p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_term text := lower(trim(coalesce(p_term, '')));
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator']) THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  IF char_length(v_term) NOT BETWEEN 2 AND 80 THEN
    RAISE EXCEPTION 'A word or phrase must be 2 to 80 characters' USING ERRCODE = '22023';
  END IF;
  IF p_severity NOT IN ('block', 'flag') THEN
    RAISE EXCEPTION 'Choose block or flag' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.chat_blocked_terms(term, severity, reason)
  VALUES (v_term, p_severity, nullif(left(trim(coalesce(p_reason, '')), 200), ''))
  ON CONFLICT (term) DO UPDATE SET severity = EXCLUDED.severity, reason = EXCLUDED.reason;
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (auth.uid(), public.current_admin_role(), 'chat_term_saved',
          jsonb_build_object('term', v_term, 'severity', p_severity));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_delete_blocked_term(p_term text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator']) THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.chat_blocked_terms WHERE term = lower(trim(coalesce(p_term, '')));
  IF NOT FOUND THEN
    RETURN false;
  END IF;
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (auth.uid(), public.current_admin_role(), 'chat_term_removed',
          jsonb_build_object('term', lower(trim(p_term))));
  RETURN true;
END;
$$;

-- 3. Message one member -------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_send_member_notification(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_deep_link text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_title text := nullif(trim(coalesce(p_title, '')), '');
  v_body text := nullif(trim(coalesce(p_body, '')), '');
  v_link text := nullif(trim(coalesce(p_deep_link, '')), '');
  v_recent integer;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator', 'support']) THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  IF v_title IS NULL OR char_length(v_title) > 80 THEN
    RAISE EXCEPTION 'The title must be 1 to 80 characters' USING ERRCODE = '22023';
  END IF;
  IF v_body IS NULL OR char_length(v_body) NOT BETWEEN 10 AND 300 THEN
    RAISE EXCEPTION 'The message must be 10 to 300 characters' USING ERRCODE = '22023';
  END IF;
  IF v_link IS NOT NULL AND v_link NOT IN (
    'silarah://profile', 'silarah://complete-profile', 'silarah://photos',
    'silarah://verify', 'silarah://help-support', 'silarah://subscription',
    'silarah://notifications', 'silarah://discover'
  ) THEN
    RAISE EXCEPTION 'Choose one of the listed app screens' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id AND deletion_status = 'active') THEN
    RAISE EXCEPTION 'This member cannot receive messages' USING ERRCODE = 'P0001';
  END IF;
  SELECT count(*) INTO v_recent FROM public.admin_audit_log
  WHERE admin_id = auth.uid() AND action_type = 'member_notified'
    AND created_at > now() - interval '1 hour';
  IF v_recent >= 30 THEN
    RAISE EXCEPTION 'You have sent 30 member messages this hour. Try again later' USING ERRCODE = 'P0001';
  END IF;
  PERFORM public.queue_notification(p_user_id, 'admin_announcement', v_title, v_body, v_link);
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(), 'member_notified', p_user_id,
          jsonb_build_object('title', v_title, 'body', v_body, 'deep_link', v_link));
END;
$$;

-- 4. Private staff case notes -------------------------------------------------
CREATE TABLE IF NOT EXISTS public.admin_member_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  author_id uuid NOT NULL,
  body text NOT NULL CHECK (char_length(body) BETWEEN 3 AND 2000),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS admin_member_notes_user ON public.admin_member_notes (user_id, created_at DESC);
ALTER TABLE public.admin_member_notes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_member_notes FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_add_member_note(p_user_id uuid, p_body text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_body text := nullif(trim(coalesce(p_body, '')), '');
  v_id uuid;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator', 'support']) THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  IF v_body IS NULL OR char_length(v_body) NOT BETWEEN 3 AND 2000 THEN
    RAISE EXCEPTION 'A note must be 3 to 2000 characters' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'User not found' USING ERRCODE = 'P0002';
  END IF;
  INSERT INTO public.admin_member_notes(user_id, author_id, body)
  VALUES (p_user_id, auth.uid(), v_body) RETURNING id INTO v_id;
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(), 'member_note_added', p_user_id,
          jsonb_build_object('note_id', v_id));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_member_notes(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator', 'support']) THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  RETURN coalesce((
    SELECT jsonb_agg(jsonb_build_object(
      'id', n.id, 'body', n.body, 'createdAt', n.created_at,
      'author', public.mask_admin_email(a.email),
      'authorRole', m.role
    ) ORDER BY n.created_at DESC)
    FROM public.admin_member_notes n
    LEFT JOIN auth.users a ON a.id = n.author_id
    LEFT JOIN public.admin_memberships m ON m.user_id = n.author_id
    WHERE n.user_id = p_user_id
  ), '[]'::jsonb);
END;
$$;

-- 5. Referral rewards -------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_referral_overview(p_limit integer DEFAULT 100)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'support']) THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  RETURN jsonb_build_object(
    'totals', jsonb_build_object(
      'referrals', (SELECT count(*) FROM public.referrals),
      'rewarded', (SELECT count(*) FROM public.referrals WHERE reward_granted),
      'activeGrants', (SELECT count(*) FROM public.promotional_premium_grants
                       WHERE starts_at <= now() AND expires_at > now())
    ),
    'referrals', coalesce((
      SELECT jsonb_agg(item ORDER BY item->>'createdAt' DESC) FROM (
        SELECT jsonb_build_object(
          'id', r.id,
          'createdAt', r.created_at,
          'referrerId', r.referrer_id,
          'referrer', (SELECT public.mask_admin_email(u.email) FROM public.users u WHERE u.id = r.referrer_id),
          'referredId', r.referred_id,
          'referred', (SELECT public.mask_admin_email(u.email) FROM public.users u WHERE u.id = r.referred_id),
          'rewarded', r.reward_granted,
          'rewardType', r.reward_type,
          'grants', coalesce((
            SELECT jsonb_agg(jsonb_build_object(
              'id', g.id, 'role', g.beneficiary_role,
              'startsAt', g.starts_at, 'expiresAt', g.expires_at,
              'active', g.starts_at <= now() AND g.expires_at > now()))
            FROM public.promotional_premium_grants g WHERE g.referral_id = r.id
          ), '[]'::jsonb)
        ) AS item
        FROM public.referrals r
        ORDER BY r.created_at DESC
        LIMIT least(greatest(p_limit, 1), 500)
      ) rows
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_end_referral_grant(p_grant_id uuid, p_reason text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_user uuid;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'Super admin authorization required' USING ERRCODE = '42501';
  END IF;
  IF v_reason IS NULL OR char_length(v_reason) < 6 THEN
    RAISE EXCEPTION 'A reason of at least 6 characters is required' USING ERRCODE = '22023';
  END IF;
  UPDATE public.promotional_premium_grants
  SET expires_at = greatest(starts_at + interval '1 second', now())
  WHERE id = p_grant_id AND expires_at > now()
  RETURNING user_id INTO v_user;
  IF v_user IS NULL THEN
    RETURN false;
  END IF;
  PERFORM private.sync_incognito_entitlement(v_user);
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(), 'referral_grant_ended', v_user,
          jsonb_build_object('grant_id', p_grant_id, 'reason', v_reason));
  RETURN true;
END;
$$;

-- 6. Remove a guardian link ---------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_remove_guardian_link(p_user_id uuid, p_reason text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_guardian uuid;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator']) THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  IF v_reason IS NULL OR char_length(v_reason) < 6 THEN
    RAISE EXCEPTION 'A reason of at least 6 characters is required' USING ERRCODE = '22023';
  END IF;
  SELECT guardian_user_id INTO v_guardian FROM public.profiles WHERE user_id = p_user_id FOR UPDATE;
  IF v_guardian IS NULL THEN
    RETURN false;
  END IF;
  UPDATE public.profiles
  SET guardian_user_id = NULL, guardian_mode = 'none'
  WHERE user_id = p_user_id;
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(), 'guardian_link_removed', p_user_id,
          jsonb_build_object('guardian_id', v_guardian, 'reason', v_reason));
  RETURN true;
END;
$$;

-- 7. Exports ------------------------------------------------------------------
-- Records the request through admin_request_data_export (purpose and audit),
-- then returns the rows. Member exports carry masked emails only.
CREATE OR REPLACE FUNCTION public.admin_export_rows(p_export_type text, p_purpose text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_rows jsonb;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'Super admin authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_export_type NOT IN ('users', 'reports', 'audit') THEN
    RAISE EXCEPTION 'Unsupported export type' USING ERRCODE = '22023';
  END IF;
  PERFORM public.admin_request_data_export(p_export_type, p_purpose, 5000);
  IF p_export_type = 'users' THEN
    SELECT coalesce(jsonb_agg(row_data), '[]'::jsonb) INTO v_rows FROM (
      SELECT jsonb_build_object(
        'member_id', u.id,
        'email_masked', public.mask_admin_email(u.email),
        'joined_at', u.created_at,
        'gender', u.gender,
        'country', u.country_code,
        'onboarding_completed', u.onboarding_completed,
        'subscription_status', u.subscription_status,
        'banned', coalesce(u.is_banned, false),
        'deletion_status', u.deletion_status,
        'profile_visibility', p.visibility
      ) AS row_data
      FROM public.users u LEFT JOIN public.profiles p ON p.user_id = u.id
      ORDER BY u.created_at DESC LIMIT 5000
    ) rows;
  ELSIF p_export_type = 'reports' THEN
    SELECT coalesce(jsonb_agg(row_data), '[]'::jsonb) INTO v_rows FROM (
      SELECT jsonb_build_object(
        'report_id', r.id, 'created_at', r.created_at, 'reason', r.reason,
        'status', r.status, 'reporter_id', r.reporter_id,
        'reported_member_id', r.reported_user_id,
        'reporter_trust_score', r.reporter_trust_score
      ) AS row_data
      FROM public.reports r ORDER BY r.created_at DESC LIMIT 5000
    ) rows;
  ELSE
    SELECT coalesce(jsonb_agg(row_data), '[]'::jsonb) INTO v_rows FROM (
      SELECT jsonb_build_object(
        'created_at', l.created_at, 'action', l.action_type,
        'staff_id', l.admin_id, 'staff_role', l.actor_role,
        'member_id', l.target_user_id
      ) AS row_data
      FROM public.admin_audit_log l ORDER BY l.created_at DESC LIMIT 5000
    ) rows;
  END IF;
  RETURN v_rows;
END;
$$;

DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.admin_remove_member_photo(uuid, text)',
    'public.admin_upsert_blocked_term(text, text, text)',
    'public.admin_delete_blocked_term(text)',
    'public.admin_send_member_notification(uuid, text, text, text)',
    'public.admin_add_member_note(uuid, text)',
    'public.admin_member_notes(uuid)',
    'public.admin_referral_overview(integer)',
    'public.admin_end_referral_grant(uuid, text)',
    'public.admin_remove_guardian_link(uuid, text)',
    'public.admin_export_rows(text, text)'
  ] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f);
  END LOOP;
END;
$$;
