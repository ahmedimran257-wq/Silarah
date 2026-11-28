begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(58);

select extensions.ok(
  not has_table_privilege('authenticated', 'public.users', 'INSERT,UPDATE,DELETE'),
  'members have no raw users DML'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.profiles', 'INSERT,UPDATE,DELETE'),
  'members have no raw profiles DML'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.photos', 'INSERT,UPDATE,DELETE'),
  'members have no raw photos DML'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.photo_access_requests', 'INSERT,UPDATE,DELETE'),
  'members cannot self-grant photo access'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.interests', 'INSERT,UPDATE,DELETE'),
  'interest state is RPC-only'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.messages', 'INSERT,UPDATE,DELETE'),
  'message state is RPC-only'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.reports', 'INSERT,UPDATE,DELETE'),
  'report state is RPC-only'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.message_reports', 'INSERT,UPDATE,DELETE'),
  'message report state is RPC-only'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.blocks', 'INSERT,UPDATE,DELETE'),
  'block state is RPC-only'
);
select extensions.ok(
  has_function_privilege('authenticated', 'public.block_member(uuid,text)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.unblock_member(uuid)', 'EXECUTE'),
  'authenticated members can use checked block RPCs'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.get_my_discovery_revision(jsonb)',
    'EXECUTE'
  )
  and not has_table_privilege('authenticated', 'private.discovery_catalog_revision', 'SELECT'),
  'members can read only their compact discovery revision projection'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.user_consents', 'INSERT,UPDATE,DELETE'),
  'consent evidence is RPC-only'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.admin_memberships', 'INSERT,UPDATE,DELETE'),
  'staff governance is RPC-only'
);
select extensions.ok(
  not has_table_privilege('anon', 'public.profiles', 'SELECT'),
  'anonymous callers cannot read base profiles'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.profiles', 'SELECT'),
  'members cannot read base profiles'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.matches', 'SELECT'),
  'members cannot read raw matches'
);
select extensions.ok(
  to_regclass('public.discovery_pool') is null
  and to_regclass('public.recommendations') is null,
  'superseded discovery storage is absent'
);
select extensions.ok(
  to_regprocedure('public.directional_preference_score(uuid,uuid)') is not null
  and not has_function_privilege(
    'authenticated',
    'public.directional_preference_score(uuid,uuid)',
    'EXECUTE'
  )
  and position(
    'public.directional_preference_score('
    in pg_get_functiondef(
      'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure
    )
  ) > 0,
  'live discovery retains its private reciprocal-preference dependency'
);
select extensions.ok(
  to_regclass('public.user_devices') is null,
  'retired Firebase device registry is absent'
);
select extensions.ok(
  not has_function_privilege(
    'authenticated',
    'public.record_onboarding_consents(text)',
    'EXECUTE'
  ),
  'legacy bundled consent RPC is unavailable'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.get_chat_inbox(integer,timestamp with time zone)',
    'EXECUTE'
  ),
  'authenticated participant chat inbox is available'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.get_my_matches(integer)',
    'EXECUTE'
  ),
  'authenticated participant match projection is available'
);
select extensions.ok(
  has_function_privilege(
    'service_role',
    'public.get_authorized_photo_gallery_paths(uuid,uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.get_authorized_photo_gallery_paths(uuid,uuid)',
    'EXECUTE'
  ),
  'gallery path projection is service-only'
);
select extensions.ok(
  (
    select bool_and(p.prosecdef)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'get_chat_inbox',
        'get_chat_messages',
        'mark_chat_read',
        'report_chat_message',
        'block_chat_user',
        'close_chat_match'
      )
  ),
  'chat RPCs use checked definer boundaries after raw table grants are removed'
);
select extensions.ok(
  not has_function_privilege(
    'public',
    'public.finalize_profile_photo_upload(uuid,text,text,integer,text,numeric,boolean)',
    'EXECUTE'
  ),
  'photo finalization is not public'
);
select extensions.ok(
  has_function_privilege(
    'service_role',
    'public.finalize_profile_photo_upload(uuid,text,text,integer,text,numeric,boolean)',
    'EXECUTE'
  ),
  'service photo finalization is available'
);
select extensions.is(
  (
    select count(*)::bigint
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname in ('Allow authenticated uploads', 'Allow user read')
  ),
  0::bigint,
  'legacy selfie policies are absent'
);
select extensions.ok(
  to_regprocedure(
    'public.apply_revenuecat_subscription_event(uuid,text,bigint,text,timestamptz,text,text,numeric,timestamptz)'
  ) is null,
  'weak RevenueCat overload is removed'
);
select extensions.ok(
  to_regprocedure(
    'public.apply_revenuecat_subscription_event(uuid,text,text,bigint,text,timestamptz,text,text,numeric,timestamptz)'
  ) is null,
  'pre-plan-change RevenueCat overload is removed (314)'
);
select extensions.ok(
  to_regprocedure(
    'public.apply_revenuecat_subscription_event(uuid,text,text,bigint,text,timestamptz,text,text,numeric,timestamptz,text)'
  ) is not null,
  'provider-ID RevenueCat RPC with the plan-change argument exists'
);
select extensions.ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'subscription_events'
      and indexname = 'idx_subscription_events_provider_event'
      and indexdef like 'CREATE UNIQUE INDEX%'
      and indexdef like '%provider_event_id%'
  ),
  'RevenueCat provider event IDs have a unique idempotency index'
);
select extensions.ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'subscription_events'
      and indexname = 'idx_subscription_events_user_time'
      and indexdef like '%user_id%event_timestamp_ms DESC%'
  ),
  'subscriber billing history has a latest-event lookup index'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.record_chat_safety_violation(uuid,text,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.record_chat_safety_violation(uuid,text,text)',
    'EXECUTE'
  ),
  'chat safety recording is internal'
);
select extensions.ok(
  not has_function_privilege(
    'authenticated',
    'public.queue_notification(uuid,text,text,text,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.queue_notification(uuid,text,text,text,text)',
    'EXECUTE'
  ),
  'notification queueing is service-only'
);
select extensions.ok(
  (
    select bool_and(
      not has_function_privilege('authenticated', p.oid, 'EXECUTE')
      and not has_function_privilege('anon', p.oid, 'EXECUTE')
    )
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'compute_casual_penalties',
        'compute_creep_scores',
        'compute_glicko2_batch',
        'compute_glicko_tiers',
        'compute_global_rank_scores',
        'expire_stale_matches',
        'hide_inactive_profiles'
      )
  ),
  'ranking and maintenance routines are unavailable to API members'
);
select extensions.ok(
  to_regprocedure('public.get_new_arrivals(text,uuid)') is null
  and to_regprocedure(
    'public.get_nearby_matches(numeric,numeric,numeric)'
  ) is null
  and to_regprocedure(
    'public.submit_selfie_verification(text,text)'
  ) is null,
  'retired discovery and client-trusted verification RPCs are absent'
);
select extensions.ok(
  not has_table_privilege(
    'authenticated',
    'public.user_glicko_ratings',
    'SELECT,INSERT,UPDATE,DELETE'
  )
  and not has_table_privilege(
    'authenticated',
    'public.glicko_interactions',
    'SELECT,INSERT,UPDATE,DELETE'
  ),
  'ranking ledgers are server-owned'
);
select extensions.ok(
  not has_table_privilege(
    'authenticated',
    'public.subscription_events',
    'SELECT,INSERT,UPDATE,DELETE'
  )
  and not has_table_privilege(
    'authenticated',
    'public.storage_cleanup_queue',
    'SELECT,INSERT,UPDATE,DELETE'
  ),
  'billing and storage cleanup ledgers are server-owned'
);
select extensions.ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'blocks'
      and policyname = 'blocks_select'
      and qual like '%blocker_id%auth.uid()%'
      and qual not like '%blocked_id%'
  ),
  'blocked members cannot discover who blocked them'
);
select extensions.ok(
  (
    to_regprocedure('public.email_registration_status(text)') is null
    or not has_function_privilege(
      'anon',
      'public.email_registration_status(text)',
      'EXECUTE'
    )
  )
  and (
    to_regprocedure('public.email_is_registered(text)') is null
    or not has_function_privilege(
      'anon',
      'public.email_is_registered(text)',
      'EXECUTE'
    )
  ),
  'email registration oracles are unavailable'
);
select extensions.ok(
  not has_function_privilege(
    'authenticated',
    'public.get_or_create_city(character varying,character varying,character varying,character varying,numeric,numeric)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.get_or_create_city(character varying,character varying,character varying,character varying,numeric,numeric)',
    'EXECUTE'
  ),
  'city catalogue resolution is service-only'
);
select extensions.ok(
  not has_table_privilege(
    'authenticated',
    'public.guardian_sessions',
    'SELECT,INSERT,UPDATE,DELETE'
  ),
  'guardian presence sessions cannot be forged or read directly'
);
select extensions.ok(
  not has_table_privilege(
    'authenticated',
    'public.guardian_chat_mirrors',
    'INSERT,UPDATE,DELETE'
  ),
  'guardian chat mirrors cannot be forged'
);
select extensions.ok(
  has_function_privilege(
    'anon',
    'public.begin_signup_consent_transaction(text,jsonb)',
    'EXECUTE'
  )
  and has_function_privilege(
    'anon',
    'public.bind_signup_consent_transaction(uuid,text)',
    'EXECUTE'
  ),
  'anonymous signup can create and bind an expiring consent transaction'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.finalize_signup_consents(uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.finalize_signup_consents(uuid)',
    'EXECUTE'
  ),
  'only a verified authenticated identity can finalize signup consent'
);
select extensions.ok(
  (
    select count(*) = 4
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name in (
        'guardian_invitation_expires_at',
        'guardian_invitation_consumed_at',
        'guardian_invitation_attempts',
        'guardian_invitation_locked_until'
      )
  ),
  'guardian invitations have expiry, consumption, attempt and lock state'
);
select extensions.ok(
  to_regprocedure('public.checkout_kyc_document_purges(integer)') is null
  and to_regprocedure(
    'public.record_kyc_purge_object_result(uuid,text,boolean,text)'
  ) is null
  and to_regprocedure('public.finish_kyc_document_purge(uuid)') is null,
  'retired government-ID functions are absent'
);
select extensions.ok(
  has_function_privilege(
    'service_role',
    'public.checkout_photo_verification_purges(integer)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.finish_photo_verification_purge(uuid,boolean,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.finish_photo_verification_purge(uuid,boolean,text)',
    'EXECUTE'
  ),
  'temporary photo-capture purge progress remains service-only'
);
select extensions.ok(
  exists (
    select 1
    from pg_constraint c
    join pg_class r on r.oid = c.conrelid
    join pg_namespace n on n.oid = r.relnamespace
    where n.nspname = 'public'
      and r.relname = 'notifications'
      and c.conname = 'notifications_deep_link_allowlist_check'
      and not c.convalidated
  ),
  'new notification deep links are constrained by the allowlist'
);
select extensions.ok(
  (
    select p.prosecdef
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.oid = 'public.apply_referral_code(text)'::regprocedure
  ),
  'referral application uses the idempotent checked definer boundary'
);

