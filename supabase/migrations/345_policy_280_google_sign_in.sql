-- Silarah — policy 2.8.0: Continue with Google in the Privacy Policy
-- (docs/google_sign_in_legal_draft.md). What Google shares at sign-in, how it
-- is used, Google as a sign-in provider, and how to remove access.
--
-- Backend first, like 264, 271 and 335. Installed clients keep working with
-- the version they actually display (2.4.0, 2.5.0, 2.6.0 where the
-- US/Canada bundle exists, and 2.7.0); new clients present and record 2.8.0.
-- 2.8.0 becomes the current notice for reminders and exports. No consent is
-- backfilled, and a reminder acknowledgement is never treated as consent.
--
-- Production has 264's bodies patched by 335; staging has 271's patched by
-- 335. Each function's CURRENT definition is patched in place: the
-- accepted-version list gains '2.8.0' and the current version becomes
-- '2.8.0'. Every patch checks its anchor and raises otherwise, so the whole
-- migration rolls back instead of half-applying. Re-running is a no-op.
--
-- Numbered 345 because 338-340 are used on other branches.

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
    IF position($v$'2.8.0'$v$ IN v_old) > 0 THEN
      CONTINUE;  -- already 2.8.0 (re-run)
    END IF;

    -- Accepted versions: ('2.4.0', '2.5.0'[, '2.6.0'], '2.7.0') -> ..., '2.8.0')
    v_lists := (SELECT count(*) FROM regexp_matches(v_old,
      $p$'2\.4\.0', '2\.5\.0'(, '2\.6\.0')?, '2\.7\.0'\)$p$, 'g'));
    v_new := regexp_replace(v_old,
      $p$('2\.4\.0', '2\.5\.0'(, '2\.6\.0')?, '2\.7\.0')\)$p$,
      $r$\1, '2.8.0')$r$, 'g');

    -- Current version: comparisons and the reported notice version.
    v_new := regexp_replace(v_new, $p$(<>|=) '2\.7\.0'$p$, $r$\1 '2.8.0'$r$, 'g');
    v_new := regexp_replace(v_new, $p$'2\.7\.0'::text$p$, $r$'2.8.0'::text$r$, 'g');

    -- Each function must have changed in the way its role requires.
    IF v_new = v_old THEN
      RAISE EXCEPTION 'policy_280: % unchanged', v_fn;
    END IF;
    IF v_fn::text LIKE '%begin_signup_consent_transaction%'
       OR v_fn::text LIKE '%finalize_signup_consents%'
       OR v_fn::text LIKE '%sync_my_user%'
       OR v_fn::text LIKE '%acknowledge_policy_reminder%' THEN
      IF v_lists = 0 THEN
        RAISE EXCEPTION 'policy_280: % has no accepted-version list', v_fn;
      END IF;
    END IF;
    IF v_fn::text LIKE '%get_my_policy_reminder_state%'
       AND position($v$SELECT '2.8.0'::text$v$ IN v_new) = 0 THEN
      RAISE EXCEPTION 'policy_280: reminder state does not report 2.8.0';
    END IF;
    IF v_fn::text LIKE '%download_my_data%'
       AND position($v$to_jsonb('2.8.0'::text)$v$ IN v_new) = 0 THEN
      RAISE EXCEPTION 'policy_280: export does not report 2.8.0';
    END IF;

    EXECUTE v_new;
  END LOOP;
END;
$migration$;

COMMENT ON FUNCTION public.begin_signup_consent_transaction(text,jsonb) IS
  'Rate-limited explicit consent intake: earlier versions for installed clients and current 2.8.0; actual displayed version is preserved.';
NOTIFY pgrst, 'reload schema';
