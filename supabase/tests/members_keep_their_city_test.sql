-- Rollback test for migration 329: a finished profile always has a city.
-- STAGING only: "$TEMP/vc/sq.sh" <staging ref> this file.
BEGIN;

CREATE TEMP TABLE t_results (n serial, name text, ok boolean, detail text) ON COMMIT DROP;

CREATE FUNCTION pg_temp.ok(p_name text, p_ok boolean, p_detail text DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO t_results(name, ok, detail) VALUES (p_name, coalesce(p_ok, false), p_detail);
$$;

-- The SQLSTATE a statement fails with, or 'ok'.
CREATE FUNCTION pg_temp.try(p_sql text) RETURNS text LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE p_sql;
  RETURN 'ok';
EXCEPTION WHEN OTHERS THEN
  RETURN SQLSTATE;
END $$;

CREATE FUNCTION pg_temp.member(p_id uuid, p_city integer, p_finished boolean)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO auth.users(id, aud, role, email, email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data)
  VALUES (p_id, 'authenticated', 'authenticated',
    'cityqa.' || right(p_id::text, 4) || '@gmail.com', now(), now(), now(), '{}', '{}');
  INSERT INTO public.users(id, email, gender, country_code, timezone, onboarding_city_id)
  VALUES (p_id, 'cityqa.' || right(p_id::text, 4) || '@gmail.com', 'female', 'IN',
    'Asia/Kolkata', p_city);
  INSERT INTO public.profiles(user_id, first_name, last_name, date_of_birth, gender,
    country_code, visibility, onboarding_completed, city_id)
  VALUES (p_id, 'Sana', 'Qatest', date '1995-01-01', 'female', 'IN', 'visible', p_finished, p_city);
END $$;

DO $$
DECLARE
  used integer;
  spare integer;
  next_city integer;
  finished uuid := '00000000-0000-4000-8000-000000130001';
  started uuid := '00000000-0000-4000-8000-000000130002';
  r text;
BEGIN
  -- A city of the catalogue's region, used by a finished member.
  INSERT INTO public.cities(region_id, name)
  SELECT region_id, 'Cityqa Used' FROM public.cities WHERE region_id IS NOT NULL LIMIT 1
  RETURNING id INTO used;
  INSERT INTO public.cities(region_id, name)
  SELECT region_id, 'Cityqa Spare' FROM public.cities WHERE region_id IS NOT NULL LIMIT 1
  RETURNING id INTO spare;
  INSERT INTO public.cities(region_id, name)
  SELECT region_id, 'Cityqa Next' FROM public.cities WHERE id = used
  RETURNING id INTO next_city;
  PERFORM pg_temp.member(finished, used, true);

  r := pg_temp.try(format('DELETE FROM public.cities WHERE id = %s', used));
  PERFORM pg_temp.ok('a city members live in cannot be deleted', r = '23503', r);
  PERFORM pg_temp.ok('the member keeps the city',
    (SELECT city_id FROM public.profiles WHERE user_id = finished) = used
    AND (SELECT onboarding_city_id FROM public.users WHERE id = finished) = used);

  r := pg_temp.try(format('DELETE FROM public.cities WHERE id = %s', spare));
  PERFORM pg_temp.ok('a city nobody uses can still be deleted', r = 'ok', r);

  r := pg_temp.try(format('UPDATE public.profiles SET city_id = NULL WHERE user_id = %L', finished));
  PERFORM pg_temp.ok('a finished profile cannot lose its city', r = '23514', r);

  -- Onboarding rows may exist before the city step.
  r := pg_temp.try(format('SELECT pg_temp.member(%L, NULL, false)', started));
  PERFORM pg_temp.ok('an unfinished profile may still be without a city', r = 'ok', r);
  r := pg_temp.try(format('UPDATE public.profiles SET onboarding_completed = true WHERE user_id = %L', started));
  PERFORM pg_temp.ok('it cannot be finished without one', r = '23514', r);

  -- Moving members first, then retiring the city, works.
  UPDATE public.users SET onboarding_city_id = next_city WHERE id = finished;
  UPDATE public.profiles SET city_id = next_city WHERE user_id = finished;
  r := pg_temp.try(format('DELETE FROM public.cities WHERE id = %s', used));
  PERFORM pg_temp.ok('after its members move, the city can be retired', r = 'ok', r);
END $$;

SELECT n, ok, name, detail FROM t_results ORDER BY n;
ROLLBACK;
