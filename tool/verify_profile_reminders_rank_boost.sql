-- Rolled-back staging check for migration 289: Premium-only boost, the
-- Discover quality score and profile-completion reminders. Two fixture
-- members are created and everything is rolled back; nothing is sent.
-- Run against staging only (execute_sql or psql); any failed ASSERT aborts.
BEGIN;

SET LOCAL session_replication_role = replica;
INSERT INTO auth.users(id, email, email_confirmed_at)
VALUES
  ('28900000-0000-0000-0000-000000000001', 'rank-female@staging.silarah.invalid', now()),
  ('28900000-0000-0000-0000-000000000002', 'rank-male@staging.silarah.invalid', now());

INSERT INTO public.users(
  id, email, gender, country_code, onboarding_step, onboarding_completed,
  subscription_status, is_banned, preferred_language, timezone, deletion_status
)
VALUES
  ('28900000-0000-0000-0000-000000000001', 'rank-female@staging.silarah.invalid', 'female', 'IN', 5, true, 'none', false, 'hi', 'Asia/Kolkata', 'active'),
  ('28900000-0000-0000-0000-000000000002', 'rank-male@staging.silarah.invalid', 'male', 'IN', 5, true, 'none', false, 'en', 'Asia/Kolkata', 'active');

INSERT INTO public.profiles(
  id, user_id, first_name, last_name, date_of_birth, gender, country_code,
  visibility, onboarding_step, onboarding_completed, approved_at,
  last_active_at
)
VALUES
  ('28900000-0000-0000-0000-000000000003', '28900000-0000-0000-0000-000000000001', 'Staging', 'Female', '1998-01-01', 'female', 'IN', 'visible', 14, true, now() - interval '2 days', now()),
  ('28900000-0000-0000-0000-000000000004', '28900000-0000-0000-0000-000000000002', 'Staging', 'Male', '1995-01-01', 'male', 'IN', 'visible', 14, true, now() - interval '2 days', now());

INSERT INTO public.photos(
  profile_id, storage_path, status, order_index, admin_approved,
  nsfw_cleared, moderation_status
)
VALUES
  ('28900000-0000-0000-0000-000000000003', 'verify-289/female-0.jpg', 'active', 0, true, true, 'approved'),
  ('28900000-0000-0000-0000-000000000004', 'verify-289/male-0.jpg', 'active', 0, true, true, 'approved');
SET LOCAL session_replication_role = origin;

DO $verify$
DECLARE
  v_female uuid := '28900000-0000-0000-0000-000000000001';
  v_male uuid := '28900000-0000-0000-0000-000000000002';
  v_female_profile uuid := '28900000-0000-0000-0000-000000000003';
  v_refused boolean;
  v_score integer;
  v_after integer;
  v_title text;
  v_link text;
BEGIN
  -- Score the fixtures once with the triggers on.
  UPDATE public.profiles SET last_active_at = now() - interval '1 minute'
  WHERE user_id IN (v_female, v_male);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);

  -- 1. Boost: free woman and free man are refused; Premium woman may boost.
  FOREACH v_title IN ARRAY ARRAY[v_female::text, v_male::text] LOOP
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_title, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_title, true);
    v_refused := false;
    BEGIN
      PERFORM public.activate_profile_boost();
    EXCEPTION WHEN OTHERS THEN
      v_refused := SQLERRM LIKE 'An active subscription is required%';
    END;
    ASSERT v_refused, 'free member was allowed to boost: ' || v_title;
  END LOOP;
  -- Women still message free.
  PERFORM private.assert_outgoing_chat_entitlement(v_female);

  UPDATE public.users
  SET subscription_status = 'active',
      subscription_expires_at = now() + interval '30 days'
  WHERE id = v_female;
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_female, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_female::text, true);
  PERFORM public.activate_profile_boost();
  ASSERT (SELECT is_boosted AND boost_expires_at > now()
          FROM public.profiles WHERE id = v_female_profile),
    'Premium woman could not boost';
  UPDATE public.users
  SET subscription_status = 'none', subscription_expires_at = NULL
  WHERE id = v_female;

  -- 2. Rank: a bio and more photos raise the stored score through triggers.
  SELECT static_rank_score INTO v_score
  FROM public.profiles WHERE id = v_female_profile;
  UPDATE public.profiles
  SET bio = repeat('Family-minded, practising, love reading. ', 5)
  WHERE id = v_female_profile;
  INSERT INTO public.photos(
    profile_id, storage_path, status, order_index, admin_approved,
    nsfw_cleared, moderation_status
  )
  VALUES
    (v_female_profile, 'verify-289/female-1.jpg', 'active', 1, true, true, 'approved'),
    (v_female_profile, 'verify-289/female-2.jpg', 'active', 2, true, true, 'approved'),
    (v_female_profile, 'verify-289/female-3.jpg', 'active', 3, true, true, 'approved');
  SELECT static_rank_score INTO v_after
  FROM public.profiles WHERE id = v_female_profile;
  ASSERT v_after >= v_score + 25,
    format('rank did not rise enough: %s -> %s', v_score, v_after);
  ASSERT (private.explain_profile_rank(v_female_profile)->>'photos')::int = 15,
    'four photos should earn the 15-point photo cap';
  ASSERT v_after BETWEEN 0 AND 100, 'rank out of bounds';

  -- 3. Reminders: Hindi copy for the top missing item, then the 3-day gap.
  DELETE FROM public.notifications WHERE user_id = v_female;
  PERFORM public.dispatch_profile_nudge(v_female);
  SELECT title, deep_link INTO v_title, v_link
  FROM public.notifications
  WHERE user_id = v_female AND type = 'profile_nudge';
  ASSERT v_link = 'silarah://verify', 'first reminder should be photo check';
  ASSERT v_title = (SELECT title FROM private.profile_nudge_copy
                    WHERE gap_type = 'photo_verification'
                      AND language_code = 'hi'),
    'reminder was not in the member language';
  PERFORM public.dispatch_profile_nudge(v_female);
  ASSERT (SELECT count(*) FROM public.notifications
          WHERE user_id = v_female AND type = 'profile_nudge') = 1,
    'second reminder inside three days';

  -- Paused members and members who turned activity nudges off get nothing.
  UPDATE public.users SET last_nudge_sent_at = NULL WHERE id = v_female;
  UPDATE public.profiles SET visibility = 'paused' WHERE id = v_female_profile;
  ASSERT NOT private.profile_nudge_audience(v_female), 'paused member reminded';
  UPDATE public.profiles SET visibility = 'visible' WHERE id = v_female_profile;
  INSERT INTO public.notification_prefs(user_id, inactive_nudge)
  VALUES (v_female, false)
  ON CONFLICT (user_id) DO UPDATE SET inactive_nudge = false;
  ASSERT NOT private.profile_nudge_audience(v_female),
    'member with activity nudges off reminded';
END;
$verify$;

ROLLBACK;
