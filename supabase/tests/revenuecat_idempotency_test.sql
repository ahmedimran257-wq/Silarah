-- Synthetic billing only: the transaction rolls back before any worker can
-- see the outbox. No payment provider or email is contacted.
begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(27);

create temporary table billing_fixture as select
  gen_random_uuid() as member_id,
  gen_random_uuid() as other_id,
  gen_random_uuid() as missing_id,
  gen_random_uuid() as pair_id,
  gen_random_uuid()::text as event_id,
  (extract(epoch from now() - interval '1 minute') * 1000)::bigint as event_ms;
insert into auth.users(id) select member_id from billing_fixture
union all select other_id from billing_fixture
union all select pair_id from billing_fixture;
insert into public.users(id, email, country_code, gender)
select id, id::text || '@staging.silarah.invalid', 'IN', 'male'
from (select member_id as id from billing_fixture
      union all select other_id from billing_fixture
      union all select pair_id from billing_fixture) members;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local request.jwt.claim.role = 'service_role';

select extensions.ok(not has_function_privilege('authenticated',
  'public.apply_revenuecat_subscription_event(uuid,text,text,bigint,text,timestamptz,text,text,numeric,timestamptz)',
  'EXECUTE'), 'members cannot grant themselves a paid entitlement');
select extensions.ok(not has_function_privilege('anon',
  'public.apply_revenuecat_subscription_event(uuid,text,text,bigint,text,timestamptz,text,text,numeric,timestamptz)',
  'EXECUTE'), 'anonymous callers cannot apply billing events');

select extensions.is(public.apply_revenuecat_subscription_event(
  member_id, event_id, 'INITIAL_PURCHASE', event_ms, 'active', now() + interval '1 month'
)->>'reason', 'applied', 'initial purchase applies') from billing_fixture;
select extensions.is(public.apply_revenuecat_subscription_event(
  member_id, event_id, 'INITIAL_PURCHASE', event_ms, 'active', now() + interval '1 month'
)->>'reason', 'duplicate_event', 'provider retry is an acknowledged no-op') from billing_fixture;
select extensions.is((select count(*) from public.subscription_events e
  join billing_fixture f on e.user_id = f.member_id), 1::bigint, 'retry creates one ledger entry');
select extensions.is((select count(*) from public.transactional_email_outbox e
  join billing_fixture f on e.user_id = f.member_id), 1::bigint, 'retry creates one email intent');

select extensions.is(public.apply_revenuecat_subscription_event(
  member_id, event_id || '-stale', 'EXPIRATION', event_ms - 1, 'none', null
)->>'reason', 'stale_event', 'older expiration cannot replace newer purchase') from billing_fixture;
select extensions.ok((select u.subscription_status = 'active'
  and u.subscription_expires_at = now() + interval '1 month' + interval '10 minutes'
  and u.last_billing_event_ts = f.event_ms
  from public.users u join billing_fixture f on u.id = f.member_id),
  'stale event preserves entitlement, expiry and watermark');

select extensions.is(public.apply_revenuecat_subscription_event(
  member_id, event_id || '-expiry', 'EXPIRATION', event_ms + 1, 'none', null
)->>'reason', 'applied', 'newer expiration applies') from billing_fixture;
select extensions.ok((select u.subscription_status = 'none'
  and u.subscription_expires_at is null and u.last_billing_event_ts = f.event_ms + 1
  from public.users u join billing_fixture f on u.id = f.member_id),
  'expiration removes the paid entitlement and advances watermark');
select extensions.is((select count(*) from public.transactional_email_outbox e
  join billing_fixture f on e.user_id = f.member_id), 2::bigint,
  'stale event creates no email intent; newer expiration creates one');

select extensions.is(public.apply_revenuecat_subscription_event(
  other_id, event_id, 'INITIAL_PURCHASE', event_ms, 'active', now() + interval '1 month'
)->>'reason', 'duplicate_event', 'same provider event cannot grant a second account') from billing_fixture;
select extensions.ok((select u.subscription_status = 'none'
  and u.subscription_expires_at is null and u.last_billing_event_ts = 0
  from public.users u join billing_fixture f on u.id = f.other_id),
  'cross-account duplicate leaves other member unchanged');
