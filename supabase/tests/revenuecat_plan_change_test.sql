-- Plan switches as Google Play reports them through RevenueCat (migration
-- 322). Synthetic members only; everything rolls back.
--
-- Both directions arrive as PRODUCT_CHANGE (product_id = old plan,
-- new_product_id = new plan, expiry = the change time). The new plan then
-- starts with an INITIAL_PURCHASE at once for monthly -> 3 months, and with
-- a RENEWAL under monthly at the 3-month period end for 3 months -> monthly.
begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(19);

create temporary table plan_fixture as select
  gen_random_uuid() as up_id,
  gen_random_uuid() as down_id,
  gen_random_uuid() as late_id,
  (extract(epoch from now() - interval '30 minutes') * 1000)::bigint as t0;
insert into auth.users(id)
select up_id from plan_fixture
union all select down_id from plan_fixture
union all select late_id from plan_fixture;
insert into public.users(id, email, country_code, gender)
select id, id::text || '@qa.silarah.com', 'IN', 'male'
from (select up_id as id from plan_fixture
      union all select down_id from plan_fixture
      union all select late_id from plan_fixture) members;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local request.jwt.claim.role = 'service_role';

create temporary view plan_users as
select u.id, u.subscription_status, u.subscription_expires_at
from public.users u;

-- Upgrade: monthly -> 3 months, charged now.
select public.apply_revenuecat_subscription_event(
  up_id, 'up-monthly-' || up_id, 'INITIAL_PURCHASE', t0, 'active',
  now() + interval '20 days', 'silarah_monthly:monthly', 'INR', 299,
  now() + interval '20 days') from plan_fixture;
select extensions.is(public.apply_revenuecat_subscription_event(
  up_id, 'up-change-' || up_id, 'PRODUCT_CHANGE', t0 + 60000, 'active',
  to_timestamp((t0 + 60000) / 1000.0), 'silarah_three_month:three-month',
  'INR', 0, to_timestamp((t0 + 60000) / 1000.0), 'silarah_monthly:monthly'
)->>'reason', 'plan_change_recorded', 'upgrade: the change is only noted')
from plan_fixture;
select extensions.ok((select u.subscription_status = 'active'
  and u.subscription_expires_at = now() + interval '20 days' + interval '10 minutes'
  from plan_users u join plan_fixture f on u.id = f.up_id),
  'upgrade: the change time is never stored as the expiry');
select extensions.is(public.apply_revenuecat_subscription_event(
  up_id, 'up-three-' || up_id, 'INITIAL_PURCHASE', t0 + 60006, 'active',
  now() + interval '95 days', 'silarah_three_month:three-month', 'INR', 749,
  now() + interval '95 days')->>'reason', 'applied',
  'upgrade: the new plan starts with its purchase') from plan_fixture;
select extensions.ok((select u.subscription_status = 'active'
  and u.subscription_expires_at = now() + interval '95 days' + interval '10 minutes'
  from plan_users u join plan_fixture f on u.id = f.up_id),
  'upgrade: Premium runs to the new plan''s period end');
select extensions.is((select count(*) from public.subscription_events e
  join plan_fixture f on e.user_id = f.up_id
  where e.event_type = 'PRODUCT_REPLACED'
    and e.product_id = 'silarah_monthly:monthly'
    and e.event_timestamp_ms = f.t0 + 60006), 1::bigint,
  'upgrade: the monthly plan is retired when the 3-month plan starts');
select extensions.is(public.apply_revenuecat_subscription_event(
  up_id, 'up-revoke-' || up_id, 'REVOCATION', t0 + 120000, 'none', null,
  'silarah_three_month:three-month')->>'reason', 'applied',
  'upgrade: a refund of the new plan applies') from plan_fixture;
select extensions.ok((select u.subscription_status = 'none'
  and u.subscription_expires_at is null
  from plan_users u join plan_fixture f on u.id = f.up_id),
  'upgrade: the retired monthly plan does not keep Premium after that refund');
select extensions.is(public.apply_revenuecat_subscription_event(
  up_id, 'up-change-' || up_id, 'PRODUCT_CHANGE', t0 + 60000, 'active',
  to_timestamp((t0 + 60000) / 1000.0), 'silarah_three_month:three-month',
  'INR', 0, to_timestamp((t0 + 60000) / 1000.0), 'silarah_monthly:monthly'
)->>'reason', 'duplicate_event', 'a redelivered change is a no-op')
from plan_fixture;

