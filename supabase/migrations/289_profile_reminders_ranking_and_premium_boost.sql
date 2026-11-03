-- Silarah — profile-completion reminders, a quality-aware Discover rank,
-- and Premium-only profile boosts.
--
-- 1. BOOST IS PREMIUM-ONLY
--    activate_profile_boost() let every woman boost without Premium (the
--    same exemption women have for messaging), and the weekly "boost ready"
--    reminder went to women without Premium. Boost is now gated on
--    public.has_active_premium() for everyone: paid, referral or test
--    Premium. Women's free messaging (private.assert_outgoing_chat_entitlement)
--    is untouched.
--
-- 2. DISCOVER RANK (profiles.static_rank_score, 0-100)
--    get_discovery_feed is unchanged. It keeps members' filters, blocks,
--    reports, gender, launch-country (India) and safety rules as hard
--    filters, then orders what is left by
--      recommendation = 0.72 x mutual preference fit (0-100)
--                     + 0.18 x static_rank_score     (0-100)
--                     + 0.10 x location closeness    (0-100)
--                     + 15 while a boost is live (boosted profiles are also
--                       sorted first into the 300-profile candidate set).
--    Quality can therefore move a profile by at most 18 points, while
--    preference fit spans 72, so it rewards good profiles without outranking
--    relevance.
--
--    static_rank_score is now this bounded, explainable sum
--    (private.profile_rank_breakdown returns each part):
--      photo verified (current, not paused)              15
--      guardian linked                                    5
--      extra approved photos: 5 each beyond the first,
--        up to 4 photos                                  15
--      bio: 50+ characters 5, 150+ characters 10         10
--      completeness_score / 10                           10
--      engagement (Glicko tier): platinum 15, gold 12,
--        silver 9, bronze 6, unranked 8 (neutral prior)  15
--      recency: 20 x 0.5^(days since active / 7), so
--        20 today, 10 after a week, 5 after two          20
--      new member: 10 on approval, fading to 0 by day 14 10
--      minus the casual-swiping penalty, capped at 15   -15
--    The total is clamped to 0-100, and shadowbanned members score 0.
--
--    It is precomputed, never per request. The update_profile_score
--    trigger recomputes it whenever the profile row changes (presence writes
--    land at most hourly). A photos trigger refreshes it when approved photos
--    change, and the nightly compute_global_rank_scores job decays recency
--    and applies Glicko tiers. get_discovery_feed keeps
--    plan_cache_mode = force_custom_plan (migration 281).
--
-- 3. PROFILE-COMPLETION REMINDERS (type 'profile_nudge')
--    One specific, localized reminder per missing item, each deep-linked
--    to the screen that fixes it:
--      photo_verification  -> silarah://verify            (Photo check)
--      photos (< 2)        -> silarah://photos            (add up to 4)
--      bio (< 50 chars)    -> silarah://complete-profile
--      deen, education, family, marriage_timeline,
--      partner_preferences -> silarah://complete-profile
--    Rules:
--      - at most one reminder every 3 days per member;
--      - the same item at most once every 14 days and 3 times in total;
--      - nothing once every item is done;
--      - only live members (visible, approved at least a day ago, active in
--        the last 7 days). Never deleted, banned, shadowbanned, suspended,
--        paused, messaging-suspended or guardian-only accounts;
--      - "Activity nudges" off (notification_prefs.inactive_nudge) sends
--        nothing; quiet hours defer delivery (queue_notification);
--      - copy in the member's app language, falling back to English.
--    The daily cron 'profile-nudge-daily' (10:00 UTC, 15:30 IST) is kept.

