-- Staff tools for running voice calling after launch (admin panel /calls,
-- member pages and the reports queue). Reads are open to every staff role
-- (super_admin, moderator, support) like admin_call_overview; every write is
-- super admin only and lands in public.admin_audit_log. Metadata only: no
-- audio exists anywhere.
--
--   admin_call_settings()                   current tunable values, bounds, last change
--   admin_update_call_settings(jsonb, text) super admin: change those values (audited)
--   admin_call_operations()                 live calls, ringing, failed/retrying jobs, months
--   admin_retry_call_job(bigint, text)      super admin: re-run one failed job (audited)
--   admin_member_call_wallet(uuid)          a member's minutes, ledger, packs waiting/refunds
--   admin_reports_by_reason(text, int)      reports queue filtered by reason, with call counts
--   admin_call_overview()                   + packs waiting, pending refunds, ringing, retrying
--
-- Nothing here changes how calls ring, hold or settle.

-- ---------------------------------------------------------------------------
-- 1. Which settings staff may tune, and their bounds
-- ---------------------------------------------------------------------------

-- Bounds sit inside the table's CHECK constraints. Deliberately not tunable
-- here: calls_enabled (its own switch), included_period_days (changing it
-- moves every member's current period and would hand out a fresh grant),
-- log_retention_months (a privacy-policy promise), calling_consent_* (set in a
-- migration with the legal text, docs/voice_calling_member_rules.md 12), and
-- the auto cap (computed hourly).
CREATE FUNCTION private.call_settings_bounds()
RETURNS TABLE (key text, min_value integer, max_value integer, sort_order integer)
LANGUAGE sql IMMUTABLE SET search_path TO ''
AS $function$
  VALUES
    ('monthly_cap_minutes',       1000, 1000000, 1),
    ('included_minutes',             0,     300, 2),
    ('max_hold_minutes',             5,     120, 3),
    ('unanswered_call_limit',        1,      10, 4),
    ('ring_timeout_seconds',        15,      60, 5),
    ('join_timeout_seconds',        10,      60, 6),
    ('connect_allowance_seconds',    0,      60, 7),
    ('plan_min_lead_minutes',        1,     240, 8),
    ('plan_max_days_ahead',          1,      30, 9),
    ('plan_window_minutes',         10,     120, 10),
    ('plan_reminder_minutes',        1,      60, 11),
    ('plan_max_open',                1,      20, 12),
    ('plan_max_per_chat_day',        1,      10, 13)
$function$;

REVOKE ALL ON FUNCTION private.call_settings_bounds() FROM PUBLIC, anon, authenticated;

-- The columns that differ between two call_settings rows, ignoring the
-- bookkeeping ones and the hourly auto cap (which writes an audit row every
-- hour and is not a decision anybody made).
CREATE FUNCTION private.call_settings_changed_keys(p_old jsonb, p_new jsonb)
RETURNS text[]
LANGUAGE sql IMMUTABLE SET search_path TO ''
AS $function$
  SELECT coalesce(array_agg(k ORDER BY k), '{}')
  FROM jsonb_object_keys(coalesce(p_new, '{}'::jsonb)) k
  WHERE k NOT IN ('updated_at', 'updated_by', 'auto_cap_minutes', 'auto_cap_at')
    AND (p_old -> k) IS DISTINCT FROM (p_new -> k);
$function$;

REVOKE ALL ON FUNCTION private.call_settings_changed_keys(jsonb, jsonb) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Read the settings
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.admin_call_settings()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_row jsonb;
  v_last record;
  v_last_change jsonb;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator', 'support']) THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  SELECT to_jsonb(s) INTO v_row FROM private.call_settings s WHERE s.id;

  -- Latest change somebody made (skips the hourly auto-cap rows).
  SELECT a.changed_at, a.changed_by, a.old_row, a.new_row,
         private.call_settings_changed_keys(a.old_row, a.new_row) AS keys
  INTO v_last
  FROM private.call_settings_audit a
  WHERE cardinality(private.call_settings_changed_keys(a.old_row, a.new_row)) > 0
  ORDER BY a.id DESC
  LIMIT 1;
  IF FOUND THEN
    v_last_change := jsonb_build_object(
      'changed_at', v_last.changed_at,
      'changed_by', v_last.changed_by,
      'changed_by_email', (SELECT u.email FROM auth.users u WHERE u.id = v_last.changed_by),
      'changes', (
        SELECT jsonb_agg(jsonb_build_object('key', k, 'from', v_last.old_row -> k, 'to', v_last.new_row -> k))
        FROM unnest(v_last.keys) k));
  END IF;

  RETURN jsonb_build_object(
    'values', (
      SELECT jsonb_agg(jsonb_build_object(
        'key', b.key, 'value', (v_row ->> b.key)::integer,
        'min', b.min_value, 'max', b.max_value) ORDER BY b.sort_order)
      FROM private.call_settings_bounds() b),
    'calls_enabled', (v_row ->> 'calls_enabled')::boolean,
    'fixed', jsonb_build_object(
      'included_period_days', (v_row ->> 'included_period_days')::integer,
      'log_retention_months', (v_row ->> 'log_retention_months')::integer,
      'calling_consent_type', v_row ->> 'calling_consent_type',
      'calling_consent_version', v_row ->> 'calling_consent_version'),
    'auto_cap_minutes', (v_row ->> 'auto_cap_minutes')::integer,
    'auto_cap_at', v_row ->> 'auto_cap_at',
    'effective_cap_minutes', private.call_month_cap_minutes(),
    'last_change', v_last_change
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3. Change the settings (super admin, audited)
-- ---------------------------------------------------------------------------

-- p_changes: {"max_hold_minutes": 45, ...}. Only listed keys, whole numbers
-- within the bounds. Keys whose value is unchanged are ignored; nothing
-- changed is an error so an empty save never writes an audit entry.
CREATE FUNCTION public.admin_update_call_settings(p_changes jsonb, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_old jsonb;
  v_new jsonb;
  v_key text;
  v_raw jsonb;
  v_value integer;
  v_bound record;
  v_set jsonb := '{}'::jsonb;
  v_reason text := trim(coalesce(p_reason, ''));
  v_diff jsonb;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'Super admin authorization required' USING ERRCODE = '42501';
  END IF;
  IF length(v_reason) < 6 THEN
    RAISE EXCEPTION 'Give a reason of at least 6 characters for the audit log.' USING ERRCODE = '22023';
  END IF;
  IF p_changes IS NULL OR jsonb_typeof(p_changes) <> 'object' THEN
    RAISE EXCEPTION 'No settings were sent.' USING ERRCODE = '22023';
  END IF;

  SELECT to_jsonb(s) INTO v_old FROM private.call_settings s WHERE s.id FOR UPDATE;

  FOR v_key, v_raw IN SELECT * FROM jsonb_each(p_changes) LOOP
    SELECT * INTO v_bound FROM private.call_settings_bounds() b WHERE b.key = v_key;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'The setting % cannot be changed here.', v_key USING ERRCODE = '22023';
    END IF;
    IF jsonb_typeof(v_raw) = 'string' AND (v_raw #>> '{}') ~ '^-?[0-9]{1,9}$' THEN
      v_value := (v_raw #>> '{}')::integer;
    ELSIF jsonb_typeof(v_raw) = 'number' AND (v_raw #>> '{}') ~ '^-?[0-9]{1,9}$' THEN
      v_value := (v_raw #>> '{}')::integer;
    ELSE
      RAISE EXCEPTION 'The setting % must be a whole number.', v_key USING ERRCODE = '22023';
    END IF;
    IF v_value < v_bound.min_value OR v_value > v_bound.max_value THEN
      RAISE EXCEPTION 'The setting % must be between % and %.', v_key, v_bound.min_value, v_bound.max_value
        USING ERRCODE = '22023';
    END IF;
    IF (v_old ->> v_key)::integer IS DISTINCT FROM v_value THEN
      v_set := v_set || jsonb_build_object(v_key, v_value);
    END IF;
  END LOOP;

  IF v_set = '{}'::jsonb THEN
    RAISE EXCEPTION 'Nothing changed: every value is already in force.' USING ERRCODE = '22023';
  END IF;

  -- The reminder goes out before the planned time, so a plan can never be
  -- closer than its own reminder.
  IF coalesce((v_set ->> 'plan_reminder_minutes')::integer, (v_old ->> 'plan_reminder_minutes')::integer)
     > coalesce((v_set ->> 'plan_min_lead_minutes')::integer, (v_old ->> 'plan_min_lead_minutes')::integer) THEN
    RAISE EXCEPTION 'The plan reminder must not be longer than the shortest planning notice.' USING ERRCODE = '22023';
  END IF;

  -- One UPDATE: the settings trigger records old and new rows in
  -- private.call_settings_audit with this staff member's id.
  UPDATE private.call_settings s SET
    monthly_cap_minutes       = coalesce((v_set ->> 'monthly_cap_minutes')::integer, s.monthly_cap_minutes),
    included_minutes          = coalesce((v_set ->> 'included_minutes')::integer, s.included_minutes),
    max_hold_minutes          = coalesce((v_set ->> 'max_hold_minutes')::integer, s.max_hold_minutes),
    unanswered_call_limit     = coalesce((v_set ->> 'unanswered_call_limit')::integer, s.unanswered_call_limit),
    ring_timeout_seconds      = coalesce((v_set ->> 'ring_timeout_seconds')::integer, s.ring_timeout_seconds),
    join_timeout_seconds      = coalesce((v_set ->> 'join_timeout_seconds')::integer, s.join_timeout_seconds),
    connect_allowance_seconds = coalesce((v_set ->> 'connect_allowance_seconds')::integer, s.connect_allowance_seconds),
    plan_min_lead_minutes     = coalesce((v_set ->> 'plan_min_lead_minutes')::integer, s.plan_min_lead_minutes),
    plan_max_days_ahead       = coalesce((v_set ->> 'plan_max_days_ahead')::integer, s.plan_max_days_ahead),
    plan_window_minutes       = coalesce((v_set ->> 'plan_window_minutes')::integer, s.plan_window_minutes),
    plan_reminder_minutes     = coalesce((v_set ->> 'plan_reminder_minutes')::integer, s.plan_reminder_minutes),
    plan_max_open             = coalesce((v_set ->> 'plan_max_open')::integer, s.plan_max_open),
    plan_max_per_chat_day     = coalesce((v_set ->> 'plan_max_per_chat_day')::integer, s.plan_max_per_chat_day),
    updated_at = now(),
    updated_by = auth.uid()
  WHERE s.id;

  SELECT to_jsonb(s) INTO v_new FROM private.call_settings s WHERE s.id;
  SELECT jsonb_object_agg(k, jsonb_build_object('from', v_old -> k, 'to', v_new -> k))
  INTO v_diff FROM jsonb_object_keys(v_set) k;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (auth.uid(), public.current_admin_role(), 'voice_call_settings_changed',
          jsonb_build_object('changes', v_diff, 'reason', left(v_reason, 500)));

  RETURN jsonb_build_object('changed', v_diff);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4. Operations: live calls, ringing, jobs, months
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.admin_call_operations()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator', 'support']) THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  RETURN jsonb_build_object(
    -- Answered calls not yet settled (creating/active = talking or joining,
    -- ending/ended = waiting for Stream's record).
    'live', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'request_id', s.request_id,
        'status', s.status,
        'caller_id', s.caller_id,
        'caller_name', private.call_display_name(s.caller_id),
        'callee_id', s.callee_id,
        'callee_name', private.call_display_name(s.callee_id),
        'accepted_at', s.accepted_at,
        'both_joined_at', s.both_joined_at,
        'end_requested_at', s.end_requested_at,
        'end_reason', s.end_reason,
        'hold_minutes', s.hold_minutes,
        'last_error', left(s.last_error, 300)
      ) ORDER BY s.accepted_at)
      FROM (SELECT * FROM private.call_sessions
            WHERE status IN ('creating', 'active', 'ending', 'ended')
            ORDER BY accepted_at LIMIT 100) s
    ), '[]'::jsonb),
    'ringing', (SELECT count(*) FROM private.call_requests WHERE status = 'ringing'),
    -- Failed for good (30 attempts). Kept 30 days, then cleaned up.
    'dead_jobs', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', j.id, 'kind', j.kind, 'request_id', j.request_id, 'user_id', j.user_id,
        'plan_id', j.plan_id, 'attempts', j.attempts, 'last_error', j.last_error,
        'created_at', j.created_at, 'last_attempt_at', coalesce(j.leased_at, j.next_attempt_at),
        'can_retry', j.kind IN ('settle', 'end_stream_call', 'join_check', 'delete_stream_user')
      ) ORDER BY j.id DESC)
      FROM (SELECT * FROM private.call_jobs WHERE status = 'dead' ORDER BY id DESC LIMIT 50) j
    ), '[]'::jsonb),
    -- Still being retried after failing at least 3 times.
    'retrying_jobs', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', j.id, 'kind', j.kind, 'request_id', j.request_id, 'user_id', j.user_id,
        'attempts', j.attempts, 'last_error', j.last_error,
        'created_at', j.created_at, 'next_attempt_at', j.next_attempt_at
      ) ORDER BY j.id DESC)
      FROM (SELECT * FROM private.call_jobs
            WHERE status IN ('pending', 'processing') AND attempts >= 3
            ORDER BY id DESC LIMIT 50) j
    ), '[]'::jsonb),
    'months', coalesce((
      SELECT jsonb_agg(jsonb_build_object('month_start', m.month_start, 'charged_minutes', m.charged_minutes)
                       ORDER BY m.month_start DESC)
      FROM (SELECT * FROM private.call_usage_months ORDER BY month_start DESC LIMIT 6) m
    ), '[]'::jsonb)
  );