select extensions.ok(
  not has_table_privilege(
    'authenticated',
    'private.premium_shortlist_details',
    'SELECT,INSERT,UPDATE,DELETE'
  )
  and not has_table_privilege(
    'authenticated',
    'private.premium_privacy_settings',
    'SELECT,INSERT,UPDATE,DELETE'
  ),
  'Premium relationship metadata has no direct member table access'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.get_premium_compatibility_insight(uuid)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'public.get_my_premium_shortlist_details()',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'public.set_my_incognito(boolean)',
    'EXECUTE'
  ),
  'members use checked Premium relationship RPCs'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.get_premium_compatibility_insight(uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.get_my_premium_shortlist_details()',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.set_my_incognito(boolean)',
    'EXECUTE'
  ),
  'anonymous callers cannot use Premium relationship RPCs'
);
select extensions.ok(
  position(
    'private.can_access_incognito_profile(p_viewer_id, dp.user_id)'
    in pg_get_functiondef(
      'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure
    )
  ) > 0
  and position(
    'private.can_access_incognito_profile(p_viewer_id, p.user_id)'
    in pg_get_functiondef(
      'public.search_profiles_by_name_city(uuid,text,integer)'::regprocedure
    )
  ) > 0,
  'Incognito is enforced in discovery and search projections'
);
select extensions.ok(
  position(
    'private.can_access_incognito_profile(v_sender, p_receiver_id)'
    in pg_get_functiondef('public.send_interest(uuid,text)'::regprocedure)
  ) > 0
  and position(
    'private.can_access_incognito_profile(v_me, p_viewed_user_id)'
    in pg_get_functiondef('public.record_profile_view(uuid,boolean)'::regprocedure)
  ) > 0,
  'Incognito cannot be bypassed by direct interest or view actions'
);
select extensions.ok(
  position(
    'r.interests, NULL::integer, NULL::integer'
    in pg_get_functiondef(
      'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure
    )
  ) > 0,
  'raw candidate preferences are never projected to discovery clients'
);
select extensions.ok(
  exists (
    select 1 from cron.job
    where jobname = 'process_premium_feature_maintenance_hourly'
      and schedule = '17 * * * *'
  )
  and position(
    'LIMIT v_limit'
    in pg_get_functiondef(
      'private.process_premium_feature_maintenance(integer)'::regprocedure
    )
  ) > 0,
  'Premium reminders and expiry use one bounded hourly job'
);
select extensions.ok(
  position(
    '2.4.0'
    in pg_get_functiondef(
      'public.begin_signup_consent_transaction(text,jsonb)'::regprocedure
    )
  ) > 0
  and position(
    '2.4.0'
    in pg_get_functiondef('public.sync_my_user(text,text)'::regprocedure)
  ) > 0
  and position(
    '''private_shortlist_details'''
    in pg_get_functiondef(
      'private.build_personal_data_export(text)'::regprocedure
    )
  ) > 0,
  'current consent and personal-data export include the new Premium metadata'
);

select * from extensions.finish();
rollback;
