-- Rollback test for migration 342 (staff access links, remove staff, reset
-- authenticator, sign a member out). STAGING first:
--   (echo 'BEGIN;'; cat supabase/migrations/342_staff_access_links.sql; cat this file) > t.sql   # if 342 is not applied
-- One transaction ending in ROLLBACK; the last SELECT prints one row per rule.
BEGIN;

CREATE TEMP TABLE t_results (n serial, name text, ok boolean, detail text) ON COMMIT DROP;
CREATE FUNCTION pg_temp.ok(p_name text, p_ok boolean, p_detail text DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO t_results(name, ok, detail) VALUES (p_name, coalesce(p_ok, false), p_detail);
$$;

CREATE FUNCTION pg_temp.as_user(p_user uuid, p_sql text, p_staff boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_user, 'role', 'authenticated')
     || CASE WHEN p_staff THEN jsonb_build_object('aal', 'aal2', 'session_id', p_user) ELSE '{}'::jsonb END)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  EXECUTE p_sql INTO v;
  PERFORM set_config('role', 'postgres', true);
  RETURN v;
EXCEPTION WHEN OTHERS THEN
  PERFORM set_config('role', 'postgres', true);
  RETURN jsonb_build_object('error', SQLSTATE, 'message', SQLERRM);
END $$;

CREATE FUNCTION pg_temp.svc(p_sql text) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', '{"role":"service_role"}', true);
  PERFORM set_config('role', 'service_role', true);
  EXECUTE p_sql INTO v;
  PERFORM set_config('role', 'postgres', true);
  RETURN v;
EXCEPTION WHEN OTHERS THEN
  PERFORM set_config('role', 'postgres', true);
  RETURN jsonb_build_object('error', SQLSTATE, 'message', SQLERRM);
END $$;

