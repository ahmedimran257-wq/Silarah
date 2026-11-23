-- A finished profile always has a city (added 23 Nov 2026).
--
-- The app treats a member's city as required: a profile without one cannot
-- be shown. The database allowed it to disappear: deleting a city set
-- profiles.city_id (and users.onboarding_city_id) to NULL for everyone in
-- it, and nothing stopped a finished profile being saved without one. A
-- city still in use now cannot be deleted (move its members first), and a
-- finished profile cannot be left without a city.
--
-- Numbered after the voice-calling migrations (323-328) on their branch. If
-- this reaches production before them, push those with --include-all.

DO $migration$
BEGIN
  IF EXISTS (SELECT 1 FROM public.profiles WHERE onboarding_completed AND city_id IS NULL) THEN
    RAISE EXCEPTION 'finished profiles without a city exist; give them a city first';
  END IF;
END;
$migration$;

ALTER TABLE public.profiles
  DROP CONSTRAINT profiles_city_id_fkey,
  ADD CONSTRAINT profiles_city_id_fkey
    FOREIGN KEY (city_id) REFERENCES public.cities(id) ON DELETE RESTRICT;

ALTER TABLE public.users
  DROP CONSTRAINT users_onboarding_city_id_fkey,
  ADD CONSTRAINT users_onboarding_city_id_fkey
    FOREIGN KEY (onboarding_city_id) REFERENCES public.cities(id) ON DELETE RESTRICT;

-- Onboarding rows may exist before the city step; a finished profile may not
-- be without one.
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_finished_profile_has_city
    CHECK (NOT onboarding_completed OR city_id IS NOT NULL);