-- Downgrade: 3 months -> monthly, booked for the renewal.
select public.apply_revenuecat_subscription_event(
  down_id, 'down-three-' || down_id, 'INITIAL_PURCHASE', t0, 'active',
  now() + interval '40 days', 'silarah_three_month:three-month', 'INR', 749,
  now() + interval '40 days') from plan_fixture;
select extensions.is(public.apply_revenuecat_subscription_event(
  down_id, 'down-change-' || down_id, 'PRODUCT_CHANGE', t0 + 60000, 'active',
  to_timestamp((t0 + 60000) / 1000.0), 'silarah_monthly:monthly', 'INR', 0,
  to_timestamp((t0 + 60000) / 1000.0), 'silarah_three_month:three-month'
)->>'reason', 'plan_change_recorded', 'downgrade: the booking is only noted')
from plan_fixture;
select extensions.ok((select u.subscription_status = 'active'
  and u.subscription_expires_at = now() + interval '40 days' + interval '10 minutes'
  from plan_users u join plan_fixture f on u.id = f.down_id),
  'downgrade: the paid 3-month period is kept in full after booking');
select extensions.is((select count(*) from public.subscription_events e
  join plan_fixture f on e.user_id = f.down_id
  where e.event_type = 'PRODUCT_REPLACED'), 0::bigint,
  'downgrade: the 3-month plan stays in force until the switch happens');
select extensions.is((select count(*) from public.transactional_email_outbox o
  join plan_fixture f on o.user_id = f.down_id
  where o.event_type = 'PRODUCT_CHANGE'), 0::bigint,
  'downgrade: booking sends no "plan changed" email before anything changed');
select extensions.is(public.apply_revenuecat_subscription_event(
  down_id, 'down-monthly-' || down_id, 'RENEWAL', t0 + 600000,
  'active', now() + interval '70 days', 'silarah_monthly:monthly', 'INR', 299,
  now() + interval '70 days')->>'reason', 'applied',
  'downgrade: monthly starts with a renewal at the 3-month period end') from plan_fixture;
select extensions.is((select count(*) from public.subscription_events e
  join plan_fixture f on e.user_id = f.down_id
  where e.event_type = 'PRODUCT_REPLACED'
    and e.product_id = 'silarah_three_month:three-month'), 1::bigint,
  'downgrade: the 3-month plan is retired once monthly starts') from plan_fixture;
select extensions.ok((select u.subscription_status = 'active'
  and u.subscription_expires_at = now() + interval '70 days' + interval '10 minutes'
  from plan_users u join plan_fixture f on u.id = f.down_id),
  'downgrade: Premium follows the monthly plan');
select extensions.is(public.apply_revenuecat_subscription_event(
  down_id, 'down-expire-' || down_id, 'EXPIRATION', t0 + 600010, 'none', null,
  'silarah_three_month:three-month')->>'access_kept', 'true',
  'downgrade: the old plan''s expiry does not end Premium') from plan_fixture;
select extensions.ok((select u.subscription_status = 'active'
  from plan_users u join plan_fixture f on u.id = f.down_id),
  'downgrade: still Premium after the old plan expires');

-- Delivered out of order: the new plan's purchase before the change note.
select public.apply_revenuecat_subscription_event(
  late_id, 'late-monthly-' || late_id, 'INITIAL_PURCHASE', t0, 'active',
  now() + interval '20 days', 'silarah_monthly:monthly', 'INR', 299,
  now() + interval '20 days') from plan_fixture;
select public.apply_revenuecat_subscription_event(
  late_id, 'late-three-' || late_id, 'INITIAL_PURCHASE', t0 + 60006, 'active',
  now() + interval '95 days', 'silarah_three_month:three-month', 'INR', 749,
  now() + interval '95 days') from plan_fixture;
select extensions.is(public.apply_revenuecat_subscription_event(
  late_id, 'late-change-' || late_id, 'PRODUCT_CHANGE', t0 + 60000, 'active',
  to_timestamp((t0 + 60000) / 1000.0), 'silarah_three_month:three-month',
  'INR', 0, to_timestamp((t0 + 60000) / 1000.0), 'silarah_monthly:monthly'
)->>'reason', 'plan_change_recorded', 'a late change note is still noted')
from plan_fixture;
select extensions.is((select count(*) from public.subscription_events e
  join plan_fixture f on e.user_id = f.late_id
  where e.event_type = 'PRODUCT_REPLACED'
    and e.product_id = 'silarah_monthly:monthly'), 1::bigint,
  'a late change note still retires the old plan') from plan_fixture;

select * from extensions.finish();
rollback;
