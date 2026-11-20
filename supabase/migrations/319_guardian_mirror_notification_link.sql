-- 319: Guardian message notifications open the Guardian dashboard
-- (device test, 20 Nov 2026).
--
-- mirror_messages_to_guardian queued 'guardian_message_mirror' notifications
-- for the Guardian with the member chat link silarah://chat/<match>. The
-- Guardian is not a participant in that chat, so tapping the notification
-- opened "Conversation no longer available" instead of the ward's
-- conversation. The Guardian reads it on the dashboard, so the link now
-- points there. Every released build (42053 included) already routes
-- silarah://guardian-dashboard. Existing rows are corrected too.

DO $migration$
DECLARE
  v_def text;
  v_old constant text := $$format('silarah://chat/%s', NEW.match_id));$$;
  v_new constant text := $$'silarah://guardian-dashboard');$$;
BEGIN
  v_def := pg_get_functiondef('public.mirror_messages_to_guardian()'::regprocedure);
  IF position(v_new in v_def) > 0 AND position(v_old in v_def) = 0 THEN
    RETURN;  -- already applied
  END IF;
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION 'mirror_messages_to_guardian: chat link not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);
END;
$migration$;

UPDATE public.notifications
SET deep_link = 'silarah://guardian-dashboard'
WHERE type = 'guardian_message_mirror'
  AND deep_link LIKE 'silarah://chat/%';
