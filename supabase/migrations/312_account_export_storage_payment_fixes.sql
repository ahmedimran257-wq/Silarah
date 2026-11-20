-- 312: account export, account standing, storage and payment fixes.
--
-- Production and staging differ in download_my_data and sync_my_user (staging
-- carries a newer policy/consent version). Those two are therefore NOT
-- rewritten here: download_my_data is untouched and sync_my_user is edited in
-- place. Every in-place edit raises unless its anchor occurs exactly once, so
-- a drifted definition aborts the whole migration instead of half-applying.

-- ---------------------------------------------------------------------------
-- Shared schema
-- ---------------------------------------------------------------------------

-- Who scheduled a pending deletion. The deletion_reason prefix ('Staff: ')
-- cannot be trusted because members type their own reason text.
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS deletion_source text;
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_deletion_source_check;
ALTER TABLE public.users ADD CONSTRAINT users_deletion_source_check
  CHECK (deletion_source IS NULL
    OR deletion_source IN ('member', 'email_request', 'staff'));

-- Backfill pending deletions. 'staff'/'email_request' require the matching
-- staff audit row so a member-typed "Staff: ..." reason is not promoted.
UPDATE public.users u
SET deletion_source = CASE
    WHEN coalesce(u.deletion_reason, '') LIKE 'Staff:%' AND EXISTS (
      SELECT 1 FROM public.admin_audit_log l
      WHERE l.target_user_id = u.id
        AND l.action_type IN ('account_deletion_scheduled', 'account_deletion_immediate')
        AND l.created_at >= coalesce(u.deletion_requested_at, '-infinity'::timestamptz) - interval '1 minute'
    ) THEN 'staff'
    WHEN coalesce(u.deletion_reason, '') LIKE 'Email request:%' AND EXISTS (
      SELECT 1 FROM public.admin_audit_log l
      WHERE l.target_user_id = u.id
        AND l.action_type = 'account_deletion_email_request'
    ) THEN 'email_request'
    ELSE 'member'
  END
WHERE u.deletion_status = 'pending_deletion'
  AND u.deletion_source IS NULL;

-- Enforcement tombstones: a salted hash of a banned member's email survives
-- account purge so the same address cannot simply sign up again. Only the
-- hash is kept (no user id, no plain email). Retention: 3 years from the ban
-- or from the banned member's deletion request, under the "abuse prevention /
-- prevent re-registration" basis in the Privacy Policy.
CREATE TABLE IF NOT EXISTS private.enforcement_tombstones (
  email_hash text PRIMARY KEY,
  reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz
);
ALTER TABLE private.enforcement_tombstones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.enforcement_tombstones FROM PUBLIC, anon, authenticated;

-- Salt lives in Vault (one random value per environment). If the secret is
-- ever missing the fixed fallback 'silarah-enforcement-v1' is used. Never
-- rotate or recreate the secret without rehashing the table: old hashes would
-- silently stop matching.
DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM vault.secrets WHERE name = 'silarah_enforcement_email_salt'
  ) THEN
    PERFORM vault.create_secret(
      encode(sha256(convert_to(
        gen_random_uuid()::text || gen_random_uuid()::text || clock_timestamp()::text,
        'UTF8')), 'hex'),
      'silarah_enforcement_email_salt',
      'Salt for private.enforcement_tombstones email hashes. Do not rotate without rehashing.'
    );
  END IF;
END
$do$;