-- ---------------------------------------------------------------------------
-- 1. Premium-only boost
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.activate_profile_boost()
RETURNS TABLE (boost_expires_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_profile public.profiles%ROWTYPE;
  v_expires timestamptz;
  v_next_available timestamptz;
BEGIN
  PERFORM private.assert_authenticated();

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE user_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND OR v_profile.visibility IS DISTINCT FROM 'visible' THEN
    RAISE EXCEPTION 'Your profile must be live before it can be boosted.'
      USING ERRCODE = 'P0001';
  END IF;
  -- Premium for everyone: paid, referral or test Premium. There is no
  -- gender exemption here; free messaging for women is a separate rule.
  IF NOT public.has_active_premium(auth.uid()) THEN
    RAISE EXCEPTION 'An active subscription is required to boost this profile.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_profile.is_boosted = true
     AND v_profile.boost_expires_at > now() THEN
    RETURN QUERY SELECT v_profile.boost_expires_at;
    RETURN;
  END IF;

  v_next_available := v_profile.boost_last_activated_at + interval '7 days';
  IF v_profile.boost_last_activated_at IS NOT NULL
     AND v_next_available > now() THEN
    RAISE EXCEPTION 'Your next weekly boost is available on %.',
      to_char(v_next_available AT TIME ZONE 'Asia/Kolkata',
              'DD Mon YYYY, HH12:MI AM')
      USING ERRCODE = 'P0001';
  END IF;

  v_expires := now() + interval '2 hours';
  PERFORM set_config('silarah.allow_boost_mutation', 'yes', true);
  UPDATE public.profiles
  SET is_boosted = true,
      boost_expires_at = v_expires,
      boost_last_activated_at = now(),
      boost_ready_notified_at = NULL,
      updated_at = now()
  WHERE id = v_profile.id;

  RETURN QUERY SELECT v_expires;
END;
$$;

REVOKE ALL ON FUNCTION public.activate_profile_boost() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.activate_profile_boost() TO authenticated;

-- Same reminders as migration 220; the weekly boost reminder now goes only
-- to members who can actually boost.
CREATE OR REPLACE FUNCTION private.process_member_reminders(
  p_batch_size integer DEFAULT 500
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_limit integer := greatest(1, least(coalesce(p_batch_size, 500), 2000));
  v_member record;
  v_inactive integer := 0;
  v_boost integer := 0;
BEGIN
  IF NOT pg_try_advisory_xact_lock(
    hashtextextended('member_reminders', 220)
  ) THEN
    RETURN jsonb_build_object('busy', true, 'inactive', 0, 'boost', 0);
  END IF;

  FOR v_member IN
    SELECT u.id
    FROM public.users u
    JOIN public.profiles p ON p.user_id = u.id
    LEFT JOIN public.notification_prefs prefs ON prefs.user_id = u.id
    WHERE u.deleted_at IS NULL
      AND coalesce(u.is_banned, false) = false
      AND coalesce(u.is_shadowbanned, false) = false
      AND p.visibility = 'visible'
      AND p.last_active_at <= now() - interval '7 days'
      AND p.last_active_at > now() - interval '30 days'
      AND coalesce(prefs.inactive_nudge, true) = true
      AND (
        u.last_inactive_nudge_at IS NULL
        OR u.last_inactive_nudge_at < p.last_active_at
      )
    ORDER BY p.last_active_at, u.id
    FOR UPDATE OF u SKIP LOCKED
    LIMIT v_limit
  LOOP
    UPDATE public.users
    SET last_inactive_nudge_at = now()
    WHERE id = v_member.id;
    PERFORM public.queue_notification(
      v_member.id,
      'inactive_nudge',
      'See what is new on Silarah',
      'Your profile has been quiet for a week. Open Discovery to see current compatible profiles.',
      'silarah://discover'
    );
    v_inactive := v_inactive + 1;
  END LOOP;

  FOR v_member IN
    SELECT p.id AS profile_id, p.user_id
    FROM public.profiles p
    JOIN public.users u ON u.id = p.user_id
    LEFT JOIN public.notification_prefs prefs ON prefs.user_id = u.id
    WHERE u.deleted_at IS NULL
      AND coalesce(u.is_banned, false) = false
      AND p.visibility = 'visible'
      AND p.boost_last_activated_at IS NOT NULL
      AND p.boost_last_activated_at <= now() - interval '7 days'
      AND (
        p.boost_ready_notified_at IS NULL
        OR p.boost_ready_notified_at < p.boost_last_activated_at
      )
      AND coalesce(prefs.boost_available, true) = true
      AND public.has_active_premium(u.id)
    ORDER BY p.boost_last_activated_at, p.id
    FOR UPDATE OF p SKIP LOCKED
    LIMIT v_limit
  LOOP
    UPDATE public.profiles
    SET boost_ready_notified_at = now()
    WHERE id = v_member.profile_id;
    PERFORM public.queue_notification(
      v_member.user_id,
      'boost_ready',
      'Your weekly boost is ready',
      'Activate it from your profile to receive two hours of priority placement.',
      'silarah://profile'
    );
    v_boost := v_boost + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'busy', false,
    'inactive', v_inactive,
    'boost', v_boost
  );
END;
$$;

REVOKE ALL ON FUNCTION private.process_member_reminders(integer)
  FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Discover rank
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.profile_rank_breakdown(p public.profiles)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_photos integer;
  v_tier text;
  v_casual_penalty double precision;
  v_shadowbanned boolean;
  v_bio_length integer := char_length(btrim(coalesce(p.bio, '')));
  v_days_active numeric;
  v_days_live numeric;
  v_photo_verified integer;
  v_guardian integer;
  v_photo_points integer;
  v_bio_points integer;
  v_completeness integer;
  v_engagement integer;
  v_recency integer;
  v_new_member integer;
  v_penalty integer;
  v_total integer;
BEGIN
  SELECT count(*)::integer
  INTO v_photos
  FROM public.photos ph
  WHERE ph.profile_id = p.id
    AND ph.status = 'active'
    AND ph.admin_approved = true
    AND ph.nsfw_cleared = true;

  SELECT g.tier, g.casual_penalty
  INTO v_tier, v_casual_penalty
  FROM public.user_glicko_ratings g
  WHERE g.user_id = p.user_id;

  SELECT coalesce(u.is_shadowbanned, false)
         OR coalesce(ua.is_shadowbanned, false)
  INTO v_shadowbanned
  FROM public.users u
  LEFT JOIN public.user_analytics ua ON ua.user_id = u.id
  WHERE u.id = p.user_id;

  v_photo_verified := CASE
    WHEN p.photo_verified_at IS NOT NULL
      AND p.photo_verification_paused_at IS NULL THEN 15
    ELSE 0
  END;
  v_guardian := CASE WHEN p.guardian_user_id IS NOT NULL THEN 5 ELSE 0 END;
  v_photo_points := 5 * least(greatest(v_photos - 1, 0), 3);
  v_bio_points := CASE
    WHEN v_bio_length >= 150 THEN 10
    WHEN v_bio_length >= 50 THEN 5
    ELSE 0
  END;
  v_completeness := round(
    least(greatest(coalesce(p.completeness_score, 0), 0), 100) / 10.0
  )::integer;
  v_engagement := CASE v_tier
    WHEN 'platinum' THEN 15
    WHEN 'gold' THEN 12
    WHEN 'silver' THEN 9
    WHEN 'bronze' THEN 6
    ELSE 8
  END;

  v_days_active := greatest(
    extract(epoch FROM now() - p.last_active_at) / 86400.0, 0
  );
  v_recency := CASE
    WHEN p.last_active_at IS NULL THEN 0
    ELSE round(20 * power(0.5::numeric, v_days_active / 7.0))::integer
  END;

  v_days_live := greatest(
    extract(epoch FROM now() - p.approved_at) / 86400.0, 0
  );
  v_new_member := CASE
    WHEN p.approved_at IS NULL OR v_days_live >= 14 THEN 0
    ELSE round(10 * (1 - v_days_live / 14.0))::integer
  END;

  v_penalty := round(
    least(greatest(coalesce(v_casual_penalty, 0), 0), 15)
  )::integer;

  v_total := CASE
    WHEN coalesce(v_shadowbanned, false) THEN 0
    ELSE least(100, greatest(0,
      v_photo_verified + v_guardian + v_photo_points + v_bio_points
      + v_completeness + v_engagement + v_recency + v_new_member
      - v_penalty
    ))
  END;

  RETURN jsonb_build_object(
    'photo_verified', v_photo_verified,
    'guardian_linked', v_guardian,
    'photos', v_photo_points,
    'approved_photo_count', v_photos,
    'bio', v_bio_points,
    'completeness', v_completeness,
    'engagement', v_engagement,
    'recency', v_recency,
    'new_member', v_new_member,
    'casual_penalty', -v_penalty,
    'shadowbanned', coalesce(v_shadowbanned, false),
    'total', v_total
  );
END;
$$;

REVOKE ALL ON FUNCTION private.profile_rank_breakdown(public.profiles)
  FROM PUBLIC, anon, authenticated;

-- Operations: SELECT private.explain_profile_rank('<profile id>');
CREATE OR REPLACE FUNCTION private.explain_profile_rank(p_profile_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT private.profile_rank_breakdown(p)
    || jsonb_build_object('stored_static_rank_score', p.static_rank_score)
  FROM public.profiles p
  WHERE p.id = p_profile_id;
$$;

REVOKE ALL ON FUNCTION private.explain_profile_rank(uuid)
  FROM PUBLIC, anon, authenticated;

-- Same completeness points as before, now counting only active photos, plus
-- the rank recomputed from the finished row.
CREATE OR REPLACE FUNCTION public.trigger_update_completeness()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  score        integer := 0;
  photo_count  integer;
  bio_length   integer;
BEGIN
  -- 25 pts: has a primary approved photo
  SELECT COUNT(*) INTO photo_count
  FROM photos
  WHERE profile_id = NEW.id
    AND status = 'active'
    AND admin_approved = true
    AND nsfw_cleared   = true
    AND order_index    = 0;
  IF photo_count > 0 THEN score := score + 25; END IF;

  -- 15 pts: bio >= 50 characters
  bio_length := coalesce(char_length(NEW.bio), 0);
  IF bio_length >= 50 THEN score := score + 15; END IF;

  -- 15 pts: Islamic fields complete
  IF NEW.deen_level IS NOT NULL AND NEW.prays_five_daily IS NOT NULL THEN
    score := score + 15;
  END IF;

  -- 10 pts: education + profession
  IF NEW.education_level IS NOT NULL AND NEW.profession IS NOT NULL THEN
    score := score + 10;
  END IF;

  -- 10 pts: family background
  IF NEW.family_type IS NOT NULL AND NEW.parents_status IS NOT NULL THEN
    score := score + 10;
  END IF;

  -- 10 pts: partner preferences set
  IF EXISTS (
    SELECT 1 FROM profile_preferences
    WHERE profile_id = NEW.id AND preferred_age_min IS NOT NULL
  ) THEN score := score + 10; END IF;

  -- 8 pts: second approved photo
  SELECT COUNT(*) INTO photo_count
  FROM photos
  WHERE profile_id = NEW.id
    AND status = 'active'
    AND admin_approved = true
    AND nsfw_cleared   = true;
  IF photo_count >= 2 THEN score := score + 8; END IF;

  -- 4 pts: income bracket provided
  IF NEW.income_bracket IS NOT NULL THEN score := score + 4; END IF;

  -- 3 pts: at least one language listed
  IF NEW.languages IS NOT NULL AND array_length(NEW.languages, 1) > 0 THEN
    score := score + 3;
  END IF;

  NEW.completeness_score := score;
  -- Discover rank, from the row as it will be stored (see the header).
  NEW.static_rank_score :=
    (private.profile_rank_breakdown(NEW)->>'total')::integer;
  RETURN NEW;
END;
$$;

-- Photo approval, removal and reordering change completeness and rank.
-- Clearing completeness_score guarantees the row differs, so the
-- update_profile_score trigger recomputes both from the photos table.
CREATE OR REPLACE FUNCTION private.refresh_profile_scores_after_photo_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE public.profiles
  SET completeness_score = NULL
  WHERE id = coalesce(NEW.profile_id, OLD.profile_id);
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION private.refresh_profile_scores_after_photo_change()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_refresh_profile_scores_photos ON public.photos;
CREATE TRIGGER trg_refresh_profile_scores_photos
  AFTER INSERT OR DELETE OR UPDATE OF status, admin_approved, nsfw_cleared,
    order_index
  ON public.photos
  FOR EACH ROW
  EXECUTE FUNCTION private.refresh_profile_scores_after_photo_change();

-- Nightly: casual penalties, then the same rank for every visible profile.
-- Only rows whose score moved are written.
CREATE OR REPLACE FUNCTION public.compute_global_rank_scores()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM compute_casual_penalties();

  UPDATE public.profiles p
  SET static_rank_score = fresh.total
  FROM (
    SELECT candidate.id,
           (private.profile_rank_breakdown(candidate)->>'total')::integer
             AS total
    FROM public.profiles candidate
    WHERE candidate.visibility = 'visible'
  ) fresh
  WHERE p.id = fresh.id
    AND p.static_rank_score IS DISTINCT FROM fresh.total;
END;
$$;

COMMENT ON COLUMN public.profiles.static_rank_score IS
  'Bounded 0-100 Discover quality score; see private.profile_rank_breakdown and migration 289.';

-- ---------------------------------------------------------------------------
-- 3. Profile-completion reminders
-- ---------------------------------------------------------------------------

-- Old rows are retired; priorities move out of the way of the UNIQUE check.
DELETE FROM public.profile_nudge_rules
WHERE gap_type NOT IN (
  'photo_verification', 'photos', 'bio', 'deen', 'education', 'family',
  'marriage_timeline', 'partner_preferences'
);
UPDATE public.profile_nudge_rules SET priority = priority + 1000;

-- English copy here is the last-resort fallback; private.profile_nudge_copy
-- holds every language.
INSERT INTO public.profile_nudge_rules(
  gap_type, priority, title_template, body_template, deep_link, enabled,
  updated_at
)
VALUES
  ('photo_verification', 10, 'Verify your profile photo',
   'A quick selfie check adds a Photo verified badge. Verified profiles earn more trust and appear higher in Discover.',
   'silarah://verify', true, now()),
  ('photos', 20, 'Add more photos',
   'Add up to 4 photos. Your photo privacy settings still decide who sees them, and profiles with more photos appear higher in Discover.',
   'silarah://photos', true, now()),
  ('bio', 30, 'Add a few lines about yourself',
   'A short bio about your values, your family and what you hope for in marriage helps the right person reach out.',
   'silarah://complete-profile', true, now()),
  ('deen', 40, 'Share your deen details',
   'Add your level of practice and prayer so members can see the values you share.',
   'silarah://complete-profile', true, now()),
  ('education', 50, 'Add your education and work',
   'Your education and profession help members understand your background.',
   'silarah://complete-profile', true, now()),
  ('family', 60, 'Add your family background',
   'Family type and your parents'' details matter to many families. It takes a minute.',
   'silarah://complete-profile', true, now()),
  ('marriage_timeline', 70, 'When are you hoping to marry?',
   'Setting your timeline helps us show you members with the same intentions.',
   'silarah://complete-profile', true, now()),
  ('partner_preferences', 80, 'Set your partner preferences',
   'Tell us the age range you are looking for so Discover can show you better matches.',
   'silarah://complete-profile', true, now())
ON CONFLICT (gap_type) DO UPDATE
SET priority = EXCLUDED.priority,
    title_template = EXCLUDED.title_template,
    body_template = EXCLUDED.body_template,
    deep_link = EXCLUDED.deep_link,
    enabled = EXCLUDED.enabled,
    updated_at = EXCLUDED.updated_at;

CREATE TABLE IF NOT EXISTS private.profile_nudge_copy (
  gap_type text NOT NULL,
  language_code text NOT NULL CHECK (language_code ~ '^[a-z]{2}$'),
  title text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 160),
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 1000),
  PRIMARY KEY (gap_type, language_code)
);