select extensions.is(public.apply_revenuecat_subscription_event(
  missing_id, event_id || '-missing', 'INITIAL_PURCHASE', event_ms, 'active', now() + interval '1 month'
)->>'reason', 'user_not_found', 'unknown identity never creates a subscriber') from billing_fixture;
select extensions.is((select count(*) from public.subscription_events e
  join billing_fixture f on e.user_id = f.member_id), 3::bigint,
  'purchase, stale event and expiration retain exactly three audit entries');

-- Monthly and 3-month are separate Play subscriptions. A member holding
-- both keeps the access the other plan still pays for (migrations 286-287),
-- and paid access carries 10 minutes of renewal slack (291).
select extensions.is(public.apply_revenuecat_subscription_event(
  pair_id, event_id || '-pair-3mo', 'INITIAL_PURCHASE', event_ms + 100, 'active',
  now() + interval '80 days', 'silarah_three_month:three-month', 'INR', 1,
  now() + interval '80 days'
)->>'reason', 'applied', 'three-month purchase applies') from billing_fixture;
select extensions.is(public.apply_revenuecat_subscription_event(
  pair_id, event_id || '-pair-1mo', 'INITIAL_PURCHASE', event_ms + 200, 'active',
  now() + interval '30 days', 'silarah_monthly:monthly', 'INR', 1,
  now() + interval '30 days'
)->>'reason', 'applied', 'monthly purchase applies') from billing_fixture;
select extensions.ok((select u.subscription_status = 'active'
  and u.subscription_expires_at = now() + interval '80 days' + interval '10 minutes'
  from public.users u join billing_fixture f on u.id = f.pair_id),
  'a shorter plan cannot cut a longer plan short');
select extensions.is(public.apply_revenuecat_subscription_event(
  pair_id, event_id || '-pair-1mo-end', 'EXPIRATION', event_ms + 300, 'none',
  null, 'silarah_monthly:monthly', 'INR', 0, now() - interval '1 minute'
)->>'access_kept', 'true', 'one plan ending reports access kept') from billing_fixture;
select extensions.ok((select u.subscription_status = 'active'
  and public.has_active_premium(u.id)
  from public.users u join billing_fixture f on u.id = f.pair_id),
  'one plan ending keeps Premium the other plan pays for');
select extensions.is((select count(*) from public.transactional_email_outbox e
  join billing_fixture f on e.dedupe_key = 'revenuecat:' || f.event_id || '-pair-1mo-end'),
  0::bigint, 'no "subscription ended" email while the other plan continues');
select extensions.is(public.apply_revenuecat_subscription_event(
  pair_id, event_id || '-pair-3mo-end', 'EXPIRATION', event_ms + 400, 'none',
  null, 'silarah_three_month:three-month', 'INR', 0, now() - interval '1 minute'
)->>'access_kept', 'false', 'the last plan ending ends Premium') from billing_fixture;
select extensions.ok((select u.subscription_status = 'none'
  and not public.has_active_premium(u.id)
  from public.users u join billing_fixture f on u.id = f.pair_id),
  'no plan left means no Premium');
select extensions.is(public.apply_revenuecat_subscription_event(
  pair_id, event_id || '-pair-hold', 'BILLING_ISSUE', event_ms + 500, 'grace',
  now() + interval '7 days', 'silarah_monthly:monthly', 'INR', 0, now()
)->>'reason', 'applied', 'billing issue applies') from billing_fixture;
select extensions.ok((select u.subscription_status = 'grace'
  and u.subscription_expires_at = now() + interval '7 days'
  from public.users u join billing_fixture f on u.id = f.pair_id),
  'grace keeps the exact store expiry, without renewal slack');
select extensions.is(public.apply_revenuecat_subscription_event(
  pair_id, event_id || '-pair-gap', 'RENEWAL', event_ms + 600, 'active',
  now() - interval '30 seconds', 'silarah_monthly:monthly', 'INR', 1,
  now() - interval '30 seconds'
)->>'reason', 'applied', 'a period that just ended applies') from billing_fixture;
select extensions.ok((select public.has_active_premium(f.pair_id) from billing_fixture f),
  'a renewing member is not expired while the RENEWAL webhook is in flight');

select * from extensions.finish();
rollback;