CREATE OR REPLACE FUNCTION private.enforcement_email_hash(p_email text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT CASE
    WHEN nullif(lower(btrim(coalesce(p_email, ''))), '') IS NULL THEN NULL
    ELSE encode(sha256(convert_to(
      coalesce(
        (SELECT s.decrypted_secret FROM vault.decrypted_secrets s
         WHERE s.name = 'silarah_enforcement_email_salt' LIMIT 1),
        'silarah-enforcement-v1'
      ) || ':' || lower(btrim(p_email)),
      'UTF8')), 'hex')
  END;
$function$;

CREATE OR REPLACE FUNCTION private.record_enforcement_tombstone(p_user_id uuid, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_hash text;
BEGIN
  SELECT private.enforcement_email_hash(coalesce(au.email, u.email))
  INTO v_hash
  FROM public.users u
  LEFT JOIN auth.users au ON au.id = u.id
  WHERE u.id = p_user_id;

  IF v_hash IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO private.enforcement_tombstones AS t (email_hash, reason, expires_at)
  VALUES (v_hash, p_reason, now() + interval '3 years')
  ON CONFLICT (email_hash) DO UPDATE
  SET expires_at = CASE
        WHEN t.expires_at IS NULL OR EXCLUDED.expires_at IS NULL THEN NULL
        ELSE greatest(t.expires_at, EXCLUDED.expires_at)
      END;
END;
$function$;

CREATE OR REPLACE FUNCTION private.clear_enforcement_tombstone(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  DELETE FROM private.enforcement_tombstones t
  WHERE t.email_hash = (
    SELECT private.enforcement_email_hash(coalesce(au.email, u.email))
    FROM public.users u
    LEFT JOIN auth.users au ON au.id = u.id
    WHERE u.id = p_user_id
  );
END;
$function$;

REVOKE ALL ON FUNCTION private.enforcement_email_hash(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.record_enforcement_tombstone(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.clear_enforcement_tombstone(uuid) FROM PUBLIC, anon, authenticated;

-- Members banned before this migration get a tombstone too.
DO $do$
DECLARE
  v_id uuid;
BEGIN
  FOR v_id IN SELECT u.id FROM public.users u WHERE coalesce(u.is_banned, false) LOOP
    PERFORM private.record_enforcement_tombstone(v_id, 'admin_ban');
  END LOOP;
END
$do$;

-- ---------------------------------------------------------------------------
-- 1. Personal data export
-- ---------------------------------------------------------------------------
-- (a) Received message text is withheld when the member cannot read chat
--     content in the app (can_read_my_chat_content() false, evaluated for
--     auth.uid()); otherwise the export would be a free paywall bypass.
--     Sent messages keep their text. 'translations' and 'safety_reason' are
--     withheld together with 'content' because they repeat or describe it.
-- (b) Inbound profile views are exported as a count only. Viewer identities
--     and times are a Premium feature; outbound views (the member's own
--     activity) stay itemised.
-- (c) Internal moderation, ranking, anti-abuse and secret columns removed:
--     users: is_banned, banned_at, banned_reason, is_shadowbanned,
--       shadowbanned_at, shadowban_reason, last_billing_event_ts
--     profiles: static_rank_score, suspended_reason, verification_challenge,
--       badge_pose_sequence, verification_attempts,
--       guardian_invitation_token_hash, guardian_invitation_attempts,
--       guardian_invitation_locked_until, guardian_phone_encrypted,
--       guardian_key_version
--     photos: moderated_by (staff identity), nsfw_score, nsfw_category,
--       moderation_source
--     reports_created: reporter_trust_score
--     (The old code subtracted names that do not exist, so these leaked.)
-- Cooldown raised from 10 minutes to 24 hours (it was a simple constant).
-- The error keeps the 'export_rate_limited' prefix the app matches on.
CREATE OR REPLACE FUNCTION private.build_personal_data_export(p_client_version text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '60s'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile_id uuid;
  v_request_id uuid;
  v_export jsonb;
  v_row_count integer := 0;
  v_can_read_received boolean := false;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = v_user_id AND u.deletion_status <> 'purged'
  ) THEN
    RAISE EXCEPTION 'account_not_available' USING ERRCODE = 'P0001';
  END IF;

  -- Keep repeated taps and automated scraping from generating expensive full
  -- account snapshots. A failed request can be retried immediately.
  IF EXISTS (
    SELECT 1
    FROM public.data_export_requests der
    WHERE der.user_id = v_user_id
      AND der.status = 'completed'
      AND der.requested_at > now() - interval '24 hours'
  ) THEN
    RAISE EXCEPTION 'export_rate_limited_24_hours' USING ERRCODE = 'P0001';
  END IF;

  -- Same rule as the chat screen: received message text only for members who
  -- may read chat content right now.
  v_can_read_received := coalesce(public.can_read_my_chat_content(), false);

  INSERT INTO public.data_export_requests(user_id, client_version)
  VALUES (v_user_id, nullif(left(trim(coalesce(p_client_version, '')), 80), ''))
  RETURNING id INTO v_request_id;

  SELECT p.id INTO v_profile_id
  FROM public.profiles p
  WHERE p.user_id = v_user_id;

  SELECT jsonb_build_object(
    'schema_version', '1.1',
    'policy_version', '2.2.0',
    'generated_at', now(),
    'request_id', v_request_id,
    'service', 'Silarah',
    'format_notice',
      'Machine-readable JSON. Dates are ISO-8601. IDs preserve relationships between sections.',
    'scope_notice',
      'This self-service archive contains account data available for direct export. It excludes passwords and OTPs, raw push tokens, temporary verification captures, other members'' confidential reports, staff identities, internal moderation and ranking signals, privileged legal material and anti-abuse methods. Received message text is included only while your account can read chat messages in the app, and profile views you received are summarised as a count. Contact privacy@silarah.com for a verified request concerning an omitted category.',
    'account', coalesce((
      SELECT jsonb_build_object(
        'auth_user_id', au.id,
        'email', au.email,
        'phone', coalesce(au.phone, u.phone),
        'email_confirmed_at', au.email_confirmed_at,
        'phone_confirmed_at', au.phone_confirmed_at,
        'last_sign_in_at', au.last_sign_in_at,
        'auth_created_at', au.created_at,
        'service_account', to_jsonb(u) - ARRAY[
          'last_billing_event_ts',
          'is_banned', 'banned_at', 'banned_reason',
          'is_shadowbanned', 'shadowbanned_at', 'shadowban_reason'
        ]
      )
      FROM public.users u
      LEFT JOIN auth.users au ON au.id = u.id
      WHERE u.id = v_user_id
    ), '{}'::jsonb),
    'profile', coalesce((
      SELECT to_jsonb(p) - ARRAY[
        'static_rank_score', 'suspended_reason',
        'verification_challenge', 'badge_pose_sequence', 'verification_attempts',
        'guardian_invitation_token_hash', 'guardian_invitation_attempts',
        'guardian_invitation_locked_until',
        'guardian_phone_encrypted', 'guardian_key_version'
      ]
      FROM public.profiles p WHERE p.user_id = v_user_id
    ), '{}'::jsonb),
    'partner_preferences', coalesce((
      SELECT to_jsonb(pp)
      FROM public.profile_preferences pp
      WHERE pp.profile_id = v_profile_id
    ), '{}'::jsonb),
    'profile_photos', coalesce((
      SELECT jsonb_agg(
        to_jsonb(ph) - ARRAY[
          'moderated_by', 'nsfw_score', 'nsfw_category', 'moderation_source'
        ]
        ORDER BY ph.order_index, ph.created_at)
      FROM public.photos ph WHERE ph.profile_id = v_profile_id
    ), '[]'::jsonb),
    'interests', coalesce((
      SELECT jsonb_agg(to_jsonb(i) ORDER BY i.created_at)
      FROM public.interests i
      WHERE i.sender_id = v_user_id OR i.receiver_id = v_user_id
    ), '[]'::jsonb),
    'matches', coalesce((
      SELECT jsonb_agg(to_jsonb(m) ORDER BY m.created_at)
      FROM public.matches m
      WHERE m.user_a = v_user_id OR m.user_b = v_user_id
    ), '[]'::jsonb),
    'messages_notice', CASE
      WHEN v_can_read_received THEN
        'Messages you sent and received are included in full.'
      ELSE
        'Messages you sent are included in full. The text of messages you received is withheld (content is null and content_withheld is true) because your account cannot currently read chat messages in the app.'
    END,
    'messages', coalesce((
      SELECT jsonb_agg(
        CASE
          WHEN msg.sender_id = v_user_id OR v_can_read_received THEN
            to_jsonb(msg) || jsonb_build_object('content_withheld', false)
          ELSE
            (to_jsonb(msg) - ARRAY['translations', 'safety_reason'])
              || jsonb_build_object('content', NULL, 'content_withheld', true)
        END
        ORDER BY msg.created_at, msg.id)
      FROM public.messages msg
      JOIN public.matches m ON m.id = msg.match_id
      WHERE m.user_a = v_user_id OR m.user_b = v_user_id
    ), '[]'::jsonb),
    'notifications', coalesce((
      SELECT jsonb_agg(to_jsonb(n) ORDER BY n.created_at)
      FROM public.notifications n WHERE n.user_id = v_user_id
    ), '[]'::jsonb),
    'notification_preferences', coalesce((
      SELECT to_jsonb(np)
      FROM public.notification_prefs np WHERE np.user_id = v_user_id
    ), '{}'::jsonb),
    'consents', coalesce((
      SELECT jsonb_agg(to_jsonb(uc) ORDER BY uc.granted_at)
      FROM public.user_consents uc WHERE uc.user_id = v_user_id
    ), '[]'::jsonb),
    'subscription_events', coalesce((
      SELECT jsonb_agg(to_jsonb(se) ORDER BY se.created_at)
      FROM public.subscription_events se WHERE se.user_id = v_user_id
    ), '[]'::jsonb),
    'devices', '[]'::jsonb,
    'push_registrations', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', ft.id,
        'device_id', ft.device_id,
        'platform', ft.platform,
        'created_at', ft.created_at,
        'updated_at', ft.updated_at,
        'token', '[redacted credential]'
      ) ORDER BY ft.created_at)
      FROM public.user_fcm_tokens ft WHERE ft.user_id = v_user_id
    ), '[]'::jsonb),
    -- Profiles this member viewed.
    'profile_views', coalesce((
      SELECT jsonb_agg(to_jsonb(pv) ORDER BY pv.viewed_at)
      FROM public.profile_views pv
      WHERE pv.viewer_profile_id = v_profile_id
    ), '[]'::jsonb),
    -- Views of this member's profile: a count only, no viewer ids or times.
    'profile_views_received', jsonb_build_object(
      'count', (
        SELECT count(*)
        FROM public.profile_views pv
        WHERE pv.viewed_profile_id = v_profile_id
          AND pv.viewer_profile_id IS DISTINCT FROM v_profile_id
      ),
      'notice',
        'Who viewed your profile, and when, is shown in the app for Premium members and is not part of this archive.'
    ),
    'bookmarks', coalesce((
      SELECT jsonb_agg(to_jsonb(pb) ORDER BY pb.created_at)
      FROM public.profile_bookmarks pb WHERE pb.user_id = v_user_id
    ), '[]'::jsonb),
    'private_shortlist_details', coalesce((
      SELECT jsonb_agg(to_jsonb(details) ORDER BY details.updated_at)
      FROM private.premium_shortlist_details details
      WHERE details.user_id = v_user_id
    ), '[]'::jsonb),
    'premium_privacy_settings', coalesce((
      SELECT to_jsonb(settings)
      FROM private.premium_privacy_settings settings
      WHERE settings.user_id = v_user_id
    ), '{}'::jsonb),
    'blocks_created', coalesce((
      SELECT jsonb_agg(to_jsonb(b) ORDER BY b.created_at)
      FROM public.blocks b WHERE b.blocker_id = v_user_id
    ), '[]'::jsonb),
    'reports_created', coalesce((
      SELECT jsonb_agg(to_jsonb(r) - 'reporter_trust_score' ORDER BY r.created_at)
      FROM public.reports r WHERE r.reporter_id = v_user_id
    ), '[]'::jsonb),
    'message_reports_created', coalesce((
      SELECT jsonb_agg(to_jsonb(mr) ORDER BY mr.created_at)
      FROM public.message_reports mr WHERE mr.reporter_id = v_user_id
    ), '[]'::jsonb),
    'photo_access_requests', coalesce((
      SELECT jsonb_agg(to_jsonb(par) ORDER BY par.created_at)
      FROM public.photo_access_requests par
      WHERE par.requester_id = v_user_id OR par.owner_id = v_user_id
    ), '[]'::jsonb),
    'guardian_sessions', coalesce((
      SELECT jsonb_agg(to_jsonb(gs) ORDER BY gs.created_at)
      FROM public.guardian_sessions gs
      WHERE gs.guardian_id = v_user_id OR gs.ward_id = v_user_id
    ), '[]'::jsonb),
    'guardian_chat_links', coalesce((
      SELECT jsonb_agg(to_jsonb(gcm) ORDER BY gcm.created_at)
      FROM public.guardian_chat_mirrors gcm
      WHERE gcm.guardian_id = v_user_id OR gcm.ward_id = v_user_id
    ), '[]'::jsonb),
    'referrals', coalesce((
      SELECT jsonb_agg(to_jsonb(ref) ORDER BY ref.created_at)
      FROM public.referrals ref
      WHERE ref.referrer_id = v_user_id OR ref.referred_id = v_user_id
    ), '[]'::jsonb),
    'referral_code', coalesce((
      SELECT to_jsonb(rc)
      FROM public.referral_codes rc WHERE rc.owner_id = v_user_id
    ), '{}'::jsonb),
    'photo_verification_history', coalesce((
      SELECT jsonb_agg(
        to_jsonb(pvs)
          - 'neutral_storage_path'
          - 'smile_storage_path'
          - 'blink_storage_path'
          - 'reviewed_by'
          - 'review_checklist'
          - 'purge_last_error'
        ORDER BY pvs.created_at
      )
      FROM public.photo_verification_submissions pvs
      WHERE pvs.user_id = v_user_id
    ), '[]'::jsonb),
    'content_filter_events', coalesce((
      SELECT jsonb_agg(to_jsonb(cv) ORDER BY cv.created_at)
      FROM public.content_violations cv WHERE cv.user_id = v_user_id
    ), '[]'::jsonb)
  ) INTO v_export;

  SELECT coalesce(sum(jsonb_array_length(value)), 0)::integer
  INTO v_row_count
  FROM jsonb_each(v_export)
  WHERE jsonb_typeof(value) = 'array';

  UPDATE public.data_export_requests
  SET status = 'completed',
      completed_at = now(),
      exported_row_count = v_row_count
  WHERE id = v_request_id;

  RETURN v_export;
EXCEPTION
  WHEN OTHERS THEN
    IF v_request_id IS NOT NULL THEN
      UPDATE public.data_export_requests
      SET status = 'failed',
          completed_at = now(),
          error_code = left(SQLSTATE || ':' || SQLERRM, 180)
      WHERE id = v_request_id;
    END IF;
    RAISE;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2/3. sync_my_user, patch_my_user, finalize_signup_and_provision_my_user
-- ---------------------------------------------------------------------------
-- The returned row subtracted column names that do not exist ('ban_reason',
-- 'moderation_reason', 'shadow_banned_at', 'moderated_by'), so the real
-- shadowban and ban fields reached the client; a shadowban must stay silent.
-- The app ignores these results (auth_cubit, locale_cubit,
-- profile_write_service and legal_consent_service only await success);
-- is_banned and every other key are unchanged.
-- patch_my_user keeps its allowlist: the app sends onboarding_step,
-- is_guardian_path, profile_owner_type and onboarding_completed through it
-- (ProfileWriteService._updateUserOnboardingProgress).

DO $do$
DECLARE
  v_def text := pg_get_functiondef('public.sync_my_user(text,text)'::regprocedure);
  v_pat constant text :=
    '''last_billing_event_ts'',\s*''ban_reason'',\s*''moderation_reason'',\s*''shadow_banned_at'',\s*''moderated_by''';
  v_new constant text :=
    '''last_billing_event_ts'', ''is_shadowbanned'', ''shadowbanned_at'', ''shadowban_reason'', ''banned_reason'', ''banned_at''';
BEGIN
  IF (SELECT count(*) FROM regexp_matches(v_def, v_pat, 'g')) <> 1 THEN
    RAISE EXCEPTION '312: sync_my_user return list not found exactly once';
  END IF;
  EXECUTE regexp_replace(v_def, v_pat, v_new);
END
$do$;

CREATE OR REPLACE FUNCTION public.patch_my_user(p_fields jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_row public.users%ROWTYPE;
  v_current public.users%ROWTYPE;
  v_allowed constant text[] := ARRAY[
    'preferred_language', 'timezone', 'country_code', 'gender',
    'is_guardian_path', 'profile_owner_type', 'onboarding_step',
    'onboarding_completed', 'onboarding_profile_for',
    'onboarding_profile_creator_relation', 'onboarding_city_id',
    'onboarding_city_name', 'onboarding_state_name',
    'onboarding_postal_code', 'onboarding_lat', 'onboarding_lng'
  ];
BEGIN
  PERFORM private.assert_jsonb_keys(p_fields, v_allowed);

  SELECT * INTO v_current
  FROM public.users
  WHERE id = v_user_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_not_found' USING ERRCODE = 'P0001';
  END IF;

  IF p_fields ? 'gender'
    AND v_current.onboarding_completed IS TRUE
    AND lower(p_fields->>'gender') IS DISTINCT FROM v_current.gender THEN
    RAISE EXCEPTION 'gender_change_locked' USING ERRCODE = 'P0001';
  END IF;

  SELECT populated.* INTO v_row
  FROM jsonb_populate_record(v_current, p_fields) AS populated;

  UPDATE public.users
  SET preferred_language = v_row.preferred_language,
      timezone = v_row.timezone,
      country_code = v_row.country_code,
      gender = v_row.gender,
      is_guardian_path = v_row.is_guardian_path,
      profile_owner_type = v_row.profile_owner_type,
      onboarding_step = v_row.onboarding_step,
      onboarding_completed = v_row.onboarding_completed,
      onboarding_profile_for = v_row.onboarding_profile_for,
      onboarding_profile_creator_relation =
        v_row.onboarding_profile_creator_relation,
      onboarding_city_id = v_row.onboarding_city_id,
      onboarding_city_name = v_row.onboarding_city_name,
      onboarding_state_name = v_row.onboarding_state_name,
      onboarding_postal_code = v_row.onboarding_postal_code,
      onboarding_lat = v_row.onboarding_lat,
      onboarding_lng = v_row.onboarding_lng
  WHERE id = v_user_id
  RETURNING * INTO v_row;

  -- 312: subtract the real moderation columns (see section comment).
  RETURN to_jsonb(v_row)
    - ARRAY[
      'last_billing_event_ts', 'is_shadowbanned', 'shadowbanned_at',
      'shadowban_reason', 'banned_reason', 'banned_at'
    ];
END;
$function$;

CREATE OR REPLACE FUNCTION public.finalize_signup_and_provision_my_user(p_transaction_id uuid, p_country_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_auth auth.users%ROWTYPE;
  v_row public.users%ROWTYPE;
  v_country text := upper(nullif(trim(p_country_code), ''));
BEGIN
  SELECT * INTO v_auth FROM auth.users WHERE id = v_user_id;
  IF NOT FOUND OR v_auth.email_confirmed_at IS NULL THEN
    RAISE EXCEPTION 'verified_signup_identity_required'
      USING ERRCODE = 'P0001';
  END IF;

  -- The FK requires the member row before consent evidence can be inserted.
  -- Both operations share this transaction: any invalid/expired consent rolls
  -- the provisional member row back completely.
  INSERT INTO public.users (id, email, phone, country_code)
  VALUES (v_user_id, v_auth.email, nullif(v_auth.phone, ''), v_country)
  ON CONFLICT (id) DO NOTHING;

  PERFORM public.finalize_signup_consents(p_transaction_id);

  SELECT * INTO v_row FROM public.users WHERE id = v_user_id;
  -- 312: subtract the real moderation columns (see section comment).
  RETURN to_jsonb(v_row)
    - ARRAY[
      'last_billing_event_ts', 'is_shadowbanned', 'shadowbanned_at',
      'shadowban_reason', 'banned_reason', 'banned_at'
    ];
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4. Profile identity and location
-- ---------------------------------------------------------------------------

-- Date of birth is fixed once onboarding is complete (age filters, adult
-- check, compatibility). The app re-sends the unchanged DOB on every Edit
-- Profile save, so only a real change is rejected. A trigger covers every
-- write path (patch_my_profile, save_basic_identity_step, staff SQL). A
-- verified staff correction can set silarah.allow_identity_correction='yes'
-- for its own transaction. Names stay editable.
CREATE OR REPLACE FUNCTION private.lock_profile_date_of_birth()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  IF OLD.onboarding_completed IS TRUE
    AND NEW.date_of_birth IS DISTINCT FROM OLD.date_of_birth
    AND current_setting('silarah.allow_identity_correction', true)
        IS DISTINCT FROM 'yes'
  THEN
    RAISE EXCEPTION 'date_of_birth_locked' USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.lock_profile_date_of_birth() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_lock_profile_date_of_birth ON public.profiles;
CREATE TRIGGER trg_lock_profile_date_of_birth
  BEFORE UPDATE OF date_of_birth ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION private.lock_profile_date_of_birth();

-- guard_profile_location_mutation exempts current_user 'postgres', which is
-- the role inside every SECURITY DEFINER RPC (patch_my_profile accepts
-- city_id and country_code), so it never protected those paths. This
-- role-independent trigger enforces the invariant that matters on every
-- path, including INSERT: a non-null city_id must belong to the profile's
-- country (cities -> regions.country_code). The RPC-only guard is left as is.
CREATE OR REPLACE FUNCTION private.enforce_profile_city_country()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF NEW.city_id IS NOT NULL
    AND (
      TG_OP = 'INSERT'
      OR NEW.city_id IS DISTINCT FROM OLD.city_id
      OR NEW.country_code IS DISTINCT FROM OLD.country_code
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.cities c
      JOIN public.regions r ON r.id = c.region_id
      WHERE c.id = NEW.city_id
        AND upper(r.country_code::text) = upper(btrim(coalesce(NEW.country_code::text, '')))
    )
  THEN
    RAISE EXCEPTION 'city_country_mismatch' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.enforce_profile_city_country() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_enforce_profile_city_country ON public.profiles;
CREATE TRIGGER trg_enforce_profile_city_country
  BEFORE INSERT OR UPDATE OF city_id, country_code ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION private.enforce_profile_city_country();

-- save_basic_identity_step is the onboarding-only identity writer (called
-- only from OnboardingCubit's basic-identity step and when no profile row
-- exists). After onboarding it would rewrite name, DOB, gender, ownership
-- and location in one go, so it now refuses.
DO $do$
DECLARE
  v_sig constant regprocedure :=
    'public.save_basic_identity_step(text,text,text,text,text,text,text,text,text,text,date,text,integer,text,text,text,text,text,text,text,text,text,numeric,numeric)'::regprocedure;
  v_def text := pg_get_functiondef(v_sig);
  v_old constant text :=
    '  -- Legacy hints are accepted for RPC compatibility; the verified city id is authoritative.';
  v_new constant text :=
    '  -- 312: identity is edited through Edit Profile once onboarding is done.' || chr(10) ||
    '  IF EXISTS (' || chr(10) ||
    '    SELECT 1 FROM public.profiles p' || chr(10) ||
    '    WHERE p.user_id = v_user_id AND p.onboarding_completed IS TRUE' || chr(10) ||
    '  ) THEN' || chr(10) ||
    '    RAISE EXCEPTION ''onboarding_already_completed'' USING ERRCODE = ''P0001'';' || chr(10) ||
    '  END IF;' || chr(10) || chr(10) ||
    v_old;
BEGIN
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION '312: save_basic_identity_step anchor not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);
END
$do$;

-- ---------------------------------------------------------------------------
-- 5. Account deletion: source tracking and cancellation rules
-- ---------------------------------------------------------------------------

DO $do$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  -- Staff scheduling marks the source.
  v_def := pg_get_functiondef('public.admin_schedule_account_deletion(uuid,text,boolean)'::regprocedure);
  v_old := 'deletion_reason = left(''Staff: '' || v_reason, 500),';
  v_new := 'deletion_reason = left(''Staff: '' || v_reason, 500), deletion_source = ''staff'',';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION '312: admin_schedule_account_deletion anchor not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);

  -- A verified email request is the member's own request.
  v_def := pg_get_functiondef('public.admin_record_email_deletion_request(text,timestamp with time zone,text,boolean)'::regprocedure);
  v_old := 'deletion_reason = left(''Email request: '' ||';
  v_new := 'deletion_source = ''email_request'', deletion_reason = left(''Email request: '' ||';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION '312: admin_record_email_deletion_request anchor not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);

  -- Staff cancellation clears the source with the other deletion fields.
  v_def := pg_get_functiondef('public.admin_cancel_account_deletion(uuid,text)'::regprocedure);
  v_old := 'SET deletion_status = ''active'', deletion_reason = NULL,';
  v_new := 'SET deletion_status = ''active'', deletion_reason = NULL, deletion_source = NULL,';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION '312: admin_cancel_account_deletion anchor not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);
END
$do$;

-- A member may undo only their own deletion request. A staff-scheduled
-- deletion, or any deletion of a banned account, is not cancellable by the
-- member (only by a super admin through admin_cancel_account_deletion).
-- Refusal is signalled with false (deletion_not_cancellable), not an
-- exception: AuthCubit treats false as "can no longer be restored" and signs
-- out with a notice, while an exception would leave sign-in retrying.
CREATE OR REPLACE FUNCTION public.cancel_my_account_deletion()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_job_status text;
  v_source text;
  v_banned boolean;
BEGIN
  SELECT j.status
  INTO v_job_status
  FROM private.account_purge_jobs j
  WHERE j.user_id = v_user_id
  FOR UPDATE;

  IF v_job_status IS NOT NULL THEN
    -- Once a purge worker has checked out the account, restoration can no
    -- longer be guaranteed to be complete or safe.
    RETURN false;
  END IF;

  SELECT u.deletion_source, coalesce(u.is_banned, false)
  INTO v_source, v_banned
  FROM public.users u
  WHERE u.id = v_user_id
  FOR UPDATE;

  IF v_source = 'staff' OR coalesce(v_banned, false) THEN
    -- deletion_not_cancellable
    RETURN false;
  END IF;

  UPDATE public.users
  SET deletion_status = 'active',
      deletion_reason = NULL,
      deletion_source = NULL,
      deletion_requested_at = NULL,
      deleted_at = NULL
  WHERE id = v_user_id
    AND deletion_status = 'pending_deletion'
    AND deletion_requested_at > now() - interval '30 days';

  RETURN FOUND;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 6. Deletion of a banned account leaves a tombstone; signup checks it
-- ---------------------------------------------------------------------------

-- A banned member may still delete their account (data rights), but the
-- hashed email is kept so deletion is not a way around the ban.
CREATE OR REPLACE FUNCTION public.request_my_account_deletion(p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_banned boolean;
BEGIN
  SELECT coalesce(u.is_banned, false) INTO v_banned
  FROM public.users u
  WHERE u.id = v_user_id
  FOR UPDATE;

  IF coalesce(v_banned, false) THEN
    PERFORM private.record_enforcement_tombstone(v_user_id, 'banned_account_deleted');
  END IF;

  UPDATE public.users
  SET deletion_status = 'pending_deletion',
      deletion_reason = left(nullif(trim(p_reason), ''), 500),
      deletion_source = 'member',
      deletion_requested_at = now(),
      deleted_at = now()
  WHERE id = v_user_id AND deletion_status = 'active';
END;
$function$;

-- Auth before-user-created hook: existing email-shape and disposable-domain
-- checks are unchanged; a new email whose hash has an unexpired enforcement
-- tombstone is refused. Lookup failures still fail closed (503).
CREATE OR REPLACE FUNCTION public.hook_before_user_created(event jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_email text;
BEGIN
  v_email := lower(trim(coalesce(event->'user'->>'email', '')));

  IF v_email = '' OR position('@' IN v_email) = 0 THEN
    RETURN jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 400,
        'message', 'Please enter a valid email address.'
      )
    );
  END IF;

  IF public.is_disposable_email_domain(v_email) THEN
    RETURN jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 400,
        'message', 'Temporary or disposable email addresses are not allowed. Please use a real personal email address.'
      )
    );
  END IF;

  IF EXISTS (
    SELECT 1
    FROM private.enforcement_tombstones t
    WHERE t.email_hash = private.enforcement_email_hash(v_email)
      AND (t.expires_at IS NULL OR t.expires_at > now())
  ) THEN
    RETURN jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 403,
        'message', 'This email address cannot be used to create a Silarah account. Contact support@silarah.com if you think this is a mistake.'
      )
    );
  END IF;

  RETURN '{}'::jsonb;
