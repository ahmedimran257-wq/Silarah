-- The 30-day pause after a declined interest counted from when the interest
-- was SENT (interests.created_at), not from when it was declined. Interests
-- stay pending for up to 14 days, so a decline on day 13 paused the sender
-- for only 17 days (found in the device test of 21 Nov 2026).
--
-- interests had no record of when it was answered. Now:
-- 1. responded_at is stamped by the database whenever the status changes to
--    accepted or declined, on every write path, and cannot be set or moved
--    by any other update.
-- 2. send_interest counts the pause from responded_at. Declines from before
--    this migration have no responded_at and keep the old reference
--    (created_at), the only time the database has for them.

ALTER TABLE public.interests
  ADD COLUMN IF NOT EXISTS responded_at timestamptz;

COMMENT ON COLUMN public.interests.responded_at IS
  'When the receiver accepted or declined. Set by trg_stamp_interest_response only.';

CREATE OR REPLACE FUNCTION private.stamp_interest_response()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.responded_at := CASE
      WHEN NEW.status IN ('accepted', 'declined') THEN now()
      ELSE NULL
    END;
  ELSIF NEW.status IS DISTINCT FROM OLD.status
        AND NEW.status IN ('accepted', 'declined') THEN
    NEW.responded_at := now();
  ELSE
    NEW.responded_at := OLD.responded_at;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.stamp_interest_response() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_stamp_interest_response ON public.interests;
CREATE TRIGGER trg_stamp_interest_response
  BEFORE INSERT OR UPDATE ON public.interests
  FOR EACH ROW
  EXECUTE FUNCTION private.stamp_interest_response();

-- Count the decline pause from the decline.
DO $migration$
DECLARE
  v_def text := pg_get_functiondef('public.send_interest(uuid, text)'::regprocedure);
  v_old text := 'i.created_at + interval ''30 days''';
  v_new text := 'coalesce(i.responded_at, i.created_at) + interval ''30 days''';
BEGIN
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 2 THEN
    RAISE EXCEPTION 'send_interest: decline pause expression not found exactly twice';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);
END;
$migration$;
