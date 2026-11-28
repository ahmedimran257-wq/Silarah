-- Rollback test for migration 325 (call minutes money integrity;
-- docs/voice_calling_spec.md 6.1-6.6). STAGING only:
--   supabase db query --remote=ykmgkrveucslglxvcyss --file <(BEGIN + 324/325 if not applied + this) --yes
-- One transaction ending in ROLLBACK; the last SELECT prints one row per rule.
-- now() is fixed inside a transaction, so "time passing" is shown by moving
-- stored times back.
BEGIN;

CREATE TEMP TABLE t_results (n serial, name text, ok boolean, detail text) ON COMMIT DROP;

CREATE FUNCTION pg_temp.ok(p_name text, p_ok boolean, p_detail text DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO t_results(name, ok, detail) VALUES (p_name, coalesce(p_ok, false), p_detail);
$$;

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

CREATE FUNCTION pg_temp.usr(p_user uuid, p_sql text) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims',
    jsonb_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  EXECUTE p_sql INTO v;
  PERFORM set_config('role', 'postgres', true);
  RETURN v;
EXCEPTION WHEN OTHERS THEN
  PERFORM set_config('role', 'postgres', true);
  RETURN jsonb_build_object('error', SQLSTATE, 'message', SQLERRM);
END $$;

CREATE FUNCTION pg_temp.member(p_id uuid, p_gender text, p_first text, p_premium boolean)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO auth.users(id, aud, role, email, email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data)
  VALUES (p_id, 'authenticated', 'authenticated',
    'vcqa.' || right(p_id::text, 4) || '@gmail.com', now(), now(), now(), '{}', '{}');
  INSERT INTO public.users(id, email, gender, country_code, timezone,
    subscription_status, subscription_expires_at)
  VALUES (p_id, 'vcqa.' || right(p_id::text, 4) || '@gmail.com', p_gender, 'IN', 'Asia/Kolkata',
    CASE WHEN p_premium THEN 'active' ELSE 'none' END,
    CASE WHEN p_premium THEN now() + interval '30 days' END);
  INSERT INTO public.profiles(user_id, first_name, last_name, date_of_birth, gender,
    country_code, visibility, onboarding_completed, city_id)
  VALUES (p_id, p_first, 'Qatest', date '1995-01-01', p_gender, 'IN', 'visible', true, (SELECT c.id FROM public.cities c JOIN public.regions r ON r.id = c.region_id WHERE upper(r.country_code) = 'IN' ORDER BY c.id LIMIT 1));
  INSERT INTO public.notification_prefs(user_id, quiet_start, quiet_end)
  VALUES (p_id, time '00:00', time '00:00')
  ON CONFLICT (user_id) DO UPDATE SET quiet_start = time '00:00', quiet_end = time '00:00';
  INSERT INTO public.user_fcm_tokens(user_id, device_id, fcm_token, platform)
  VALUES (p_id, 'vcqa-' || replace(p_id::text, '-', ''), 'vcqa-token-' || p_id, 'android')
  ON CONFLICT (user_id, device_id) DO NOTHING;
  INSERT INTO private.call_device_capabilities(user_id, device_id, can_ring)
  VALUES (p_id, 'vcqa-' || replace(p_id::text, '-', ''), true)
  ON CONFLICT (user_id, device_id) DO UPDATE SET can_ring = true;
END $$;

CREATE FUNCTION pg_temp.match(p_a uuid, p_b uuid) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v uuid;
BEGIN
  INSERT INTO public.matches(user_a, user_b, status, guardian_approved)
  VALUES (p_a, p_b, 'active', true) RETURNING id INTO v;
  RETURN v;
END $$;

-- A subscription event as the billing RPC records it: the event first,
-- then the member's state.
CREATE FUNCTION pg_temp.sub_event(p_user uuid, p_type text, p_status text, p_expires timestamptz)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE ts bigint := (extract(epoch FROM clock_timestamp()) * 1000)::bigint;
BEGIN
  INSERT INTO public.subscription_events(user_id, provider_event_id, event_type,
    event_timestamp_ms, product_id, expires_at)
  VALUES (p_user, 'vcqa-' || gen_random_uuid(), p_type, ts, 'silarah_premium_monthly', p_expires);
  UPDATE public.users SET subscription_status = p_status, subscription_expires_at = p_expires,
    last_billing_event_ts = ts
  WHERE id = p_user;
END $$;

CREATE FUNCTION pg_temp.wallet(p_user uuid) RETURNS jsonb LANGUAGE sql AS $$
  SELECT to_jsonb(w) FROM private.call_wallets w WHERE w.user_id = p_user;
$$;

-- Moves p_user's run back by p_days, as if it started then.
CREATE FUNCTION pg_temp.age_run(p_user uuid, p_days integer) RETURNS void LANGUAGE sql AS $$
  UPDATE private.call_included_periods
  SET period_start = period_start - make_interval(days => p_days),
      period_end = period_end - make_interval(days => p_days)
  WHERE user_id = p_user;
  UPDATE private.call_wallets
  SET included_anchor_at = included_anchor_at - make_interval(days => p_days)
  WHERE user_id = p_user;
$$;

CREATE FUNCTION pg_temp.credit(p_user uuid, p_tx text, p_product text DEFAULT 'silarah_calls_20')
RETURNS jsonb LANGUAGE sql AS $$
  SELECT pg_temp.svc(format('SELECT public.call_service_credit_pack(%L, %L, %L, %L)',
    p_user, 'ev-buy-' || p_tx, p_tx, p_product));
$$;

CREATE FUNCTION pg_temp.refund(p_app text, p_tx text, p_event text, p_product text DEFAULT 'silarah_calls_20')
RETURNS jsonb LANGUAGE sql AS $$
  SELECT pg_temp.svc(format('SELECT public.call_service_refund_pack(%L, %L, %L, %L)',
    p_app, p_event, p_tx, p_product));
$$;

CREATE FUNCTION pg_temp.reverse(p_app text, p_tx text, p_event text, p_product text DEFAULT 'silarah_calls_20')
RETURNS jsonb LANGUAGE sql AS $$
  SELECT pg_temp.svc(format('SELECT public.call_service_reverse_pack_refund(%L, %L, %L, %L)',
    p_app, p_event, p_tx, p_product));
$$;

DO $$
BEGIN
  DELETE FROM private.call_jobs;
  DELETE FROM private.call_plans;
  DELETE FROM private.call_requests;
  DELETE FROM private.call_usage_months;
  UPDATE private.call_settings SET calls_enabled = true, monthly_cap_minutes = 100000,
    auto_cap_minutes = NULL, auto_cap_at = NULL, calling_consent_version = NULL;
END $$;

DO $$
DECLARE
  m1 uuid := '00000000-0000-4000-8000-0000000e0001'; -- man, Premium (subscription)
  w1 uuid := '00000000-0000-4000-8000-0000000e0002'; -- woman, free
  m2 uuid := '00000000-0000-4000-8000-0000000e0003'; -- man, free; gets a test grant
  m3 uuid := '00000000-0000-4000-8000-0000000e0004'; -- man, Premium: packs
  m4 uuid := '00000000-0000-4000-8000-0000000e0005'; -- man, Premium: live-call scenarios
  w2 uuid := '00000000-0000-4000-8000-0000000e0006'; -- woman, free
  m5 uuid := '00000000-0000-4000-8000-0000000e0007'; -- man, free: lapsed copy for the sweep
  k_m1w1 uuid; k_m4w2 uuid;
  r jsonb; r2 jsonb; w jsonb; anchor0 timestamptz; rid uuid; n integer; cap0 integer;
  synth private.call_wallets%ROWTYPE; t record;
BEGIN
  PERFORM pg_temp.member(m1, 'male', 'Arif', true);
  PERFORM pg_temp.member(w1, 'female', 'Sana', false);
  PERFORM pg_temp.member(m2, 'male', 'Bilal', false);
  PERFORM pg_temp.member(m3, 'male', 'Kamran', true);
  PERFORM pg_temp.member(m4, 'male', 'Danish', true);
  PERFORM pg_temp.member(w2, 'female', 'Hina', false);
  PERFORM pg_temp.member(m5, 'male', 'Faraz', false);
  k_m1w1 := pg_temp.match(m1, w1);
  k_m4w2 := pg_temp.match(m4, w2);

  -- ---- 6.1 Premium runs --------------------------------------------------------
  r := pg_temp.usr(m1, 'SELECT public.get_my_call_wallet()');
  w := pg_temp.wallet(m1);
  PERFORM pg_temp.ok('a Premium member has a run and 30 included minutes',
    (w->>'included_anchor_at') IS NOT NULL AND (r->>'included_minutes')::int = 30, r::text);
  PERFORM pg_temp.ok('the run knows when Premium coverage ends',
    (w->>'premium_covered_until')::timestamptz = now() + interval '30 days', w::text);
  PERFORM pg_temp.ok('the minutes card gets the Premium end date',
    (r->>'premium_until')::timestamptz = now() + interval '30 days', r::text);
  PERFORM pg_temp.ok('no renewal is promised without a renewing subscription event',
    (r->>'will_renew')::boolean = false, r::text);

  PERFORM pg_temp.age_run(m1, 10);
  UPDATE private.call_included_periods SET used_minutes = 25 WHERE user_id = m1;
  anchor0 := (pg_temp.wallet(m1)->>'included_anchor_at')::timestamptz;
  PERFORM pg_temp.usr(m1, 'SELECT public.get_my_call_wallet()');
  PERFORM pg_temp.usr(m1, 'SELECT public.get_my_call_overview()');
  PERFORM pg_temp.ok('reads never move the run',
    (pg_temp.wallet(m1)->>'included_anchor_at')::timestamptz = anchor0, pg_temp.wallet(m1)::text);

  PERFORM pg_temp.sub_event(m1, 'RENEWAL', 'active', now() + interval '40 days');
  w := pg_temp.wallet(m1);
  r := pg_temp.usr(m1, 'SELECT public.get_my_call_wallet()');
  PERFORM pg_temp.ok('a renewal before the end continues the run',
    (w->>'included_anchor_at')::timestamptz = anchor0
    AND (w->>'premium_covered_until')::timestamptz = now() + interval '40 days', w::text);
  PERFORM pg_temp.ok('renewing subscription: the card may say it renews',
    (r->>'will_renew')::boolean AND (r->>'included_minutes')::int = 5, r::text);

  PERFORM pg_temp.sub_event(m1, 'CANCELLATION', 'active', now() + interval '40 days');
  r := pg_temp.usr(m1, 'SELECT public.get_my_call_wallet()');
  PERFORM pg_temp.ok('cancelled (no renewal): the card shows the end date, run unchanged',
    NOT (r->>'will_renew')::boolean AND (pg_temp.wallet(m1)->>'included_anchor_at')::timestamptz = anchor0,
    r::text);

  PERFORM pg_temp.sub_event(m1, 'BILLING_ISSUE', 'grace', now() + interval '3 days');
  r := pg_temp.usr(m1, 'SELECT public.get_my_call_wallet()');
  PERFORM pg_temp.ok('grace / billing retry counts as Premium; same run',
    (r->>'premium')::boolean AND (pg_temp.wallet(m1)->>'included_anchor_at')::timestamptz = anchor0
    AND NOT (r->>'will_renew')::boolean, r::text);

  PERFORM pg_temp.sub_event(m1, 'EXPIRATION', 'none', NULL);
  w := pg_temp.wallet(m1);
  PERFORM pg_temp.ok('Premium ending ends the run at once (event), keeping it for a renewal',
    (w->>'included_anchor_at') IS NULL AND (w->>'last_run_anchor_at')::timestamptz = anchor0
    AND (w->>'last_run_ended_at')::timestamptz = now() AND (w->>'premium_covered_until') IS NULL, w::text);
  UPDATE private.call_wallets SET pack_minutes = 12 WHERE user_id = m1;
  r := pg_temp.usr(m1, 'SELECT public.get_my_call_wallet()');
  PERFORM pg_temp.ok('lapsed: nothing to spend, pack minutes kept',
    NOT (r->>'premium')::boolean AND (r->>'available_minutes')::int = 0
    AND (r->>'pack_minutes')::int = 12 AND (pg_temp.wallet(m1)->>'included_anchor_at') IS NULL, r::text);

  PERFORM pg_temp.sub_event(m1, 'RENEWAL', 'active', now() + interval '30 days');
  r := pg_temp.usr(m1, 'SELECT public.get_my_call_wallet()');
  PERFORM pg_temp.ok('a renewal after a lapse (billing retry recovered) continues the same run',
    (pg_temp.wallet(m1)->>'included_anchor_at')::timestamptz = anchor0
    AND (r->>'included_minutes')::int = 5, r::text);

  PERFORM pg_temp.sub_event(m1, 'EXPIRATION', 'none', NULL);
  PERFORM pg_temp.sub_event(m1, 'INITIAL_PURCHASE', 'active', now() + interval '30 days');
  r := pg_temp.usr(m1, 'SELECT public.get_my_call_wallet()');
  PERFORM pg_temp.ok('a new purchase after Premium ended starts a fresh run with full minutes',
    (pg_temp.wallet(m1)->>'included_anchor_at')::timestamptz = now()
    AND (r->>'included_minutes')::int = 30 AND (r->>'period_end' IS NULL OR true), r::text);

  -- Coverage that ran out with nobody noticing: the end is when it ran out.
  SELECT * INTO synth FROM private.call_wallets WHERE user_id = m1;
  synth.included_anchor_at := now() - interval '20 days';
  synth.premium_covered_until := now() - interval '2 hours';
  UPDATE public.users SET subscription_status = 'none', subscription_expires_at = NULL WHERE id = m5;
  SELECT * INTO t FROM private.call_premium_run_target(m5, synth, NULL);
  PERFORM pg_temp.ok('a run ends when its coverage ran out, not when someone looks',
    t.anchor_at IS NULL AND t.last_ended_at = now() - interval '2 hours'
    AND t.last_anchor_at = now() - interval '20 days', to_jsonb(t)::text);
  INSERT INTO private.call_wallets(user_id, included_anchor_at, premium_covered_until)
  VALUES (m5, now() - interval '20 days', now() - interval '2 hours')
  ON CONFLICT (user_id) DO UPDATE SET included_anchor_at = EXCLUDED.included_anchor_at,
    premium_covered_until = EXCLUDED.premium_covered_until;
  PERFORM private.call_sync_due_premium_runs();
  w := pg_temp.wallet(m5);
  PERFORM pg_temp.ok('the expiry sweep closes it with the same end time',
    (w->>'included_anchor_at') IS NULL AND (w->>'last_run_ended_at')::timestamptz = now() - interval '2 hours',
    w::text);
  UPDATE private.call_wallets SET included_anchor_at = now() - interval '20 days',
    premium_covered_until = now() - interval '2 hours', last_run_anchor_at = NULL, last_run_ended_at = NULL
  WHERE user_id = m5;
  PERFORM pg_temp.usr(m5, 'SELECT public.get_my_call_overview()');
  w := pg_temp.wallet(m5);
  PERFORM pg_temp.ok('a read reaches the very same state as the sweep',
    (w->>'included_anchor_at') IS NULL AND (w->>'last_run_ended_at')::timestamptz = now() - interval '2 hours',
    w::text);

  -- Grants (promo / referral / test) are Premium runs too.
  INSERT INTO private.test_premium_grants(batch_id, user_id, starts_at, expires_at, reason)
  VALUES ('device-test-vcqa-money', m2, now() - interval '3 days', now() + interval '4 days', 'owner_supervised_device_qa');
  w := pg_temp.wallet(m2);
  r := pg_temp.usr(m2, 'SELECT public.get_my_call_wallet()');
  PERFORM pg_temp.ok('a test grant starts a run at the grant start with included minutes',
    (w->>'included_anchor_at')::timestamptz = now() - interval '3 days'
    AND (r->>'included_minutes')::int = 30, r::text);
  INSERT INTO private.test_premium_grants(batch_id, user_id, starts_at, expires_at, reason)
  VALUES ('device-test-vcqa-money-two', m2, now() + interval '4 days', now() + interval '9 days', 'owner_supervised_device_qa');
  PERFORM pg_temp.ok('a grant that starts as the last one ends extends the same run',
    (pg_temp.wallet(m2)->>'premium_covered_until')::timestamptz = now() + interval '9 days'
    AND (pg_temp.wallet(m2)->>'included_anchor_at')::timestamptz = now() - interval '3 days',
    pg_temp.wallet(m2)::text);
  cap0 := private.call_refresh_month_cap();
  UPDATE private.test_premium_grants SET revoked_at = now() WHERE user_id = m2;
  PERFORM pg_temp.ok('the monthly brake counts grant members',
    private.call_refresh_month_cap() <= cap0 - 30, cap0::text);
  PERFORM pg_temp.ok('revoking the grant ends the run',
    (pg_temp.wallet(m2)->>'included_anchor_at') IS NULL, pg_temp.wallet(m2)::text);
  -- 336: staff undo the revoke: the same run carries on (no fresh minutes).
  UPDATE private.test_premium_grants SET revoked_at = NULL WHERE user_id = m2;
  PERFORM pg_temp.ok('undoing a grant revoke continues the same run',
    (pg_temp.wallet(m2)->>'included_anchor_at')::timestamptz = now() - interval '3 days',
    pg_temp.wallet(m2)::text);
  UPDATE private.test_premium_grants SET revoked_at = now() WHERE user_id = m2;

  -- ---- 6.2 Pack refunds ----------------------------------------------------------
  r := pg_temp.refund(m3::text, 'tx-early', 'ev-ref-early');
  PERFORM pg_temp.ok('a refund before its purchase changes nothing yet',
    r->>'reason' = 'pending_purchase' AND coalesce((pg_temp.wallet(m3)->>'pack_minutes')::int, 0) = 0
    AND coalesce((pg_temp.wallet(m3)->>'pack_refund_count')::int, 0) = 0, r::text);
  r := pg_temp.credit(m3, 'tx-early');
  PERFORM pg_temp.ok('the purchase arrives: credited and netted against the early refund',
    (r->>'applied')::boolean AND (r->>'refunded')::boolean
    AND (pg_temp.wallet(m3)->>'pack_minutes')::int = 0
    AND (pg_temp.wallet(m3)->>'pack_refund_count')::int = 1, r::text || pg_temp.wallet(m3)::text);
  r := pg_temp.refund(m3::text, 'tx-early', 'ev-ref-early');
  PERFORM pg_temp.ok('the same refund again changes nothing',
    r->>'reason' = 'duplicate' AND (pg_temp.wallet(m3)->>'pack_minutes')::int = 0, r::text);
  r := pg_temp.refund(m3::text, 'tx-none', 'ev-ref-none');
  PERFORM pg_temp.ok('a refund with no purchase never takes minutes',
    r->>'reason' = 'pending_purchase' AND (pg_temp.wallet(m3)->>'pack_minutes')::int = 0, r::text);

  PERFORM pg_temp.credit(m3, 'tx-a', 'silarah_calls_60');
  r := pg_temp.refund('someone-else', 'tx-a', 'ev-ref-a', 'silarah_calls_20');
  PERFORM pg_temp.ok('a refund applies to the purchase it belongs to (member, product size)',
    (r->>'applied')::boolean AND (r->>'user_id')::uuid = m3 AND (r->>'minutes')::int = -60
    AND (pg_temp.wallet(m3)->>'pack_minutes')::int = 0
    AND (pg_temp.wallet(m3)->>'pack_refund_count')::int = 2, r::text);
  r := pg_temp.reverse(m3::text, 'tx-a', 'ev-rev-a');
  PERFORM pg_temp.ok('a reversed refund gives the minutes back and lowers the refund count',
    (r->>'applied')::boolean AND (pg_temp.wallet(m3)->>'pack_minutes')::int = 60
    AND (pg_temp.wallet(m3)->>'pack_refund_count')::int = 1, r::text);
  r := pg_temp.reverse(m3::text, 'tx-a', 'ev-rev-a2');
  PERFORM pg_temp.ok('a reversal counts once per transaction',
    r->>'reason' = 'duplicate' AND (pg_temp.wallet(m3)->>'pack_minutes')::int = 60, r::text);
  r := pg_temp.reverse(m3::text, 'tx-none', 'ev-rev-none');
  r2 := pg_temp.credit(m3, 'tx-none');
  PERFORM pg_temp.ok('reversing a refund still waiting drops it; the purchase then counts in full',
    r->>'reason' = 'pending_refund_dropped' AND NOT (r2->>'refunded')::boolean
    AND (pg_temp.wallet(m3)->>'pack_minutes')::int = 80, r::text || r2::text);
  r := pg_temp.reverse(m3::text, 'tx-never', 'ev-rev-never');
  PERFORM pg_temp.ok('a reversal without a refund changes nothing',
    r->>'reason' = 'no_refund' AND (pg_temp.wallet(m3)->>'pack_minutes')::int = 80, r::text);

  -- ---- 6.3 Unclaimed packs ------------------------------------------------------
  n := (SELECT count(*) FROM public.admin_notifications WHERE type = 'call_pack_unclaimed');
  r := pg_temp.svc(format('SELECT public.call_service_store_unclaimed_pack(%L, %L, %L, %L, %L, %L, %L, now(), %L)',
    'ev-anon-1', '$RCAnonymousID:abc', ARRAY['$RCAnonymousID:abc'], 'silarah_calls_150', 'tx-anon-1',
    'PLAY_STORE', 'PRODUCTION', 'not_a_member'));
  PERFORM pg_temp.ok('a pack paid by an unknown store account is kept and staff are alerted',
    (r->>'stored')::boolean AND NOT (r->>'claimed')::boolean
    AND (SELECT count(*) FROM public.admin_notifications WHERE type = 'call_pack_unclaimed') = n + 1, r::text);
  r := pg_temp.svc(format('SELECT public.call_service_store_unclaimed_pack(%L, %L, %L, %L, %L, %L, %L, now(), %L)',
    'ev-anon-1', '$RCAnonymousID:abc', ARRAY['$RCAnonymousID:abc'], 'silarah_calls_150', 'tx-anon-1',
    'PLAY_STORE', 'PRODUCTION', 'not_a_member'));
  PERFORM pg_temp.ok('a repeated delivery is stored once', r->>'reason' = 'duplicate', r::text);
  r := pg_temp.refund('$RCAnonymousID:abc', 'tx-anon-1', 'ev-anon-ref');
  PERFORM pg_temp.ok('its refund waits for the claim', r->>'reason' = 'pending_purchase', r::text);
  r := pg_temp.svc(format('SELECT public.call_service_claim_unclaimed_packs(%L, %L, %L)',
    m4, ARRAY['$RCAnonymousID:abc', m4::text], 'transfer'));
  w := pg_temp.wallet(m4);
  PERFORM pg_temp.ok('a transfer to a member credits it, netted against the waiting refund',
    (r->>'claimed')::int = 1 AND coalesce((w->>'pack_minutes')::int, 0) = 0
    AND (w->>'pack_refund_count')::int = 1
    AND (SELECT claimed_user_id FROM private.call_pack_unclaimed WHERE provider_event_id = 'ev-anon-1') = m4,
    r::text || w::text);
  r := pg_temp.svc(format('SELECT public.call_service_claim_unclaimed_packs(%L, %L, %L)',
    m4, ARRAY['$RCAnonymousID:abc'], 'transfer'));
  PERFORM pg_temp.ok('a claimed pack is never credited twice', (r->>'claimed')::int = 0, r::text);
  r := pg_temp.svc(format('SELECT public.call_service_store_unclaimed_pack(%L, %L, %L, %L, %L, %L, %L, now(), %L)',
    'ev-anon-2', '$RCAnonymousID:def', ARRAY['$RCAnonymousID:def', m4::text], 'silarah_calls_20', 'tx-anon-2',
    'PLAY_STORE', 'PRODUCTION', 'not_a_member'));
  PERFORM pg_temp.ok('a store account already linked to a member is credited at once',
    (r->>'claimed')::boolean AND (pg_temp.wallet(m4)->>'pack_minutes')::int = 20, r::text);
  r := pg_temp.usr(m4, format('SELECT public.admin_claim_unclaimed_call_pack(%L, %L, %L)', 'ev-anon-1', m4, 'member asked'));
  PERFORM pg_temp.ok('members cannot claim packs', r->>'error' = '42501', r::text);
  r := pg_temp.usr(m4, 'SELECT public.admin_unclaimed_call_packs(false)');
  PERFORM pg_temp.ok('members cannot list unclaimed packs', r->>'error' = '42501', r::text);
  r := pg_temp.usr(m4, format('SELECT public.call_service_store_unclaimed_pack(%L, %L, %L, %L, %L, %L, %L, now(), %L)',
    'ev-x', 'x', ARRAY['x'], 'silarah_calls_20', 'tx-x', 'PLAY_STORE', 'PRODUCTION', 'x'));
  r2 := pg_temp.usr(m4, format('SELECT public.call_service_reverse_pack_refund(%L, %L, %L, %L)', 'x', 'e', 't', 'silarah_calls_20'));
  PERFORM pg_temp.ok('members cannot call the pack service RPCs',
    r->>'error' = '42501' AND r2->>'error' = '42501', r::text || r2::text);

  r := pg_temp.svc(format('SELECT public.call_service_store_unclaimed_pack(%L, %L, %L, %L, %L, %L, %L, now(), %L)',
    'ev-anon-notx', '$RCAnonymousID:ghi', ARRAY['$RCAnonymousID:ghi'], 'silarah_calls_20', NULL,
    'PLAY_STORE', 'PRODUCTION', 'not_a_member'));
  r := pg_temp.svc(format('SELECT public.call_service_claim_unclaimed_packs(%L, %L, %L)',
    m5, ARRAY['$RCAnonymousID:ghi'], 'transfer'));
  PERFORM pg_temp.ok('a kept pack without a store transaction id can still be credited once',
    (r->>'claimed')::int = 1 AND (pg_temp.wallet(m5)->>'pack_minutes')::int = 20, r::text);
  UPDATE public.users SET deleted_at = now() WHERE id = m5;
  r := pg_temp.credit(m5, 'tx-grace');
  PERFORM pg_temp.ok('a member in the deletion grace period still gets a pack they paid for',
    (r->>'applied')::boolean AND (pg_temp.wallet(m5)->>'pack_minutes')::int = 40, r::text);
  UPDATE public.users SET deleted_at = NULL WHERE id = m5;

  -- ---- 6.4 Live calls and holds --------------------------------------------------
  -- Included minutes are used before pack minutes, for the hold and the charge.
  UPDATE private.call_wallets SET pack_minutes = 20 WHERE user_id = m4;
  PERFORM pg_temp.usr(m4, 'SELECT public.get_my_call_wallet()');
  UPDATE private.call_included_periods SET used_minutes = 20 WHERE user_id = m4;
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m4, k_m4w2));
  rid := (r->>'request_id')::uuid;
  r := pg_temp.svc(format('SELECT public.call_service_accept(%L, %L, NULL)', w2, rid));
  PERFORM pg_temp.ok('the hold takes included minutes first, then pack minutes',
    (SELECT included_minutes = 10 AND pack_minutes = 20 FROM private.call_holds WHERE request_id = rid),
    (SELECT jsonb_agg(to_jsonb(h)) FROM private.call_holds h WHERE request_id = rid)::text);
  -- The included period resets during the call: the next period begins now.
  anchor0 := (SELECT period_start FROM private.call_holds WHERE request_id = rid);
  PERFORM pg_temp.age_run(m4, 30);
  UPDATE private.call_holds SET period_start = period_start - interval '30 days' WHERE request_id = rid;
  -- A pack refund during the call: the call goes on from its hold.
  -- (the 20 pack minutes now held came from tx-anon-2)
  r := pg_temp.refund(m4::text, 'tx-anon-2', 'ev-ref-live');
  PERFORM pg_temp.ok('a pack refunded during a call is taken at once',
    (r->>'applied')::boolean AND (pg_temp.wallet(m4)->>'pack_minutes')::int = -20, r::text);
  PERFORM pg_temp.svc(format('SELECT public.call_service_end(%L, %L, %L)', m4, rid, 'hangup'));
  PERFORM pg_temp.svc(format('SELECT jsonb_build_object(''done'', true) FROM (SELECT public.call_service_stream_end_confirmed(%L)) x', rid));
  r := pg_temp.svc(format('SELECT public.call_service_settle(%L, 721, %L)', rid, 'test'));
  r2 := pg_temp.usr(m4, 'SELECT public.get_my_call_wallet()');
  PERFORM pg_temp.ok('settled per started minute: 721 s = 13 min, included first',
    (SELECT charged_minutes = 13 AND charged_included_minutes = 10 AND charged_pack_minutes = 3
     FROM private.call_sessions WHERE request_id = rid), r::text);
  PERFORM pg_temp.ok('unused hold goes back to the period it came from; the new period is full',
    (SELECT used_minutes FROM private.call_included_periods
     WHERE user_id = m4 AND period_start = anchor0 - interval '30 days') = 30
    AND (r2->>'included_minutes')::int = 30, r2::text);
  PERFORM pg_temp.ok('a pack refunded during the call: finished from the hold, then negative',
    (r2->>'pack_minutes')::int = -3 AND (r2->>'available_minutes')::int = 0, r2::text);
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m4, k_m4w2));
  PERFORM pg_temp.ok('a negative balance blocks the next call', r->>'outcome' = 'balance_negative', r::text);

  -- ---- 6.5 Calling terms ---------------------------------------------------------
  UPDATE private.call_wallets SET pack_minutes = 0 WHERE user_id = m4;
  PERFORM pg_temp.ok('version check: later versions count, earlier ones do not',
    private.call_version_at_least('2.1', '2.0') AND private.call_version_at_least('10.0', '9.0')
    AND NOT private.call_version_at_least('2.0', '2.1') AND NOT private.call_version_at_least(NULL, '1.0'), NULL);
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('no terms version set: calling works as before', r->>'outcome' = 'ringing', r::text);
  UPDATE private.call_requests SET status = 'cancelled', reason = 'caller_cancelled', closed_at = now()
  WHERE id = (r->>'request_id')::uuid;
  UPDATE private.call_settings SET calling_consent_version = '9.0';
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('caller without the calling terms is asked to accept them',
    r->>'outcome' = 'consent_required', r::text);
  r := pg_temp.usr(m1, 'SELECT public.get_my_call_overview()');
  PERFORM pg_temp.ok('the overview says the terms are needed', (r->>'consent_required')::boolean, r::text);
  INSERT INTO public.user_consents(user_id, consent_type, version, granted_at)
  VALUES (m1, 'terms_of_service', '9.1', now());
  r := pg_temp.svc(format('SELECT public.call_service_request(%L, %L)', m1, k_m1w1));
  PERFORM pg_temp.ok('callee without the terms: neutral unavailable for the caller',
    r->>'outcome' = 'unavailable'
    AND (SELECT reason FROM private.call_requests WHERE id = (r->>'request_id')::uuid) = 'consent_required', r::text);
  r2 := pg_temp.svc(format('SELECT public.call_service_missed_push(%L)', r->>'request_id'));
  PERFORM pg_temp.ok('the callee''s missed call asks them to accept the terms',
    (r2->>'send')::boolean AND r2->>'variant' = 'consent', r2::text);
  r := pg_temp.usr(w1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_m1w1));
  PERFORM pg_temp.ok('planning a call needs the terms too', r->>'outcome' = 'consent_required', r::text);
  r := pg_temp.usr(m1, format('SELECT public.propose_call_plan(%L, now() + interval ''1 hour'')', k_m1w1));
  PERFORM pg_temp.ok('a plan with someone without the terms is neutral unavailable',
    r->>'outcome' = 'unavailable', r::text);
  UPDATE private.call_settings SET calling_consent_version = NULL;

  -- ---- 6.6 Data export -----------------------------------------------------------
  r := private.call_history_export(m3);
  PERFORM pg_temp.ok('the export sums the minutes ledger',
    (r->'minutes_summary'->>'packs_bought')::int = 3
    AND (r->'minutes_summary'->>'pack_minutes_bought')::int = 100
    AND (r->'minutes_summary'->>'pack_minutes_refunded')::int = 20, (r->'minutes_summary')::text);
END $$;

SELECT n, ok, name, detail FROM t_results ORDER BY n;
ROLLBACK;