EXCEPTION
  WHEN others THEN
    -- Fail closed so fake-account protection is not bypassed during lookup
    -- failures. The message is intentionally user-safe.
    RETURN jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 503,
        'message', 'We could not validate this email address. Please try again.'
      )
    );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 6/7. admin_account_action: ban tombstone, restore rules
-- ---------------------------------------------------------------------------
-- ban: also writes the enforcement tombstone.
-- restore: a moderator can lift a suspension but cannot clear a shadowban
--   (the shadowban stays untouched unless a super admin restores). A super
--   admin restoring a banned account also removes its tombstone.
--   Visibility: no previous visibility is stored anywhere, so restore keeps
--   the existing rule ('visible' with a safe primary photo, else 'paused').
CREATE OR REPLACE FUNCTION public.admin_account_action(p_user_id uuid, p_action text, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_is_banned boolean;
  v_is_shadowbanned boolean;
  v_is_super boolean;
  v_clear_shadowban boolean := false;
  v_has_safe_primary_photo boolean;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  v_is_super := public.is_active_admin(ARRAY['super_admin']);

  IF p_action IN ('ban', 'shadowban') AND NOT v_is_super THEN
    RAISE EXCEPTION 'Super admin authorization required';
  END IF;

  SELECT
    coalesce(u.is_banned, false),
    coalesce(u.is_shadowbanned, false),
    EXISTS (
      SELECT 1
      FROM public.profiles p
      JOIN public.photos ph ON ph.profile_id = p.id
      WHERE p.user_id = p_user_id
        AND ph.order_index = 0
        AND ph.admin_approved = true
        AND ph.nsfw_cleared = true
        AND coalesce(ph.status, 'active') = 'active'
    )
  INTO v_is_banned, v_is_shadowbanned, v_has_safe_primary_photo
  FROM public.users u
  WHERE u.id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  IF p_action = 'suspend' THEN
    UPDATE public.profiles
    SET visibility = 'suspended',
        suspended_reason = coalesce(nullif(trim(p_reason), ''), 'admin_suspension')
    WHERE user_id = p_user_id;

    PERFORM public.queue_notification(
      p_user_id,
      'account_suspended',
      'Profile suspended',
      'Your Silarah profile has been suspended. Contact support if you believe this is a mistake.',
      '/help-support'
    );
  ELSIF p_action = 'restore' THEN
    IF coalesce(v_is_banned, false) AND NOT v_is_super THEN
      RAISE EXCEPTION 'Super admin authorization required to restore a banned account';
    END IF;

    -- 312: only a super admin clears a shadowban.
    v_clear_shadowban := v_is_shadowbanned AND v_is_super;

    UPDATE public.users
    SET is_shadowbanned = CASE WHEN v_clear_shadowban THEN false ELSE is_shadowbanned END,
        shadowbanned_at = CASE WHEN v_clear_shadowban THEN NULL ELSE shadowbanned_at END,
        shadowban_reason = CASE WHEN v_clear_shadowban THEN NULL ELSE shadowban_reason END,
        is_banned = CASE WHEN coalesce(v_is_banned, false) THEN false ELSE is_banned END,
        banned_at = CASE WHEN coalesce(v_is_banned, false) THEN NULL ELSE banned_at END,
        banned_reason = CASE WHEN coalesce(v_is_banned, false) THEN NULL ELSE banned_reason END
    WHERE id = p_user_id;

    IF coalesce(v_is_banned, false) THEN
      PERFORM private.clear_enforcement_tombstone(p_user_id);
    END IF;

    UPDATE public.profiles
    SET visibility = CASE WHEN v_has_safe_primary_photo THEN 'visible' ELSE 'paused' END,
        suspended_reason = NULL
    WHERE user_id = p_user_id;

    PERFORM public.queue_notification(
      p_user_id,
      'account_restored',
      'Profile restored',
      CASE
        WHEN v_has_safe_primary_photo THEN 'Your Silarah profile has been restored and is visible again.'
        ELSE 'Your Silarah account has been restored. Add a safe primary photo to return to discovery.'
      END,
      '/home?tab=3'
    );
  ELSIF p_action = 'shadowban' THEN
    UPDATE public.users
    SET is_shadowbanned = true,
        shadowbanned_at = now(),
        shadowban_reason = coalesce(nullif(trim(p_reason), ''), 'admin_shadowban')
    WHERE id = p_user_id;

    -- Deliberately silent: do not disclose this moderation control to the user.
  ELSIF p_action = 'ban' THEN
    UPDATE public.users
    SET is_banned = true,
        banned_at = now(),
        banned_reason = coalesce(nullif(trim(p_reason), ''), 'admin_ban')
    WHERE id = p_user_id;

    UPDATE public.profiles
    SET visibility = 'suspended',
        suspended_reason = coalesce(nullif(trim(p_reason), ''), 'admin_ban')
    WHERE user_id = p_user_id;

    -- 312: the hashed email outlives a later account purge.
    PERFORM private.record_enforcement_tombstone(p_user_id, 'admin_ban');

    PERFORM public.queue_notification(
      p_user_id,
      'account_banned',
      'Account banned',
      'Your Silarah account has been banned for violating community guidelines.',
      '/help-support'
    );
  ELSE
    RAISE EXCEPTION 'Unsupported account action';
  END IF;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'account_' || p_action,
    p_user_id,
    jsonb_build_object('reason', p_reason, 'silent', p_action = 'shadowban')
      || CASE
           WHEN p_action = 'restore' AND v_is_shadowbanned AND NOT v_clear_shadowban
             THEN jsonb_build_object('shadowban_kept', true)
           ELSE '{}'::jsonb
         END
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 8. Legacy admin directory RPC
-- ---------------------------------------------------------------------------
-- The admin app uses admin_user_directory_keyset; this older variant returns
-- full emails and is not called by admin/src, lib or edge functions.
REVOKE EXECUTE ON FUNCTION public.admin_user_directory(text, integer) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 9/10. Banned or deleted callers
-- ---------------------------------------------------------------------------

-- Un-pausing makes a profile discoverable, so the caller must be an active
-- member (not banned, not pending deletion). Pausing stays allowed.
CREATE OR REPLACE FUNCTION public.set_profile_pause(p_paused boolean)
 RETURNS TABLE(is_paused boolean, visibility text, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_profile public.profiles%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE user_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Complete your profile before changing visibility.';
  END IF;
  IF v_profile.visibility IN ('suspended', 'deactivated') THEN
    RAISE EXCEPTION 'This profile cannot be made visible from settings.';
  END IF;

  IF coalesce(p_paused, false) THEN
    UPDATE public.profiles
    SET visibility = 'paused', updated_at = now()
    WHERE id = v_profile.id;
    RETURN QUERY
      SELECT true, 'paused'::text, 'Your profile is hidden.'::text;
    RETURN;
  END IF;

  -- 312: banned or deleting accounts cannot return to discovery.
  PERFORM private.assert_active_member(auth.uid(), false);

  IF coalesce(v_profile.onboarding_completed, false) IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Complete onboarding before making your profile visible.';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.photos ph
    WHERE ph.profile_id = v_profile.id
      AND ph.order_index = 0
      AND ph.status = 'active'
      AND ph.admin_approved = true
      AND ph.nsfw_cleared = true
  ) THEN
    RAISE EXCEPTION
      'Add a primary photo that passes the safety scan before making your profile visible.';
  END IF;

  UPDATE public.profiles
  SET visibility = 'visible',
      approved_at = coalesce(approved_at, now()),
      updated_at = now()
  WHERE id = v_profile.id;
  RETURN QUERY
    SELECT false, 'visible'::text, 'Your profile is visible.'::text;
END;
$function$;

-- A banned or deleting account must not leave view footprints (or view
-- notifications) on other members. The app already ignores errors here.
CREATE OR REPLACE FUNCTION public.record_profile_view(p_viewed_user_id uuid, p_notify_owner boolean DEFAULT false)
 RETURNS TABLE(allowed boolean, views_today integer, daily_limit integer, remaining integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := auth.uid();
  v_viewer_profile_id uuid;
  v_viewed_profile_id uuid;
  v_limit integer;
  v_count integer;
  v_inserted boolean := false;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  -- 312: banned/deleted callers are refused (account_restricted).
  PERFORM private.assert_active_member(v_me, false);

  IF p_viewed_user_id IS NULL OR p_viewed_user_id = v_me THEN
    v_limit := coalesce(public.profile_view_daily_limit(v_me), 15);
    SELECT count(*)::integer INTO v_count
    FROM public.profile_view_daily_seen seen
    WHERE seen.viewer_user_id = v_me
      AND seen.viewed_on = current_date;
    RETURN QUERY SELECT true, v_count, v_limit,
      greatest(v_limit - v_count, 0);
    RETURN;
  END IF;

  IF NOT private.can_access_incognito_profile(v_me, p_viewed_user_id) THEN
    RAISE EXCEPTION 'Profile not found' USING ERRCODE = 'P0001';
  END IF;

  SELECT p.id INTO v_viewer_profile_id
  FROM public.profiles p
  WHERE p.user_id = v_me
  LIMIT 1;

  SELECT p.id INTO v_viewed_profile_id
  FROM public.profiles p
  WHERE p.user_id = p_viewed_user_id
  LIMIT 1;

  IF v_viewer_profile_id IS NULL OR v_viewed_profile_id IS NULL THEN
    RAISE EXCEPTION 'Profile not found' USING ERRCODE = 'P0001';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.blocks b
    WHERE (b.blocker_id = v_me AND b.blocked_id = p_viewed_user_id)
       OR (b.blocker_id = p_viewed_user_id AND b.blocked_id = v_me)
  ) THEN
    RAISE EXCEPTION 'Profile not found' USING ERRCODE = 'P0001';
  END IF;

  v_limit := coalesce(public.profile_view_daily_limit(v_me), 15);

  SELECT count(*)::integer INTO v_count
  FROM public.profile_view_daily_seen seen
  WHERE seen.viewer_user_id = v_me
    AND seen.viewed_on = current_date;

  IF v_count >= v_limit AND NOT EXISTS (
    SELECT 1
    FROM public.profile_view_daily_seen seen
    WHERE seen.viewer_user_id = v_me
      AND seen.viewed_profile_id = v_viewed_profile_id
      AND seen.viewed_on = current_date
  ) THEN
    RETURN QUERY SELECT false, v_count, v_limit, 0;
    RETURN;
  END IF;

  INSERT INTO public.profile_view_daily_seen(
    viewer_user_id, viewed_profile_id, viewed_on
  )
  VALUES (v_me, v_viewed_profile_id, current_date)
  ON CONFLICT DO NOTHING;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  v_inserted := v_count > 0;

  IF v_inserted THEN
    INSERT INTO public.profile_views(viewer_profile_id, viewed_profile_id)
    VALUES (v_viewer_profile_id, v_viewed_profile_id);
  END IF;

  IF coalesce(p_notify_owner, false) THEN
    BEGIN
      PERFORM private.maybe_queue_profile_view_notification(
        v_me,
        p_viewed_user_id
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Profile view committed without notification enqueue: %',
        SQLERRM;
    END;
  END IF;

  SELECT count(*)::integer INTO v_count
  FROM public.profile_view_daily_seen seen
  WHERE seen.viewer_user_id = v_me
    AND seen.viewed_on = current_date;

  RETURN QUERY SELECT true, v_count, v_limit,
    greatest(v_limit - v_count, 0);
END;
$function$;

-- A banned or deleting account must not appear "online"/"recently active".
CREATE OR REPLACE FUNCTION public.record_user_presence(p_app_state text DEFAULT 'foreground'::text, p_platform text DEFAULT NULL::text)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_now timestamptz := now();
  v_state text := coalesce(nullif(trim(p_app_state), ''), 'foreground');
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = 'P0001';
  END IF;
  -- 312: banned/deleted callers are refused (account_restricted).
  PERFORM private.assert_active_member(v_user_id, false);
  IF v_state NOT IN ('foreground', 'background', 'inactive') THEN
    v_state := 'foreground';
  END IF;

  INSERT INTO public.user_presence(
    user_id, last_seen_at, app_state, platform, updated_at
  )
  VALUES (
    v_user_id, v_now, v_state,
    nullif(left(trim(coalesce(p_platform, '')), 24), ''), v_now
  )
  ON CONFLICT (user_id) DO UPDATE
  SET last_seen_at = EXCLUDED.last_seen_at,
      app_state = EXCLUDED.app_state,
      platform = coalesce(EXCLUDED.platform, public.user_presence.platform),
      updated_at = EXCLUDED.updated_at;

  UPDATE public.profiles
  SET last_active_at = v_now
  WHERE user_id = v_user_id
    AND (
      last_active_at IS NULL
      OR last_active_at < v_now - interval '1 hour'
    );
  RETURN v_now;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 11. Storage orphans
-- ---------------------------------------------------------------------------
-- Reservations used to be expired (and their path deleted) at expires_at
-- (15 minutes), but the Storage signed upload URL stays valid for 2 hours:
-- an upload finishing after the delete left a file nothing referenced.
-- Now 'reserved' and 'superseded' rows are expired only after 2h05m, once
-- the URL is dead. finalize_profile_photo_upload / consume_upload_reservation
-- are unchanged: they still accept a reservation only before expires_at and
-- only while it is 'reserved', and nothing here touches a reservation that
-- could still be finalized.
-- Second pass: queue (100 per run) current objects older than 3 hours in
-- 'profile-photos' / 'photo-verification-captures' that nothing references:
-- no public.photos row (any status), no live reservation ('reserved' or the
-- legacy 'uploaded' state), no un-purged verification submission (captures),
-- and no existing deletion job. Returns expired reservations + queued
-- orphans. Called as service role by storage-lifecycle-worker.
CREATE OR REPLACE FUNCTION public.expire_upload_reservations(p_limit integer DEFAULT 100)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_count integer := 0;
  v_orphans integer := 0;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;

  WITH expired AS (
    SELECT id, bucket_id, storage_path, user_id
    FROM private.upload_reservations
    WHERE status IN ('reserved', 'superseded')
      AND created_at <= now() - interval '2 hours 5 minutes'
    ORDER BY created_at
    LIMIT least(greatest(p_limit, 1), 500)
    FOR UPDATE SKIP LOCKED
  ), changed AS (
    UPDATE private.upload_reservations r
    SET status = 'expired'
    FROM expired e
    WHERE r.id = e.id
    RETURNING e.bucket_id, e.storage_path, e.user_id
  ), queued AS (
    INSERT INTO private.storage_deletion_jobs(
      bucket_id, storage_path, user_id, reason
    )
    SELECT c.bucket_id, c.storage_path, c.user_id, 'expired_upload_reservation'
    FROM changed c
    -- Defensive: never delete a file a photo row points at.
    WHERE NOT EXISTS (
      SELECT 1 FROM public.photos ph WHERE ph.storage_path = c.storage_path
    )
    ON CONFLICT (bucket_id, storage_path) DO NOTHING
    RETURNING 1
  )
  SELECT count(*) INTO v_count FROM changed;

  WITH orphans AS (
    SELECT o.bucket_id, o.name
    FROM storage.objects o
    WHERE o.bucket_id IN ('profile-photos', 'photo-verification-captures')
      AND o.created_at <= now() - interval '3 hours'
      AND o.archived_at IS NULL
      AND o.is_delete_marker IS NOT TRUE
      AND NOT EXISTS (
        SELECT 1 FROM public.photos ph WHERE ph.storage_path = o.name
      )
      AND NOT EXISTS (
        SELECT 1 FROM private.upload_reservations r
        WHERE r.bucket_id = o.bucket_id
          AND r.storage_path = o.name
          AND r.status IN ('reserved', 'uploaded')
      )
      AND (
        o.bucket_id <> 'photo-verification-captures'
        OR NOT EXISTS (
          SELECT 1 FROM public.photo_verification_submissions s
          WHERE s.captures_purged_at IS NULL
            AND o.name IN (
              s.neutral_storage_path, s.smile_storage_path, s.blink_storage_path
            )
        )
      )
      AND NOT EXISTS (
        SELECT 1 FROM private.storage_deletion_jobs j
        WHERE j.bucket_id = o.bucket_id AND j.storage_path = o.name
      )
    ORDER BY o.created_at
    LIMIT 100
  ), queued AS (
    INSERT INTO private.storage_deletion_jobs(
      bucket_id, storage_path, user_id, reason
    )
    SELECT orphans.bucket_id, orphans.name, au.id, 'orphan_sweep'
    FROM orphans
    -- Owner from the '<user id>/...' path when that account still exists;
    -- CASE keeps a non-uuid prefix from ever reaching the cast.
    LEFT JOIN auth.users au
      ON au.id = CASE
        WHEN split_part(orphans.name, '/', 1)
          ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        THEN split_part(orphans.name, '/', 1)::uuid
      END
    ON CONFLICT (bucket_id, storage_path) DO NOTHING
    RETURNING 1
  )
  SELECT count(*) INTO v_orphans FROM queued;

  RETURN coalesce(v_count, 0) + coalesce(v_orphans, 0);
END;
$function$;

-- The 5-minute cron only calls the worker when there is work. Its idle check
-- now matches the new expiry rule and also wakes the worker for orphans, or
-- the orphan sweep would never run on a quiet system.
CREATE OR REPLACE FUNCTION private.invoke_storage_lifecycle_worker()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  -- Stay idle (no HTTP call) unless there is deletion, reservation or
  -- orphan-sweep work.
  IF NOT EXISTS (
    SELECT 1
    FROM private.storage_deletion_jobs j
    WHERE (
      j.status IN ('pending', 'failed')
      AND j.next_attempt_at <= now()
    ) OR (
      j.status = 'processing'
      AND j.processing_at < now() - interval '5 minutes'
    )
    LIMIT 1
  ) AND NOT EXISTS (
    SELECT 1
    FROM private.upload_reservations r
    WHERE r.status IN ('reserved', 'superseded')
      AND r.created_at <= now() - interval '2 hours 5 minutes'
    LIMIT 1
  ) AND NOT EXISTS (
    SELECT 1
    FROM storage.objects o
    WHERE o.bucket_id IN ('profile-photos', 'photo-verification-captures')
      AND o.created_at <= now() - interval '3 hours'
      AND o.archived_at IS NULL
      AND o.is_delete_marker IS NOT TRUE
      AND NOT EXISTS (
        SELECT 1 FROM public.photos ph WHERE ph.storage_path = o.name
      )
      AND NOT EXISTS (
        SELECT 1 FROM private.upload_reservations r
        WHERE r.bucket_id = o.bucket_id
          AND r.storage_path = o.name
          AND r.status IN ('reserved', 'uploaded')
      )
      AND (
        o.bucket_id <> 'photo-verification-captures'
        OR NOT EXISTS (
          SELECT 1 FROM public.photo_verification_submissions s
          WHERE s.captures_purged_at IS NULL
            AND o.name IN (
              s.neutral_storage_path, s.smile_storage_path, s.blink_storage_path
            )
        )
      )
      AND NOT EXISTS (
        SELECT 1 FROM private.storage_deletion_jobs j
        WHERE j.bucket_id = o.bucket_id AND j.storage_path = o.name
      )
    LIMIT 1
  ) THEN
    RETURN;
  END IF;

  PERFORM private.invoke_edge_worker('storage-lifecycle-worker', 'storage_lifecycle_worker');
END;
$function$;

-- ---------------------------------------------------------------------------
-- 12/13. RevenueCat ledger
-- ---------------------------------------------------------------------------
-- (user_id, event_type, event_timestamp_ms) is not unique in RevenueCat: two
-- genuine events can share it and the second was swallowed as a duplicate.
-- Duplicates are already caught by idx_subscription_events_provider_event
-- (provider_event_id). apply_revenuecat_subscription_event uses a target-less
-- ON CONFLICT DO NOTHING, so it keeps working with that index alone.
ALTER TABLE public.subscription_events
  DROP CONSTRAINT IF EXISTS subscription_events_user_id_event_type_event_timestamp_ms_key;

-- An 'active'/'grace' state needs an expiry: a NULL expiry would grant
-- Premium with no end. The webhook already returns 400 for this; the
-- database now refuses it too (invalid_billing_event).
DO $do$
DECLARE
  v_sig constant regprocedure :=
    'public.apply_revenuecat_subscription_event(uuid,text,text,bigint,text,timestamp with time zone,text,text,numeric,timestamp with time zone)'::regprocedure;
  v_def text := pg_get_functiondef(v_sig);
  v_old constant text := 'OR p_subscription_status NOT IN (''none'', ''active'', ''grace'')';
  v_new constant text := v_old || chr(10) ||
    '    -- 312: paid states must carry an authoritative expiry.' || chr(10) ||
    '    OR (p_subscription_status IN (''active'', ''grace'')' || chr(10) ||
    '        AND p_subscription_expires_at IS NULL)';
BEGIN
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION '312: apply_revenuecat_subscription_event anchor not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);
END
$do$;

-- ---------------------------------------------------------------------------
-- 14. Pre-auth rate limit subject
-- ---------------------------------------------------------------------------
-- Keyed on the client IP only. Including the User-Agent let a client reset
-- its own limit by changing one header. Order: cf-connecting-ip, then the
-- first x-forwarded-for entry, then x-real-ip.
CREATE OR REPLACE FUNCTION private.pre_auth_rate_limit_subject(p_scope text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
DECLARE
  v_headers jsonb := coalesce(
    nullif(current_setting('request.headers', true), ''),
    '{}'
  )::jsonb;
  v_network text;
BEGIN
  v_network := coalesce(
    nullif(trim(v_headers ->> 'cf-connecting-ip'), ''),
    nullif(trim(split_part(coalesce(v_headers ->> 'x-forwarded-for', ''), ',', 1)), ''),
    nullif(trim(v_headers ->> 'x-real-ip'), ''),
    'unknown'
  );

  RETURN encode(
    extensions.digest(
      convert_to(
        left(coalesce(p_scope, 'preauth'), 40) || ':' || left(v_network, 100),
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );
END;
$function$;