END;
$function$;

-- Re-run one failed job. Only kinds that re-check the call's current state
-- before acting; a late missed-call or reminder push would only confuse.
CREATE FUNCTION public.admin_retry_call_job(p_job_id bigint, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_job private.call_jobs%ROWTYPE;
  v_reason text := trim(coalesce(p_reason, ''));
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'Super admin authorization required' USING ERRCODE = '42501';
  END IF;
  IF length(v_reason) < 6 THEN
    RAISE EXCEPTION 'Give a reason of at least 6 characters for the audit log.' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_job FROM private.call_jobs WHERE id = p_job_id FOR UPDATE;
  IF NOT FOUND OR v_job.status <> 'dead' THEN
    RAISE EXCEPTION 'This job is not waiting for a retry.' USING ERRCODE = '22023';
  END IF;
  IF v_job.kind NOT IN ('settle', 'end_stream_call', 'join_check', 'delete_stream_user') THEN
    RAISE EXCEPTION 'Notification jobs are not retried: the moment has passed.' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (
    SELECT 1 FROM private.call_jobs o
    WHERE o.id <> v_job.id AND o.kind = v_job.kind AND o.status IN ('pending', 'processing')
      AND ((v_job.request_id IS NOT NULL AND o.request_id = v_job.request_id)
        OR (v_job.request_id IS NULL AND v_job.user_id IS NOT NULL
            AND o.request_id IS NULL AND o.user_id = v_job.user_id))
  ) THEN
    RAISE EXCEPTION 'The same job is already queued again.' USING ERRCODE = '22023';
  END IF;

  UPDATE private.call_jobs
  SET status = 'pending', attempts = 0, next_attempt_at = now(), lease_token = NULL,
      leased_at = NULL, done_at = NULL
  WHERE id = v_job.id;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(), 'voice_call_job_retried',
          coalesce(v_job.user_id, (SELECT r.caller_id FROM private.call_requests r WHERE r.id = v_job.request_id)),
          jsonb_build_object('job_id', v_job.id, 'kind', v_job.kind, 'request_id', v_job.request_id,
                             'last_error', left(v_job.last_error, 300), 'reason', left(v_reason, 500)));

  PERFORM private.call_wake_worker();
  RETURN jsonb_build_object('queued', true, 'job_id', v_job.id, 'kind', v_job.kind);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5. One member's minutes (read only: never creates periods or syncs runs)
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.admin_member_call_wallet(p_user uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_wallet private.call_wallets%ROWTYPE;
  v_period private.call_included_periods%ROWTYPE;
  v_ids text[] := ARRAY[p_user::text];
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator', 'support']) THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = p_user) THEN
    RETURN NULL;
  END IF;
  SELECT * INTO v_wallet FROM private.call_wallets w WHERE w.user_id = p_user;
  IF v_wallet.included_anchor_at IS NOT NULL THEN
    SELECT * INTO v_period FROM private.call_included_periods cp
    WHERE cp.user_id = p_user AND cp.period_start <= now() AND cp.period_end > now()
    ORDER BY cp.period_start DESC LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'premium', public.has_active_premium(p_user),
    'pack_minutes', coalesce(v_wallet.pack_minutes, 0),
    'run_started_at', v_wallet.included_anchor_at,
    'period', CASE WHEN v_period.period_start IS NULL THEN NULL ELSE jsonb_build_object(
      'start', v_period.period_start, 'end', v_period.period_end,
      'granted', v_period.granted_minutes, 'used', v_period.used_minutes,
      'forfeited_at', v_period.forfeited_at,
      'remaining', CASE WHEN v_period.forfeited_at IS NOT NULL THEN 0
                        ELSE greatest(v_period.granted_minutes - v_period.used_minutes, 0) END
    ) END,
    'held_now', coalesce((
      SELECT sum(h.included_minutes + h.pack_minutes)
      FROM private.call_holds h JOIN private.call_sessions s ON s.request_id = h.request_id
      WHERE s.caller_id = p_user AND s.status IN ('creating', 'active', 'ending', 'ended')), 0),
    'month_charged_minutes', coalesce((
      SELECT sum(s.charged_minutes) FROM private.call_sessions s
      WHERE s.caller_id = p_user AND s.settled_at >= private.call_month_start()), 0),
    'call_mode', coalesce((SELECT mp.call_mode FROM private.call_member_prefs mp WHERE mp.user_id = p_user), 'ring'),
    'chats_with_calls_blocked', (SELECT count(*) FROM private.call_pair_prefs pp
                                 WHERE pp.user_id = p_user AND pp.calls_blocked),
    'ledger', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', l.id, 'kind', l.kind, 'pack', l.pack_minutes_delta, 'included', l.included_minutes_delta,
        'product_id', l.product_id, 'transaction_id', l.transaction_id, 'request_id', l.request_id,
        'note', left(l.note, 300), 'created_at', l.created_at) ORDER BY l.id DESC)
      FROM (SELECT * FROM private.call_ledger
            WHERE user_id = p_user AND kind NOT IN ('hold', 'release')
            ORDER BY id DESC LIMIT 50) l
    ), '[]'::jsonb),
    -- A refund that arrived before its purchase (netted when it arrives).
    'pending_refunds', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'transaction_id', r.transaction_id, 'product_id', r.product_id, 'received_at', r.received_at)
        ORDER BY r.received_at DESC)
      FROM private.call_pack_pending_refunds r
      WHERE r.app_user_id = p_user::text AND r.applied_at IS NULL AND r.reversed_at IS NULL
    ), '[]'::jsonb),
    -- Paid packs under this member's store ID that are not credited yet,
    -- and packs staff or the app credited to them later.
    'packs_waiting', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'event_id', c.provider_event_id, 'product_id', c.product_id, 'transaction_id', c.transaction_id,
        'reason', c.reason, 'received_at', c.received_at) ORDER BY c.received_at DESC)
      FROM private.call_pack_unclaimed c
      WHERE c.claimed_at IS NULL AND (c.app_user_id = ANY(v_ids) OR c.aliases && v_ids)
    ), '[]'::jsonb),
    'packs_claimed', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'event_id', c.provider_event_id, 'product_id', c.product_id, 'claimed_at', c.claimed_at,
        'claim_source', c.claim_source) ORDER BY c.claimed_at DESC)
      FROM private.call_pack_unclaimed c WHERE c.claimed_user_id = p_user
    ), '[]'::jsonb)
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 6. Reports queue by reason, with the calls behind each report
-- ---------------------------------------------------------------------------

