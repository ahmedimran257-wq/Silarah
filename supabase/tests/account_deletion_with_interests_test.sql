-- Rollback test for migration 338: a member with pending interests can delete
-- their account, and a deleted member still cannot make relationship moves.
-- STAGING only: "$TEMP/vc/sq.sh" <staging ref> this file. Uses two existing
-- active staging members (Aisha deletes; Imran receives her interest) and a throwaway
-- member who sends one to her. Nothing is kept.
BEGIN;

CREATE TEMP TABLE t_results (n serial, name text, ok boolean, detail text) ON COMMIT DROP;

CREATE FUNCTION pg_temp.ok(p_name text, p_ok boolean, p_detail text DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO t_results(name, ok, detail) VALUES (p_name, coalesce(p_ok, false), p_detail);
$$;

-- The error message a statement fails with, or 'ok'.
CREATE FUNCTION pg_temp.try(p_sql text) RETURNS text LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE p_sql;
  RETURN 'ok';
EXCEPTION WHEN OTHERS THEN
  RETURN SQLERRM;
END $$;

CREATE FUNCTION pg_temp.as_member(p_id uuid) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims', jsonb_build_object('sub', p_id, 'role', 'authenticated')::text, true),
         set_config('request.jwt.claim.sub', p_id::text, true);
$$;

CREATE FUNCTION pg_temp.as_system() RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims', '', true), set_config('request.jwt.claim.sub', '', true);
$$;

-- A throwaway active male member (rolled back with everything else).
CREATE FUNCTION pg_temp.member(p_id uuid) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_city integer := (SELECT city_id FROM public.profiles WHERE user_id = 'a5161695-036c-4687-8381-da1daedc70e0');
BEGIN
  INSERT INTO auth.users(id, aud, role, email, email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data)
  VALUES (p_id, 'authenticated', 'authenticated', 'delqa.' || right(p_id::text, 4) || '@gmail.com',
    now(), now(), now(), '{}', '{}');
  INSERT INTO public.users(id, email, gender, country_code, timezone, onboarding_city_id)
  VALUES (p_id, 'delqa.' || right(p_id::text, 4) || '@gmail.com', 'male', 'IN', 'Asia/Kolkata', v_city);
  INSERT INTO public.profiles(user_id, first_name, last_name, date_of_birth, gender,
    country_code, visibility, onboarding_completed, city_id)
  VALUES (p_id, 'Zaid', 'Qatest', date '1994-01-01', 'male', 'IN', 'visible', true, v_city);
END $$;

DO $$
DECLARE
  aisha uuid := '50723e93-d39c-429a-af48-d1819097881f';
  imran uuid := 'a5161695-036c-4687-8381-da1daedc70e0';
  zaid uuid := gen_random_uuid();
  sent uuid;
  got uuid;
  r text;
BEGIN
  PERFORM pg_temp.ok('fixture: both members active',
    (SELECT count(*) FROM public.users WHERE id IN (aisha, imran) AND deleted_at IS NULL) = 2);

  -- Pending interests in both directions, created as the system.
  PERFORM pg_temp.as_system();
  PERFORM pg_temp.member(zaid);
  INSERT INTO public.interests (sender_id, receiver_id) VALUES (aisha, imran) RETURNING id INTO sent;
  INSERT INTO public.interests (sender_id, receiver_id) VALUES (zaid, aisha) RETURNING id INTO got;

  -- The bug: deletion with pending interests failed with account_restricted.
  PERFORM pg_temp.as_member(aisha);
  r := pg_temp.try($q$SELECT public.request_my_account_deletion('rollback test')$q$);
  PERFORM pg_temp.ok('member with pending interests can delete their account', r = 'ok', r);
  PERFORM pg_temp.ok('account is pending deletion',
    (SELECT deletion_status = 'pending_deletion' AND deleted_at IS NOT NULL FROM public.users WHERE id = aisha));
  PERFORM pg_temp.ok('sent pending interest expired', (SELECT status FROM public.interests WHERE id = sent) = 'expired');
  PERFORM pg_temp.ok('received pending interest expired', (SELECT status FROM public.interests WHERE id = got) = 'expired');
  PERFORM pg_temp.ok('profile hidden from discovery',
    (SELECT visibility FROM public.profiles WHERE user_id = aisha) = 'paused');

  -- The guard still stops a deleted member's relationship moves.
  PERFORM pg_temp.as_system();
  UPDATE public.interests SET status = 'pending' WHERE id = got;
  PERFORM pg_temp.as_member(aisha);
  r := pg_temp.try(format($q$UPDATE public.interests SET status = 'accepted' WHERE id = %L$q$, got));
  PERFORM pg_temp.ok('deleted member cannot accept an interest', r LIKE '%account_restricted%', r);
  r := pg_temp.try(format($q$UPDATE public.interests SET status = 'expired', note = 'x' WHERE id = %L$q$, got));
  PERFORM pg_temp.ok('expiry cannot carry other changes', r LIKE '%account_restricted%', r);
  r := pg_temp.try(format($q$INSERT INTO public.interests (sender_id, receiver_id) VALUES (%L, %L)$q$, aisha, gen_random_uuid()));
  PERFORM pg_temp.ok('deleted member cannot send an interest', r <> 'ok', r);
  r := pg_temp.try(format($q$UPDATE public.interests SET status = 'expired' WHERE id = %L$q$, got));
  PERFORM pg_temp.ok('plain expiry is allowed', r = 'ok', r);

  PERFORM pg_temp.as_system();
END $$;

SELECT n, ok, name, detail FROM t_results ORDER BY n;
ROLLBACK;
