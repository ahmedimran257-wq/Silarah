-- The admin member directory's Plan column showed "Free" for closed-test
-- testers on staff-granted test Premium, because it read only the paid
-- subscription status. Members with no paid subscription and an active
-- test Premium grant are now reported as 'test_premium'. Paid statuses
-- (active, grace) still win. Only that one output column changes; the
-- signature, audit write, owner and grants stay as they are.

DO $$
DECLARE
  fn constant regprocedure :=
    'public.admin_user_directory_keyset(text,integer,timestamp with time zone,uuid)'::regprocedure;
  body text := pg_get_functiondef(fn);
  old_col constant text := E'    page.subscription_status::text,\n';
  new_col constant text := E'    CASE\n'
    || E'      WHEN coalesce(page.subscription_status::text, ''none'') = ''none''\n'
    || E'       AND EXISTS (SELECT 1 FROM private.test_premium_grants g\n'
    || E'                   WHERE g.user_id = page.id AND g.revoked_at IS NULL\n'
    || E'                     AND g.starts_at <= now() AND g.expires_at > now())\n'
    || E'      THEN ''test_premium''\n'
    || E'      ELSE page.subscription_status::text\n'
    || E'    END,\n';
BEGIN
  IF position(old_col IN body) = 0 THEN
    RAISE EXCEPTION 'admin_user_directory_keyset no longer has the expected plan column';
  END IF;
  EXECUTE replace(body, old_col, new_col);
END
$$;