-- Same rows and order as admin_reports_queue (059), optionally one reason,
-- plus per-reason counts and, for every report, how often the reported
-- member called the reporter (90 days) and the unanswered calls in the 24
-- hours before the report (as admin_report_call_context).
CREATE FUNCTION public.admin_reports_by_reason(p_reason text DEFAULT NULL, p_limit integer DEFAULT 100)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator']) THEN
    RAISE EXCEPTION 'Moderator authorization required' USING ERRCODE = '42501';
  END IF;
  RETURN jsonb_build_object(
    'counts', coalesce((
      SELECT jsonb_object_agg(c.reason, c.n)
      FROM (SELECT r.reason, count(*) AS n FROM public.reports r
            WHERE r.status = 'pending' GROUP BY r.reason) c
    ), '{}'::jsonb),
    'rows', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'report_id', q.id, 'reporter_id', q.reporter_id, 'reported_user_id', q.reported_user_id,
        'reason', q.reason, 'description', q.description, 'created_at', q.created_at,
        'report_count', (SELECT count(*) FROM public.reports r2
                         WHERE r2.reported_user_id = q.reported_user_id AND r2.status = 'pending'),
        'reported_name', concat_ws(' ', p.first_name, p.last_name),
        'calls_to_reporter_90d', (
          SELECT count(*) FROM private.call_requests cr
          WHERE cr.caller_id = q.reported_user_id AND cr.callee_id = q.reporter_id
            AND cr.created_at > now() - interval '90 days'),
        'unanswered_24h', (
          SELECT count(*) FROM private.call_requests cr
          WHERE cr.caller_id = q.reported_user_id AND cr.callee_id = q.reporter_id
            AND cr.status IN ('declined', 'cancelled', 'missed', 'unavailable')
            AND cr.created_at > q.created_at - interval '24 hours'
            AND cr.created_at <= q.created_at)
      ) ORDER BY q.created_at ASC)
      FROM (SELECT * FROM public.reports r
            WHERE r.status = 'pending' AND (v_reason IS NULL OR r.reason = v_reason)
            ORDER BY r.created_at ASC
            LIMIT least(greatest(coalesce(p_limit, 100), 1), 100)) q
      JOIN public.profiles p ON p.user_id = q.reported_user_id
    ), '[]'::jsonb)
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 7. Overview: the same keys as 324 plus what the dashboard needs
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_call_overview()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_settings private.call_settings := private.call_settings_row();
  v_month integer := coalesce((SELECT charged_minutes FROM private.call_usage_months
                               WHERE month_start = private.call_month_start()), 0);
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator', 'support']) THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  RETURN jsonb_build_object(
    'calls_enabled', v_settings.calls_enabled,
    'monthly_cap_minutes', v_settings.monthly_cap_minutes,
    'effective_cap_minutes', private.call_month_cap_minutes(),
    'auto_cap_minutes', v_settings.auto_cap_minutes,
    -- 339: when the auto cap was last computed (stale after 3 hours).
    'auto_cap_at', v_settings.auto_cap_at,
    -- Stream audio: $0.30 per 1,000 participant minutes, 2 per call minute.
    'estimated_stream_cost_usd', round(v_month * 0.0006, 2),
    'month_charged_minutes', v_month,
    'open_hold_minutes', coalesce((SELECT sum(hold_minutes) FROM private.call_sessions
                                   WHERE status IN ('creating', 'active', 'ending', 'ended')), 0),
    'live_calls', (SELECT count(*) FROM private.call_sessions WHERE status IN ('creating', 'active')),
    'calls_today', (SELECT count(*) FROM private.call_requests WHERE created_at > now() - interval '24 hours'),
    'dead_jobs', (SELECT count(*) FROM private.call_jobs WHERE status = 'dead'),
    -- 339 additions.
    'ringing_now', (SELECT count(*) FROM private.call_requests WHERE status = 'ringing'),
    'retrying_jobs', (SELECT count(*) FROM private.call_jobs
                      WHERE status IN ('pending', 'processing') AND attempts >= 3),
    'unclaimed_packs', (SELECT count(*) FROM private.call_pack_unclaimed WHERE claimed_at IS NULL),
    'pending_refunds', (SELECT count(*) FROM private.call_pack_pending_refunds
                        WHERE applied_at IS NULL AND reversed_at IS NULL),
    'calling_consent_version', v_settings.calling_consent_version
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 8. Grants
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.admin_call_settings() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_update_call_settings(jsonb, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_call_operations() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_retry_call_job(bigint, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_member_call_wallet(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_reports_by_reason(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_call_settings() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_call_settings(jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_call_operations() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_retry_call_job(bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_member_call_wallet(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reports_by_reason(text, integer) TO authenticated;

NOTIFY pgrst, 'reload schema';