-- p_role NULL: a plain member account with no staff role.
CREATE FUNCTION pg_temp.person(p_id uuid, p_role text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO auth.users(id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES (p_id, 'authenticated', 'authenticated', 'vcstaff.' || right(p_id::text, 6) || '@gmail.com', now(), now(), now(), '{}', '{}');
  INSERT INTO auth.sessions(id, user_id, created_at, updated_at, aal) VALUES (p_id, p_id, now(), now(), 'aal2');
  IF p_role IS NOT NULL THEN
    INSERT INTO public.admin_memberships(user_id, role, status) VALUES (p_id, p_role, 'active');
  END IF;
END $$;

DO $$
DECLARE
  boss uuid := gen_random_uuid();
  mod uuid := gen_random_uuid();
  sup uuid := gen_random_uuid();
  outsider uuid := gen_random_uuid();
  r jsonb;
  v_link text;
  v_token text;
  v_email uuid;
  n bigint;
BEGIN
  -- Only one super admin may exist in this transaction for the last-admin rule.
  PERFORM set_config('silarah.test', 'staff', true);
  PERFORM pg_temp.person(boss, 'super_admin');
  PERFORM pg_temp.person(mod, 'moderator');
  PERFORM pg_temp.person(sup, 'support');
  PERFORM pg_temp.person(outsider, NULL);
  -- A second (app) session for the support person, at AAL1.
  INSERT INTO auth.sessions(id, user_id, created_at, updated_at, aal) VALUES (gen_random_uuid(), sup, now(), now(), 'aal1');

  -- 1. Invites and reset links -------------------------------------------------
  r := pg_temp.as_user(mod, format('SELECT to_jsonb(public.admin_send_staff_access(%L, %L, %L))', sup, 'invite', 'https://admin.silarah.com'), true);
  PERFORM pg_temp.ok('only super admins send staff links', r->>'error' = 'P0001', r::text);
  r := pg_temp.as_user(boss, format('SELECT to_jsonb(public.admin_send_staff_access(%L, %L, %L))', sup, 'invite', 'https://evil.example/x?'), true);
  PERFORM pg_temp.ok('links only point at an admin site', r->>'error' = '22023', r::text);
  r := pg_temp.as_user(boss, format('SELECT to_jsonb(public.admin_send_staff_access(%L, %L, %L))', outsider, 'invite', 'https://admin.silarah.com'), true);
  PERFORM pg_temp.ok('links go only to active staff', r->>'error' = 'P0001', r::text);

  r := pg_temp.as_user(boss, format('SELECT to_jsonb(public.admin_send_staff_access(%L, %L, %L))', sup, 'invite', 'https://admin.silarah.com'), true);
  PERFORM pg_temp.ok('an invite lasts 72 hours',
    (r #>> '{}')::timestamptz BETWEEN now() + interval '71 hours' AND now() + interval '73 hours', r::text);
  SELECT e.link, e.id INTO v_link, v_email FROM private.staff_access_emails e WHERE e.user_id = sup AND e.kind = 'invite';
  v_token := split_part(v_link, 'token=', 2);
  PERFORM pg_temp.ok('the email holds the link; only a hash is stored',
    v_link LIKE 'https://admin.silarah.com/auth/accept?token=%' AND v_token ~ '^[0-9a-f]{64}$'
    AND NOT EXISTS (SELECT 1 FROM private.staff_access_tokens t WHERE t.token_hash = v_token)
    AND EXISTS (SELECT 1 FROM private.staff_access_tokens t
                WHERE t.token_hash = encode(extensions.digest(v_token, 'sha256'), 'hex')), NULL);
  PERFORM pg_temp.ok('sending an invite is audited',
    EXISTS (SELECT 1 FROM public.admin_audit_log a WHERE a.action_type = 'staff_invite_sent'
            AND a.admin_id = boss AND a.target_user_id = sup), NULL);

  r := pg_temp.svc('SELECT coalesce(jsonb_agg(to_jsonb(c)), ''[]''::jsonb) FROM public.claim_staff_access_emails(25) c');
  PERFORM pg_temp.ok('the email worker gets address, role, link and member flag',
    EXISTS (SELECT 1 FROM jsonb_array_elements(r) x
            WHERE (x->>'email_id')::uuid = v_email AND x->>'email_kind' = 'invite'
              AND x->>'staff_role' = 'support' AND x->>'link' = v_link
              AND x->>'recipient' LIKE 'vcstaff.%' AND (x->>'is_member') = 'false'), left(r::text, 300));
  r := pg_temp.as_user(sup, 'SELECT to_jsonb(count(*)) FROM public.claim_staff_access_emails(5)', true);
  PERFORM pg_temp.ok('staff cannot claim the email queue', r->>'error' = '42501', r::text);
  PERFORM pg_temp.svc(format('SELECT to_jsonb(public.complete_staff_access_email(%L, true, NULL))', v_email));
  PERFORM pg_temp.ok('a sent email forgets the link',
    (SELECT sent_at IS NOT NULL AND link IS NULL FROM private.staff_access_emails WHERE id = v_email), NULL);

  -- 2. Using the link -------------------------------------------------------------
  r := pg_temp.as_user(sup, format('SELECT coalesce(jsonb_agg(to_jsonb(c)), ''[]''::jsonb) FROM public.consume_staff_access_token(%L) c', v_token), true);
  PERFORM pg_temp.ok('only the admin worker can use a token', r->>'error' = '42501', r::text);
  r := pg_temp.svc(format('SELECT coalesce(jsonb_agg(to_jsonb(c)), ''[]''::jsonb) FROM public.consume_staff_access_token(%L) c', v_token));
  PERFORM pg_temp.ok('a fresh link signs in the right person',
    jsonb_array_length(r) = 1 AND (r->0->>'user_id')::uuid = sup AND r->0->>'kind' = 'invite', r::text);
  r := pg_temp.svc(format('SELECT coalesce(jsonb_agg(to_jsonb(c)), ''[]''::jsonb) FROM public.consume_staff_access_token(%L) c', v_token));
  PERFORM pg_temp.ok('a link works once', jsonb_array_length(r) = 0, r::text);
  r := pg_temp.svc(format('SELECT coalesce(jsonb_agg(to_jsonb(c)), ''[]''::jsonb) FROM public.consume_staff_access_token(%L) c', repeat('a', 64)));
  PERFORM pg_temp.ok('an unknown link does nothing', jsonb_array_length(r) = 0, r::text);

  -- A newer link replaces an older one.
  PERFORM pg_temp.as_user(boss, format('SELECT to_jsonb(public.admin_send_staff_access(%L, %L, %L))', mod, 'reset', 'https://admin.silarah.com'), true);
  SELECT split_part(link, 'token=', 2) INTO v_token FROM private.staff_access_emails WHERE user_id = mod AND kind = 'reset';
  PERFORM pg_temp.as_user(boss, format('SELECT to_jsonb(public.admin_send_staff_access(%L, %L, %L))', mod, 'reset', 'https://admin.silarah.com'), true);
  r := pg_temp.svc(format('SELECT coalesce(jsonb_agg(to_jsonb(c)), ''[]''::jsonb) FROM public.consume_staff_access_token(%L) c', v_token));
  PERFORM pg_temp.ok('an older link stops working when a new one is sent',
    jsonb_array_length(r) = 0
    AND (SELECT count(*) FROM private.staff_access_emails WHERE user_id = mod AND kind = 'reset' AND link IS NOT NULL) = 1, r::text);
  PERFORM pg_temp.ok('a reset link lasts one hour',
    (SELECT max(expires_at) BETWEEN now() + interval '59 minutes' AND now() + interval '61 minutes'
     FROM private.staff_access_tokens WHERE user_id = mod AND kind = 'reset'), NULL);

  -- 3. Forgot password from the sign-in page -----------------------------------------
  r := pg_temp.as_user(outsider, format('SELECT to_jsonb(public.request_staff_password_reset(%L, %L))', 'x@y.com', 'https://admin.silarah.com'));
  PERFORM pg_temp.ok('only the admin worker can request a reset', r->>'error' = '42501', r::text);
  SELECT count(*) INTO n FROM private.staff_access_emails;
  PERFORM pg_temp.svc(format('SELECT to_jsonb(public.request_staff_password_reset(%L, %L))',
    (SELECT email FROM auth.users WHERE id = outsider), 'https://admin.silarah.com'));
  PERFORM pg_temp.ok('a non-staff address gets nothing (and is not told)',
    (SELECT count(*) FROM private.staff_access_emails) = n, NULL);
  PERFORM pg_temp.svc(format('SELECT to_jsonb(public.request_staff_password_reset(%L, %L))',
    upper((SELECT email FROM auth.users WHERE id = boss)), 'https://admin.silarah.com'));
  PERFORM pg_temp.svc(format('SELECT to_jsonb(public.request_staff_password_reset(%L, %L))',
    (SELECT email FROM auth.users WHERE id = boss), 'https://admin.silarah.com'));
  PERFORM pg_temp.svc(format('SELECT to_jsonb(public.request_staff_password_reset(%L, %L))',
    (SELECT email FROM auth.users WHERE id = boss), 'https://admin.silarah.com'));
  PERFORM pg_temp.svc(format('SELECT to_jsonb(public.request_staff_password_reset(%L, %L))',
    (SELECT email FROM auth.users WHERE id = boss), 'https://admin.silarah.com'));
  PERFORM pg_temp.ok('staff get a reset link, at most 3 a day',
    (SELECT count(*) FROM private.staff_access_tokens WHERE user_id = boss AND kind = 'reset') = 3
    AND EXISTS (SELECT 1 FROM public.admin_audit_log a WHERE a.action_type = 'staff_password_reset_requested' AND a.target_user_id = boss), NULL);

  -- 4. Staff list -------------------------------------------------------------------
  INSERT INTO auth.mfa_factors(id, user_id, friendly_name, factor_type, status, created_at, updated_at, secret)
  VALUES (gen_random_uuid(), sup, 'Silarah Admin', 'totp', 'verified', now(), now(), 'JBSWY3DPEHPK3PXP');
  PERFORM pg_temp.as_user(boss, format('SELECT to_jsonb(public.admin_send_staff_access(%L, %L, %L))', sup, 'invite', 'https://admin.silarah.com'), true);
  r := pg_temp.as_user(boss, 'SELECT jsonb_agg(to_jsonb(s)) FROM public.admin_staff_members(100) s', true);
  PERFORM pg_temp.ok('the staff list shows authenticator and pending link',
    EXISTS (SELECT 1 FROM jsonb_array_elements(r) x WHERE (x->>'user_id')::uuid = sup
            AND (x->>'has_authenticator')::boolean AND x->>'link_pending_kind' = 'invite')
    AND EXISTS (SELECT 1 FROM jsonb_array_elements(r) x WHERE (x->>'user_id')::uuid = mod
            AND NOT (x->>'has_authenticator')::boolean), left(r::text, 300));
  r := pg_temp.as_user(mod, 'SELECT jsonb_agg(to_jsonb(s)) FROM public.admin_staff_members(100) s', true);
  PERFORM pg_temp.ok('only super admins see the staff list', r IS NULL OR r = 'null'::jsonb, coalesce(r::text, 'null'));

  -- 5. Reset authenticator ------------------------------------------------------------
  r := pg_temp.as_user(mod, format('SELECT to_jsonb(public.admin_reset_staff_mfa(%L, %L))', sup, 'Lost phone, ticket 12'), true);
  PERFORM pg_temp.ok('only super admins reset an authenticator', r->>'error' = 'P0001', r::text);
  r := pg_temp.as_user(boss, format('SELECT to_jsonb(public.admin_reset_staff_mfa(%L, %L))', boss, 'Lost my phone'), true);
  PERFORM pg_temp.ok('not your own authenticator', r->>'error' = '22023', r::text);
  r := pg_temp.as_user(boss, format('SELECT to_jsonb(public.admin_reset_staff_mfa(%L, %L))', sup, 'Lost phone, ticket 12'), true);
  PERFORM pg_temp.ok('reset removes the authenticator and admin sessions only',
    (r #>> '{}')::int = 1
    AND NOT EXISTS (SELECT 1 FROM auth.mfa_factors WHERE user_id = sup)
    AND NOT EXISTS (SELECT 1 FROM auth.sessions WHERE user_id = sup AND aal = 'aal2')
    AND EXISTS (SELECT 1 FROM auth.sessions WHERE user_id = sup AND aal = 'aal1'), r::text);
  PERFORM pg_temp.ok('the reset is audited with its reason',
    EXISTS (SELECT 1 FROM public.admin_audit_log a WHERE a.action_type = 'staff_mfa_reset'
            AND a.target_user_id = sup AND a.details->>'reason' = 'Lost phone, ticket 12'), NULL);

  -- 6. Remove staff --------------------------------------------------------------------
  r := pg_temp.as_user(boss, format('SELECT to_jsonb(public.admin_remove_staff_member(%L, %L))', boss, 'Leaving the team'), true);
  PERFORM pg_temp.ok('you cannot remove yourself', r->>'error' = '22023', r::text);
  r := pg_temp.as_user(boss, format('SELECT to_jsonb(public.admin_remove_staff_member(%L, %L))', mod, 'no'), true);
  PERFORM pg_temp.ok('removal needs a reason', r->>'error' = '22023', r::text);
  r := pg_temp.as_user(boss, format('SELECT to_jsonb(public.admin_remove_staff_member(%L, %L))', mod, 'Left the team on 28 Nov'), true);
  PERFORM pg_temp.ok('a super admin removes staff, links and admin sessions go too',
    NOT (r ? 'error')
    AND NOT EXISTS (SELECT 1 FROM public.admin_memberships WHERE user_id = mod)
    AND NOT EXISTS (SELECT 1 FROM private.staff_access_tokens WHERE user_id = mod AND used_at IS NULL)
    AND NOT EXISTS (SELECT 1 FROM auth.sessions WHERE user_id = mod AND aal = 'aal2')
    AND EXISTS (SELECT 1 FROM auth.users WHERE id = mod), r::text);
  PERFORM pg_temp.ok('removal is audited',
    EXISTS (SELECT 1 FROM public.admin_audit_log a WHERE a.action_type = 'staff_removed'
            AND a.target_user_id = mod AND a.details->>'reason' = 'Left the team on 28 Nov'), NULL);
  -- The last active super admin: demote every other one in this transaction.
  UPDATE public.admin_memberships SET status = 'revoked' WHERE role = 'super_admin' AND user_id <> boss;
  INSERT INTO public.admin_memberships(user_id, role, status) VALUES (outsider, 'super_admin', 'active');
  INSERT INTO auth.sessions(id, user_id, created_at, updated_at, aal) SELECT gen_random_uuid(), outsider, now(), now(), 'aal2';
  UPDATE public.admin_memberships SET status = 'revoked' WHERE user_id = boss;
  r := pg_temp.as_user(outsider, format('SELECT to_jsonb(public.admin_remove_staff_member(%L, %L))', boss, 'Testing the last-admin rule'), true);
  PERFORM pg_temp.ok('removing a revoked super admin is allowed', NOT (r ? 'error'), r::text);
  r := pg_temp.as_user(outsider, format('SELECT to_jsonb(public.admin_remove_staff_member(%L, %L))', sup, 'Support left'), true);
  PERFORM pg_temp.ok('other staff can be removed by the remaining super admin', NOT (r ? 'error'), r::text);

  -- 7. Sign a member out everywhere ------------------------------------------------------
  INSERT INTO auth.sessions(id, user_id, created_at, updated_at, aal) VALUES (gen_random_uuid(), mod, now(), now(), 'aal1');
  INSERT INTO public.admin_memberships(user_id, role, status) VALUES (mod, 'moderator', 'active');
  INSERT INTO auth.sessions(id, user_id, created_at, updated_at, aal) VALUES (mod, mod, now(), now(), 'aal2')
  ON CONFLICT (id) DO NOTHING;
  r := pg_temp.as_user(mod, format('SELECT to_jsonb(public.admin_sign_out_member(%L, %L))', sup, 'Phone stolen, member asked'), true);
  PERFORM pg_temp.ok('moderators can sign a member out everywhere',
    (r #>> '{}')::int >= 1 AND NOT EXISTS (SELECT 1 FROM auth.sessions WHERE user_id = sup)
    AND EXISTS (SELECT 1 FROM public.admin_audit_log a WHERE a.action_type = 'member_signed_out_everywhere'
                AND a.target_user_id = sup), r::text);
  r := pg_temp.as_user(sup, format('SELECT to_jsonb(public.admin_sign_out_member(%L, %L))', mod, 'Testing support role'));
  PERFORM pg_temp.ok('others cannot sign members out', r->>'error' = '42501', r::text);

  -- 8. Retry job still runs -------------------------------------------------------------
  PERFORM private.retry_account_emails();
  PERFORM pg_temp.ok('the hourly email retry still runs', true, NULL);
END $$;

SELECT n, ok, name, detail FROM t_results ORDER BY n;
ROLLBACK;
