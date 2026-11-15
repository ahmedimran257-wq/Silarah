-- Three staff functions reported "not found" with SQLSTATE P0002, which
-- PostgREST returns as HTTP 500. Staff saw the right message, but every
-- lookup miss (e.g. an email deletion request from an unregistered address)
-- counted as a server failure in the API logs and health checks. P0001 maps
-- to HTTP 400. Only the error code changes; bodies, owners and grants stay.

DO $$
DECLARE
  fn regprocedure;
  body text;
BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'public.admin_schedule_account_deletion(uuid,text,boolean)'::regprocedure,
    'public.admin_add_member_note(uuid,text)'::regprocedure,
    'public.admin_record_email_deletion_request(text,timestamp with time zone,text,boolean)'::regprocedure
  ] LOOP
    body := pg_get_functiondef(fn);
    IF position('ERRCODE = ''P0002''' IN body) > 0 THEN
      EXECUTE replace(body, 'ERRCODE = ''P0002''', 'ERRCODE = ''P0001''');
    END IF;
  END LOOP;
END
$$;