-- One row per member and item: how often it was sent and when.
CREATE TABLE IF NOT EXISTS private.profile_nudge_history (
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  gap_type text NOT NULL,
  sent_count integer NOT NULL DEFAULT 0 CHECK (sent_count >= 0),
  last_sent_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, gap_type)
);

ALTER TABLE private.profile_nudge_copy ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.profile_nudge_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.profile_nudge_copy, private.profile_nudge_history
  FROM PUBLIC, anon, authenticated;

INSERT INTO private.profile_nudge_copy(gap_type, language_code, title, body)
VALUES
  ('photo_verification', 'en', 'Verify your profile photo', 'A quick selfie check adds a Photo verified badge. Verified profiles earn more trust and appear higher in Discover.'),
  ('photo_verification', 'ar', 'وثّق صورة ملفك الشخصي', 'فحص سريع بصورة سيلفي يضيف شارة «صورة موثّقة». الملفات الموثّقة تنال ثقة أكبر وتظهر أعلى في الاستكشاف.'),
  ('photo_verification', 'bn', 'আপনার প্রোফাইল ছবি যাচাই করুন', 'একটি দ্রুত সেলফি যাচাইয়ে “ছবি যাচাইকৃত” ব্যাজ যুক্ত হয়। যাচাইকৃত প্রোফাইল বেশি আস্থা পায় এবং খোঁজে উপরে দেখায়।'),
  ('photo_verification', 'de', 'Bestätige dein Profilfoto', 'Ein kurzer Selfie-Check fügt das Abzeichen „Foto verifiziert“ hinzu. Verifizierte Profile genießen mehr Vertrauen und erscheinen weiter oben in Entdecken.'),
  ('photo_verification', 'fr', 'Vérifiez votre photo de profil', 'Une rapide vérification par selfie ajoute le badge « Photo vérifiée ». Les profils vérifiés inspirent plus confiance et apparaissent plus haut dans Découvrir.'),
  ('photo_verification', 'hi', 'अपनी प्रोफ़ाइल फ़ोटो सत्यापित करें', 'एक छोटी सेल्फ़ी जाँच से “फ़ोटो सत्यापित” बैज जुड़ जाता है। सत्यापित प्रोफ़ाइल पर ज़्यादा भरोसा होता है और वे खोज में ऊपर दिखती हैं।'),
  ('photo_verification', 'id', 'Verifikasi foto profil Anda', 'Pemeriksaan swafoto singkat menambahkan lencana Foto terverifikasi. Profil terverifikasi lebih dipercaya dan tampil lebih atas di Temukan.'),
  ('photo_verification', 'ms', 'Sahkan foto profil anda', 'Semakan swafoto ringkas menambah lencana Foto disahkan. Profil yang disahkan lebih dipercayai dan muncul lebih tinggi dalam carian.'),
  ('photo_verification', 'tr', 'Profil fotoğrafını doğrula', 'Kısa bir selfie kontrolü Fotoğraf doğrulandı rozetini ekler. Doğrulanmış profiller daha çok güven kazanır ve Keşfet''te daha üstte görünür.'),
  ('photo_verification', 'ur', 'اپنی پروفائل تصویر کی تصدیق کریں', 'ایک مختصر سیلفی جانچ سے “تصویر تصدیق شدہ” بیج لگ جاتا ہے۔ تصدیق شدہ پروفائلز پر زیادہ اعتماد ہوتا ہے اور وہ تلاش میں اوپر نظر آتے ہیں۔'),

  ('photos', 'en', 'Add more photos', 'Add up to 4 photos. Your photo privacy settings still decide who sees them, and profiles with more photos appear higher in Discover.'),
  ('photos', 'ar', 'أضف المزيد من الصور', 'أضف حتى 4 صور. إعدادات خصوصية الصور تبقى هي التي تحدد من يراها، والملفات التي تضم صورًا أكثر تظهر أعلى في الاستكشاف.'),
  ('photos', 'bn', 'আরও ছবি যোগ করুন', '৪টি পর্যন্ত ছবি যোগ করুন। কে দেখবে তা আপনার ছবির গোপনীয়তা সেটিংসই ঠিক করে, আর বেশি ছবিসহ প্রোফাইল খোঁজে উপরে দেখায়।'),
  ('photos', 'de', 'Füge weitere Fotos hinzu', 'Füge bis zu 4 Fotos hinzu. Deine Foto-Privatsphäre bestimmt weiterhin, wer sie sieht, und Profile mit mehr Fotos erscheinen weiter oben in Entdecken.'),
  ('photos', 'fr', 'Ajoutez plus de photos', 'Ajoutez jusqu''à 4 photos. Vos réglages de confidentialité décident toujours qui les voit, et les profils avec plus de photos apparaissent plus haut dans Découvrir.'),
  ('photos', 'hi', 'और फ़ोटो जोड़ें', '4 फ़ोटो तक जोड़ें। कौन देख सकता है, यह आपकी फ़ोटो प्राइवेसी सेटिंग ही तय करती है, और ज़्यादा फ़ोटो वाली प्रोफ़ाइल खोज में ऊपर दिखती हैं।'),
  ('photos', 'id', 'Tambahkan lebih banyak foto', 'Tambahkan hingga 4 foto. Pengaturan privasi foto tetap menentukan siapa yang dapat melihatnya, dan profil dengan lebih banyak foto tampil lebih atas di Temukan.'),
  ('photos', 'ms', 'Tambah lebih banyak foto', 'Tambah sehingga 4 foto. Tetapan privasi foto anda tetap menentukan siapa yang boleh melihatnya, dan profil dengan lebih banyak foto muncul lebih tinggi dalam carian.'),
  ('photos', 'tr', 'Daha fazla fotoğraf ekle', '4 fotoğrafa kadar ekle. Kimin göreceğine yine fotoğraf gizlilik ayarların karar verir; daha çok fotoğrafı olan profiller Keşfet''te daha üstte görünür.'),
  ('photos', 'ur', 'مزید تصاویر شامل کریں', '4 تصاویر تک شامل کریں۔ کون دیکھ سکتا ہے، یہ آپ کی تصویر کی پرائیویسی سیٹنگز ہی طے کرتی ہیں، اور زیادہ تصاویر والے پروفائلز تلاش میں اوپر نظر آتے ہیں۔'),

  ('bio', 'en', 'Add a few lines about yourself', 'A short bio about your values, your family and what you hope for in marriage helps the right person reach out.'),
  ('bio', 'ar', 'اكتب بضعة أسطر عن نفسك', 'نبذة قصيرة عن قيمك وعائلتك وما تأمله في الزواج تساعد الشخص المناسب على التواصل معك.'),
  ('bio', 'bn', 'নিজের সম্পর্কে কয়েক লাইন লিখুন', 'আপনার মূল্যবোধ, পরিবার ও বিয়ে নিয়ে প্রত্যাশা সম্পর্কে ছোট একটি পরিচিতি সঠিক মানুষকে যোগাযোগ করতে সাহায্য করে।'),
  ('bio', 'de', 'Schreib ein paar Zeilen über dich', 'Eine kurze Beschreibung deiner Werte, deiner Familie und deiner Wünsche für die Ehe hilft der richtigen Person, dich anzusprechen.'),
  ('bio', 'fr', 'Écrivez quelques lignes sur vous', 'Une courte présentation de vos valeurs, de votre famille et de vos attentes pour le mariage aide la bonne personne à vous contacter.'),
  ('bio', 'hi', 'अपने बारे में कुछ पंक्तियाँ लिखें', 'अपने मूल्यों, परिवार और शादी से उम्मीदों के बारे में छोटा परिचय सही व्यक्ति को आपसे संपर्क करने में मदद करता है।'),
  ('bio', 'id', 'Tulis beberapa kalimat tentang diri Anda', 'Bio singkat tentang nilai-nilai, keluarga, dan harapan Anda dalam pernikahan membantu orang yang tepat menghubungi Anda.'),
  ('bio', 'ms', 'Tulis beberapa baris tentang diri anda', 'Bio ringkas tentang nilai, keluarga dan harapan anda dalam perkahwinan membantu orang yang sesuai menghubungi anda.'),
  ('bio', 'tr', 'Kendinden birkaç satır bahset', 'Değerlerini, aileni ve evlilikten beklentilerini anlatan kısa bir tanıtım, doğru kişinin sana ulaşmasına yardımcı olur.'),
  ('bio', 'ur', 'اپنے بارے میں چند سطریں لکھیں', 'اپنی اقدار، خاندان اور نکاح سے امیدوں کے بارے میں مختصر تعارف صحیح شخص کو آپ سے رابطہ کرنے میں مدد دیتا ہے۔'),

  ('deen', 'en', 'Share your deen details', 'Add your level of practice and prayer so members can see the values you share.'),
  ('deen', 'ar', 'شارك تفاصيل التزامك الديني', 'أضف مستوى التزامك وصلاتك ليرى الأعضاء القيم المشتركة بينكم.'),
  ('deen', 'bn', 'আপনার দ্বীনি তথ্য দিন', 'আপনার দ্বীন পালনের মাত্রা ও নামাজের তথ্য যোগ করুন, যাতে সদস্যরা মিলে যাওয়া মূল্যবোধ দেখতে পান।'),
  ('deen', 'de', 'Teile Angaben zu deinem Deen', 'Gib deine religiöse Praxis und dein Gebet an, damit Mitglieder eure gemeinsamen Werte erkennen.'),
  ('deen', 'fr', 'Précisez votre pratique religieuse', 'Indiquez votre niveau de pratique et votre prière pour que les membres voient les valeurs que vous partagez.'),
  ('deen', 'hi', 'अपनी दीनी जानकारी जोड़ें', 'अपना दीनी स्तर और नमाज़ की जानकारी जोड़ें, ताकि सदस्य आपके साझा मूल्य देख सकें।'),
  ('deen', 'id', 'Bagikan detail agama Anda', 'Tambahkan tingkat pengamalan dan salat Anda agar anggota dapat melihat nilai-nilai yang sama.'),
  ('deen', 'ms', 'Kongsi butiran agama anda', 'Tambah tahap amalan dan solat anda supaya ahli dapat melihat nilai yang dikongsi bersama.'),
  ('deen', 'tr', 'Dini bilgilerini paylaş', 'Dini yaşantını ve namaz durumunu ekle; üyeler ortak değerlerinizi görebilsin.'),
  ('deen', 'ur', 'اپنی دینی تفصیلات شامل کریں', 'اپنی دینی وابستگی اور نماز کی تفصیل شامل کریں تاکہ اراکین مشترکہ اقدار دیکھ سکیں۔'),

  ('education', 'en', 'Add your education and work', 'Your education and profession help members understand your background.'),
  ('education', 'ar', 'أضف تعليمك وعملك', 'يساعد تعليمك ومهنتك الأعضاء على فهم خلفيتك.'),
  ('education', 'bn', 'আপনার শিক্ষা ও পেশা যোগ করুন', 'আপনার শিক্ষা ও পেশা সদস্যদের আপনার পটভূমি বুঝতে সাহায্য করে।'),
  ('education', 'de', 'Füge Ausbildung und Beruf hinzu', 'Deine Ausbildung und dein Beruf helfen Mitgliedern, deinen Hintergrund zu verstehen.'),
  ('education', 'fr', 'Ajoutez vos études et votre métier', 'Vos études et votre profession aident les membres à comprendre votre parcours.'),
  ('education', 'hi', 'अपनी शिक्षा और काम जोड़ें', 'आपकी शिक्षा और पेशा सदस्यों को आपकी पृष्ठभूमि समझने में मदद करते हैं।'),
  ('education', 'id', 'Tambahkan pendidikan dan pekerjaan Anda', 'Pendidikan dan profesi Anda membantu anggota memahami latar belakang Anda.'),
  ('education', 'ms', 'Tambah pendidikan dan pekerjaan anda', 'Pendidikan dan profesion anda membantu ahli memahami latar belakang anda.'),
  ('education', 'tr', 'Eğitimini ve işini ekle', 'Eğitimin ve mesleğin, üyelerin geçmişini anlamasına yardımcı olur.'),
  ('education', 'ur', 'اپنی تعلیم اور کام شامل کریں', 'آپ کی تعلیم اور پیشہ اراکین کو آپ کا پس منظر سمجھنے میں مدد دیتے ہیں۔'),

  ('family', 'en', 'Add your family background', 'Family type and your parents'' details matter to many families. It takes a minute.'),
  ('family', 'ar', 'أضف خلفيتك العائلية', 'نوع العائلة وتفاصيل الوالدين مهمة لكثير من العائلات. لن يستغرق ذلك سوى دقيقة.'),
  ('family', 'bn', 'আপনার পারিবারিক পটভূমি যোগ করুন', 'পরিবারের ধরন ও বাবা-মায়ের তথ্য অনেক পরিবারের কাছে গুরুত্বপূর্ণ। এক মিনিটেই যোগ করা যায়।'),
  ('family', 'de', 'Füge deinen familiären Hintergrund hinzu', 'Familienform und Angaben zu deinen Eltern sind vielen Familien wichtig. Es dauert nur eine Minute.'),
  ('family', 'fr', 'Ajoutez votre contexte familial', 'Le type de famille et les informations sur vos parents comptent pour beaucoup de familles. Une minute suffit.'),
  ('family', 'hi', 'अपनी पारिवारिक पृष्ठभूमि जोड़ें', 'परिवार का प्रकार और माता-पिता की जानकारी कई परिवारों के लिए अहम है। इसमें बस एक मिनट लगता है।'),
  ('family', 'id', 'Tambahkan latar belakang keluarga Anda', 'Jenis keluarga dan detail orang tua penting bagi banyak keluarga. Hanya butuh satu menit.'),
  ('family', 'ms', 'Tambah latar belakang keluarga anda', 'Jenis keluarga dan butiran ibu bapa penting bagi banyak keluarga. Ia hanya mengambil masa seminit.'),
  ('family', 'tr', 'Aile bilgilerini ekle', 'Aile yapısı ve anne babanla ilgili bilgiler birçok aile için önemlidir. Bir dakikanı alır.'),
  ('family', 'ur', 'اپنا خاندانی پس منظر شامل کریں', 'خاندان کی نوعیت اور والدین کی تفصیل بہت سے خاندانوں کے لیے اہم ہے۔ اس میں بس ایک منٹ لگتا ہے۔'),

  ('marriage_timeline', 'en', 'When are you hoping to marry?', 'Setting your timeline helps us show you members with the same intentions.'),
  ('marriage_timeline', 'ar', 'متى تأمل أن تتزوج؟', 'تحديد الموعد الذي تأمله يساعدنا على أن نعرض لك أعضاء لديهم النية نفسها.'),
  ('marriage_timeline', 'bn', 'আপনি কবে বিয়ে করতে চান?', 'আপনার সময়সীমা জানালে আমরা একই উদ্দেশ্যের সদস্যদের দেখাতে পারি।'),
  ('marriage_timeline', 'de', 'Wann möchtest du heiraten?', 'Mit deinem Zeitrahmen zeigen wir dir Mitglieder mit denselben Absichten.'),
  ('marriage_timeline', 'fr', 'Quand souhaitez-vous vous marier ?', 'Indiquer votre calendrier nous aide à vous montrer des membres aux intentions similaires.'),
  ('marriage_timeline', 'hi', 'आप कब तक निकाह करना चाहते हैं?', 'अपनी समय-सीमा बताने से हम आपको एक जैसे इरादे वाले सदस्य दिखा पाते हैं।'),
  ('marriage_timeline', 'id', 'Kapan Anda berharap menikah?', 'Menentukan rencana waktu Anda membantu kami menampilkan anggota dengan niat yang sama.'),
  ('marriage_timeline', 'ms', 'Bilakah anda berharap untuk berkahwin?', 'Menetapkan jangka masa anda membantu kami menunjukkan ahli yang mempunyai niat yang sama.'),
  ('marriage_timeline', 'tr', 'Ne zaman evlenmeyi düşünüyorsun?', 'Zaman planını belirlemen, sana aynı niyetteki üyeleri göstermemize yardımcı olur.'),
  ('marriage_timeline', 'ur', 'آپ کب تک نکاح کرنا چاہتے ہیں؟', 'اپنی متوقع مدت بتانے سے ہم آپ کو ایک جیسے ارادے والے اراکین دکھا سکتے ہیں۔'),

  ('partner_preferences', 'en', 'Set your partner preferences', 'Tell us the age range you are looking for so Discover can show you better matches.'),
  ('partner_preferences', 'ar', 'حدّد تفضيلات شريك الحياة', 'أخبرنا بالفئة العمرية التي تبحث عنها ليعرض لك الاستكشاف تطابقات أفضل.'),
  ('partner_preferences', 'bn', 'জীবনসঙ্গীর পছন্দ ঠিক করুন', 'আপনি কোন বয়সসীমা খুঁজছেন জানান, যাতে আমরা আরও ভালো মিল দেখাতে পারি।'),
  ('partner_preferences', 'de', 'Lege deine Partnerwünsche fest', 'Sag uns, welche Altersspanne du suchst, damit Entdecken dir passendere Profile zeigt.'),
  ('partner_preferences', 'fr', 'Définissez vos préférences de partenaire', 'Indiquez la tranche d''âge recherchée pour que Découvrir vous propose de meilleures correspondances.'),
  ('partner_preferences', 'hi', 'जीवनसाथी की पसंद तय करें', 'बताएँ कि आप किस उम्र सीमा में रिश्ता ढूँढ रहे हैं, ताकि हम आपको बेहतर रिश्ते दिखा सकें।'),
  ('partner_preferences', 'id', 'Atur preferensi pasangan Anda', 'Beri tahu kami rentang usia yang Anda cari agar Temukan dapat menampilkan kecocokan yang lebih baik.'),
  ('partner_preferences', 'ms', 'Tetapkan pilihan pasangan anda', 'Beritahu kami julat umur yang anda cari supaya kami dapat menunjukkan padanan yang lebih baik.'),
  ('partner_preferences', 'tr', 'Eş tercihlerini belirle', 'Aradığın yaş aralığını söyle; Keşfet sana daha uygun profiller göstersin.'),
  ('partner_preferences', 'ur', 'رشتے کی ترجیحات طے کریں', 'بتائیں کہ آپ کس عمر کی حد میں رشتہ تلاش کر رہے ہیں تاکہ ہم آپ کو بہتر رشتے دکھا سکیں۔')
