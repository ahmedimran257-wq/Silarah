-- Silarah — policy 2.7.0: voice calls, call minute packs, refunds only for
-- Silarah's own mistakes (owner-approved 25 Nov 2026;
-- docs/calling_legal_updates_draft.md).
--
-- Backend-first, like 264 and 271. Installed clients keep working with the
-- version they actually display (2.4.0, 2.5.0, and 2.6.0 where the US/Canada
-- bundle of migration 271 exists); new clients present and record 2.7.0.
-- 2.7.0 becomes the current notice for reminders and exports. No consent is
-- backfilled, and a reminder acknowledgement is never treated as consent.
--
-- 2.6.0 is the US/Canada bundle (expansion/us-canada, migration 271), applied
-- on staging only. Production has 264's functions; staging has 271's. Rather
-- than restate either set of bodies (which would undo the other), each
-- function's CURRENT definition is patched in place: the accepted-version
-- list gains '2.7.0' and the current version becomes '2.7.0'. Every patch
-- checks its anchor and raises otherwise, so the whole migration rolls back
-- instead of half-applying.

DO $migration$
DECLARE
  v_fn regprocedure;
  v_old text;
  v_new text;
  v_lists integer;
BEGIN
  FOREACH v_fn IN ARRAY ARRAY[
    'public.begin_signup_consent_transaction(text,jsonb)'::regprocedure,
    'public.finalize_signup_consents(uuid)'::regprocedure,
    'public.sync_my_user(text,text)'::regprocedure,
    'public.get_my_policy_reminder_state()'::regprocedure,
    'public.acknowledge_policy_reminder(text)'::regprocedure,
    'public.download_my_data(text)'::regprocedure
  ] LOOP
    v_old := replace(pg_get_functiondef(v_fn), E'\r\n', E'\n');
    IF position($v$'2.7.0'$v$ IN v_old) > 0 THEN
      CONTINUE;  -- already 2.7.0 (re-run)
    END IF;

    -- Accepted versions: ('2.4.0', '2.5.0'[, '2.6.0']) -> ... , '2.7.0')
    v_lists := (SELECT count(*) FROM regexp_matches(v_old,
      $p$'2\.4\.0', '2\.5\.0'(, '2\.6\.0')?\)$p$, 'g'));
    v_new := regexp_replace(v_old,
      $p$('2\.4\.0', '2\.5\.0'(, '2\.6\.0')?)\)$p$, $r$\1, '2.7.0')$r$, 'g');

    -- Current version: comparisons and the reported notice version.
    v_new := regexp_replace(v_new, $p$(<>|=) '2\.[56]\.0'$p$, $r$\1 '2.7.0'$r$, 'g');
    v_new := regexp_replace(v_new, $p$'2\.[56]\.0'::text$p$, $r$'2.7.0'::text$r$, 'g');

    -- Each function must have changed in the way its role requires.
    IF v_new = v_old THEN
      RAISE EXCEPTION 'policy_270: % unchanged', v_fn;
    END IF;
    IF v_fn::text LIKE '%begin_signup_consent_transaction%'
       OR v_fn::text LIKE '%finalize_signup_consents%'
       OR v_fn::text LIKE '%sync_my_user%'
       OR v_fn::text LIKE '%acknowledge_policy_reminder%' THEN
      IF v_lists = 0 THEN
        RAISE EXCEPTION 'policy_270: % has no accepted-version list', v_fn;
      END IF;
    END IF;
    IF v_fn::text LIKE '%get_my_policy_reminder_state%'
       AND position($v$SELECT '2.7.0'::text$v$ IN v_new) = 0 THEN
      RAISE EXCEPTION 'policy_270: reminder state does not report 2.7.0';
    END IF;
    IF v_fn::text LIKE '%download_my_data%'
       AND position($v$to_jsonb('2.7.0'::text)$v$ IN v_new) = 0 THEN
      RAISE EXCEPTION 'policy_270: export does not report 2.7.0';
    END IF;

    EXECUTE v_new;
  END LOOP;
END;
$migration$;

COMMENT ON FUNCTION public.begin_signup_consent_transaction(text,jsonb) IS
  'Rate-limited explicit consent intake: earlier versions for installed clients and current 2.7.0; actual displayed version is preserved.';
NOTIFY pgrst, 'reload schema';
