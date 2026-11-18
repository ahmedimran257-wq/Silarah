-- Cities are unique per (region, name). When a second member picked a
-- different village with the same name in the same state, the conflict branch
-- overwrote the stored latitude/longitude, silently moving the cached city that
-- earlier members and later searches rely on. Members' own coordinates are
-- saved separately and were never affected.
--
-- Same-name villages now resolve to district-qualified names in the
-- location-search function (e.g. "Ramnagar (Warangal)"). For a true duplicate,
-- the cached row keeps its first coordinates. Behaviour is otherwise unchanged.

CREATE OR REPLACE FUNCTION public.get_or_create_city(
  p_city_name character varying,
  p_region_name character varying,
  p_country_name character varying,
  p_country_code character varying,
  p_latitude numeric,
  p_longitude numeric
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_country_code text := upper(trim(coalesce(p_country_code, '')));
  v_country_name text := trim(coalesce(p_country_name, ''));
  v_region_name text := trim(coalesce(p_region_name, ''));
  v_city_name text := trim(coalesce(p_city_name, ''));
  v_region_id integer;
  v_city_id integer;
BEGIN
  IF auth.role() <> 'service_role'
    OR v_country_code !~ '^[A-Z]{2}$'
    OR char_length(v_country_name) NOT BETWEEN 2 AND 100
    OR char_length(v_region_name) NOT BETWEEN 2 AND 100
    OR char_length(v_city_name) NOT BETWEEN 2 AND 100
    OR p_latitude NOT BETWEEN -90 AND 90
    OR p_longitude NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION 'invalid_location_resolution' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.countries(
    iso_code, name, dialing_code, currency, default_lang, rtl, show_sect,
    show_sub_sect, wali_requirement, pricing_tier
  )
  VALUES (
    v_country_code, v_country_name, '', '', 'en', false, true, false,
    'optional', 'tier_3'
  )
  ON CONFLICT (iso_code) DO UPDATE
  SET name = public.countries.name
  RETURNING iso_code INTO v_country_code;

  INSERT INTO public.regions(country_code, name)
  VALUES (v_country_code, v_region_name)
  ON CONFLICT (country_code, name) DO UPDATE
  SET name = EXCLUDED.name
  RETURNING id INTO v_region_id;

  -- Keep the first coordinates; only fill them in if they were missing.
  INSERT INTO public.cities(region_id, name, latitude, longitude)
  VALUES (v_region_id, v_city_name, p_latitude, p_longitude)
  ON CONFLICT (region_id, name) DO UPDATE
  SET latitude = coalesce(public.cities.latitude, EXCLUDED.latitude),
      longitude = coalesce(public.cities.longitude, EXCLUDED.longitude)
  RETURNING id INTO v_city_id;

  RETURN v_city_id;
END;
$function$;