ON CONFLICT (gap_type, language_code) DO UPDATE
SET title = EXCLUDED.title,
    body = EXCLUDED.body;

-- Every item still missing from a profile, in no particular order. Mirrors
-- the completeness points, plus photo verification and a second photo.
CREATE OR REPLACE FUNCTION private.profile_completion_gaps(p public.profiles)
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT coalesce(array_agg(gap.gap_type), ARRAY[]::text[])
  FROM (
    VALUES
      ('photo_verification',
        NOT (p.photo_verified_at IS NOT NULL
             AND p.photo_verification_paused_at IS NULL)
        -- A photo check waiting for review is not nagged about.
        AND NOT EXISTS (
          SELECT 1 FROM public.photo_verification_submissions s
          WHERE s.profile_id = p.id
            AND (s.status = 'pending'
                 OR (s.status = 'uploading'
                     AND s.created_at > now() - interval '1 day'))
        )),
      ('photos', (
        SELECT count(*) FROM public.photos ph
        WHERE ph.profile_id = p.id
          AND ph.status = 'active'
          AND ph.admin_approved = true
          AND ph.nsfw_cleared = true
      ) < 2),
      ('bio', char_length(btrim(coalesce(p.bio, ''))) < 50),
      ('deen', p.deen_level IS NULL OR p.prays_five_daily IS NULL),
      ('education',
        p.education_level IS NULL
        OR nullif(btrim(coalesce(p.profession, '')), '') IS NULL),
      ('family', p.family_type IS NULL OR p.parents_status IS NULL),
      ('marriage_timeline', p.marriage_timeline IS NULL),
      ('partner_preferences', NOT EXISTS (
        SELECT 1 FROM public.profile_preferences pref
        WHERE pref.profile_id = p.id
          AND pref.preferred_age_min IS NOT NULL
          AND pref.preferred_age_max IS NOT NULL
      ))
  ) AS gap(gap_type, is_missing)
  WHERE gap.is_missing;
$$;

REVOKE ALL ON FUNCTION private.profile_completion_gaps(public.profiles)
  FROM PUBLIC, anon, authenticated;

-- The audience rule, shared by the batch and the single-member function.
CREATE OR REPLACE FUNCTION private.profile_nudge_audience(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    JOIN public.profiles p ON p.user_id = u.id
    LEFT JOIN public.notification_prefs prefs ON prefs.user_id = u.id
    WHERE u.id = p_user_id
      AND u.deleted_at IS NULL
      AND u.deletion_status = 'active'
      AND coalesce(u.is_banned, false) = false
      AND coalesce(u.is_shadowbanned, false) = false
      AND (u.messaging_suspended_until IS NULL
           OR u.messaging_suspended_until <= now())
      AND coalesce(u.account_role, 'member') <> 'guardian'
      AND p.visibility = 'visible'
      AND coalesce(p.onboarding_completed, false) = true
      AND p.approved_at <= now() - interval '1 day'
      AND p.last_active_at > now() - interval '7 days'
      AND coalesce(prefs.inactive_nudge, true) = true
      AND coalesce(u.last_nudge_sent_at, '-infinity'::timestamptz)
          <= now() - interval '3 days'
  );
$$;

REVOKE ALL ON FUNCTION private.profile_nudge_audience(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.dispatch_profile_nudge(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_profile public.profiles%ROWTYPE;
  v_lang text;
  v_gaps text[];
  v_gap_type text;
  v_deep_link text;
  v_title text;
  v_body text;
  v_claimed integer;
BEGIN
  -- Repeated here so a manual call cannot bypass the audience or the
  -- three-day interval.
  IF NOT private.profile_nudge_audience(p_user_id) THEN
    RETURN;
  END IF;

  SELECT p.* INTO v_profile
  FROM public.profiles p
  WHERE p.user_id = p_user_id;

  SELECT coalesce(lower(left(nullif(btrim(u.preferred_language), ''), 2)), 'en')
  INTO v_lang
  FROM public.users u
  WHERE u.id = p_user_id;

  v_gaps := private.profile_completion_gaps(v_profile);
  IF cardinality(v_gaps) = 0 THEN
    RETURN;
  END IF;

  -- Highest-priority missing item that was not sent in the last 14 days
  -- and has been sent fewer than 3 times.
  SELECT rule.gap_type, rule.deep_link, rule.title_template, rule.body_template
  INTO v_gap_type, v_deep_link, v_title, v_body
  FROM public.profile_nudge_rules rule
  LEFT JOIN private.profile_nudge_history sent
    ON sent.user_id = p_user_id AND sent.gap_type = rule.gap_type
  WHERE rule.enabled
    AND rule.gap_type = ANY(v_gaps)
    AND (
      sent.user_id IS NULL
      OR (sent.sent_count < 3
          AND sent.last_sent_at <= now() - interval '14 days')
    )
  ORDER BY rule.priority
  LIMIT 1;

  IF v_gap_type IS NULL THEN
    RETURN;
  END IF;

  SELECT c.title, c.body
  INTO v_title, v_body
  FROM private.profile_nudge_copy c
  WHERE c.gap_type = v_gap_type
    AND c.language_code IN (v_lang, 'en')
  ORDER BY (c.language_code = v_lang) DESC
  LIMIT 1;
  -- With no copy row, the rule's English templates (already selected) stay.

  -- Claim the send window atomically so overlapping runs cannot double-send.
  UPDATE public.users
  SET last_nudge_sent_at = now()
  WHERE id = p_user_id
    AND coalesce(last_nudge_sent_at, '-infinity'::timestamptz)
        <= now() - interval '3 days';
  GET DIAGNOSTICS v_claimed = ROW_COUNT;
  IF v_claimed = 0 THEN
    RETURN;
  END IF;

  INSERT INTO private.profile_nudge_history(
    user_id, gap_type, sent_count, last_sent_at
  )
  VALUES (p_user_id, v_gap_type, 1, now())
  ON CONFLICT (user_id, gap_type) DO UPDATE
  SET sent_count = private.profile_nudge_history.sent_count + 1,
      last_sent_at = now();

  -- queue_notification moves delivery past the member's quiet hours.
  PERFORM public.queue_notification(
    p_user_id, 'profile_nudge', v_title, v_body, v_deep_link
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.dispatch_profile_nudges()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtextextended('profile_nudges', 289)) THEN
    RETURN;
  END IF;

  FOR v_user_id IN
    SELECT u.id
    FROM public.users u
    JOIN public.profiles p ON p.user_id = u.id
    WHERE u.deleted_at IS NULL
      AND p.visibility = 'visible'
      AND p.last_active_at > now() - interval '7 days'
      AND coalesce(u.last_nudge_sent_at, '-infinity'::timestamptz)
          <= now() - interval '3 days'
      AND private.profile_nudge_audience(u.id)
    ORDER BY p.last_active_at DESC, u.id
    LIMIT 500
  LOOP
    PERFORM public.dispatch_profile_nudge(v_user_id);
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.dispatch_profile_nudge(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.dispatch_profile_nudges()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.dispatch_profile_nudge(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.dispatch_profile_nudges() TO service_role;

COMMENT ON FUNCTION public.dispatch_profile_nudge(uuid) IS
  'One localized profile-completion reminder for one missing item; see migration 289.';
COMMENT ON TABLE private.profile_nudge_history IS
  'Per member and item: reminders sent (max 3) and when (14-day gap).';

-- Recompute every profile once so the new rank applies immediately.
UPDATE public.profiles p
SET static_rank_score = (private.profile_rank_breakdown(p)->>'total')::integer
WHERE p.static_rank_score IS DISTINCT FROM
  (private.profile_rank_breakdown(p)->>'total')::integer;

NOTIFY pgrst, 'reload schema';
