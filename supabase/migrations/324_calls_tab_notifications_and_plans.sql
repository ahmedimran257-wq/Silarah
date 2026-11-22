-- Calls tab, call notifications and planned calls
-- (docs/voice_calling_spec.md sections 12 and 13, added 22 Nov 2026).
--
-- Builds on 323_voice_calling.sql. Calling still ships OFF
-- (private.call_settings.calls_enabled = false).
--
--   * Ringing only reaches phones that said they can ring (notifications
--     allowed, incoming-call channel on). With none, the callee counts as
--     unavailable: the caller gets the same neutral answer as always and the
--     callee gets the missed call.
--   * Missed calls are a data-only push rendered on the phone in its own
--     language, one notification per caller with a count. Calls off: no push;
--     Silent, muted chat, quiet hours or busy: a silent notification;
--     notification_prefs.missed_call switches the push off. A free man gets
--     the Premium variant. Pushes carry the first name only.
--   * The Calls tab reads one page of the member's own call log at a time
--     (get_my_call_log) and one overview (get_my_call_overview). "Remove from
--     history" hides rows for that member only; harassment limits, safety
--     logs, the Guardian log and the data export still see them.
--   * Planned calls: either member proposes a time, the other accepts, both
--     get a reminder 5 minutes before, and the plan expires 30 minutes after.
--   * Reports get the "harassing_calls" reason.
--   * Every number a member is told (unanswered-call limit, included
--     minutes, call length, ring time, refunds, planned-call windows,
--     retention) lives in private.call_settings and reaches the app through
--     get_calling_rules(), so copy never hard-codes it.
--   * The monthly minute cap is an emergency brake, never a budget limit for
--     paid members: it is at least the minutes members are entitled to this
--     month (Premium included minutes + unused pack minutes) plus 25%,
--     refreshed hourly.
--   * Call records are kept 12 months (longer only while an open report
--     between the two members needs them), then purged daily.

-- ---------------------------------------------------------------------------
-- 1. Schema
-- ---------------------------------------------------------------------------

-- Which of a member's phones can ring. Kept apart from user_fcm_tokens so a
-- token refresh never resets it and the push registration RPC (used by
-- every release) is unchanged. No row means "unknown", which never rings:
-- only app versions that can ring report it.
CREATE TABLE private.call_device_capabilities (
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  device_id text NOT NULL CHECK (char_length(device_id) BETWEEN 8 AND 128),
  can_ring boolean NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, device_id)
);

-- One source for every rule a member is told (get_calling_rules).
ALTER TABLE private.call_settings
  ADD COLUMN plan_min_lead_minutes integer NOT NULL DEFAULT 10
    CHECK (plan_min_lead_minutes BETWEEN 1 AND 1440),
  ADD COLUMN plan_max_days_ahead integer NOT NULL DEFAULT 7
    CHECK (plan_max_days_ahead BETWEEN 1 AND 60),
  ADD COLUMN plan_window_minutes integer NOT NULL DEFAULT 30
    CHECK (plan_window_minutes BETWEEN 5 AND 240),
  ADD COLUMN plan_reminder_minutes integer NOT NULL DEFAULT 5
    CHECK (plan_reminder_minutes BETWEEN 1 AND 120),
  ADD COLUMN plan_max_open integer NOT NULL DEFAULT 5
    CHECK (plan_max_open BETWEEN 1 AND 50),
  ADD COLUMN plan_max_per_chat_day integer NOT NULL DEFAULT 3
    CHECK (plan_max_per_chat_day BETWEEN 1 AND 50),
  ADD COLUMN log_retention_months integer NOT NULL DEFAULT 12
    CHECK (log_retention_months BETWEEN 1 AND 120),
  -- Entitled minutes this month + 25% (call_refresh_month_cap, hourly).
  ADD COLUMN auto_cap_minutes integer,
  ADD COLUMN auto_cap_at timestamptz;

-- Remove from history: per member, never deletes.
ALTER TABLE private.call_requests
  ADD COLUMN hidden_by_caller_at timestamptz,
  ADD COLUMN hidden_by_callee_at timestamptz;

-- When the member last opened the Calls tab (missed-call badge).
ALTER TABLE private.call_member_prefs
  ADD COLUMN calls_seen_at timestamptz;

-- Missed-call pushes only. Ringing is controlled by Ring / Silent / Off.
ALTER TABLE public.notification_prefs
  ADD COLUMN missed_call boolean NOT NULL DEFAULT true;

CREATE TABLE private.call_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id uuid NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  proposer_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  invitee_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  planned_for timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'proposed' CHECK (status IN (
    'proposed', 'accepted', 'declined', 'cancelled', 'expired', 'done'
  )),
  created_at timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz,
  closed_at timestamptz,
  closed_by uuid,
  reminder_sent_at timestamptz,
  CHECK (proposer_id <> invitee_id)
);
CREATE UNIQUE INDEX uq_call_plans_open_per_match ON private.call_plans(match_id)
  WHERE status IN ('proposed', 'accepted');
CREATE INDEX idx_call_plans_proposer ON private.call_plans(proposer_id, planned_for DESC);
CREATE INDEX idx_call_plans_invitee ON private.call_plans(invitee_id, planned_for DESC);
CREATE INDEX idx_call_plans_open ON private.call_plans(planned_for)
  WHERE status IN ('proposed', 'accepted');

-- Jobs for missed-call pushes, "seen on another phone" and plan reminders.
ALTER TABLE private.call_jobs ADD COLUMN plan_id uuid
  REFERENCES private.call_plans(id) ON DELETE CASCADE;
ALTER TABLE private.call_jobs DROP CONSTRAINT call_jobs_kind_check;
ALTER TABLE private.call_jobs ADD CONSTRAINT call_jobs_kind_check CHECK (kind IN (
  'end_stream_call', 'join_check', 'settle', 'cancel_ring', 'delete_stream_user',
  'missed_push', 'seen_push', 'plan_reminder'
));
ALTER TABLE private.call_jobs DROP CONSTRAINT call_jobs_check;
ALTER TABLE private.call_jobs ADD CONSTRAINT call_jobs_target_check
  CHECK (request_id IS NOT NULL OR user_id IS NOT NULL OR plan_id IS NOT NULL);
CREATE UNIQUE INDEX uq_call_jobs_open_plan ON private.call_jobs(kind, plan_id)
  WHERE status IN ('pending', 'processing') AND plan_id IS NOT NULL;

-- Reports from calls get their own reason. The allowed list is extended in
-- place, keeping whatever reasons this database already allows.
DO $$
DECLARE
  v_values text[];
BEGIN
  SELECT array_agg(DISTINCT m[1]) INTO v_values
  FROM pg_constraint c,
       regexp_matches(pg_get_constraintdef(c.oid), '''([a-z_]+)''', 'g') AS m
  WHERE c.conrelid = 'public.reports'::regclass AND c.conname = 'reports_reason_check';
  IF v_values IS NULL THEN
    RAISE EXCEPTION 'reports_reason_check not found';
  END IF;
  IF NOT 'harassing_calls' = ANY (v_values) THEN
    v_values := v_values || 'harassing_calls'::text;
  END IF;
  ALTER TABLE public.reports DROP CONSTRAINT reports_reason_check;
  EXECUTE format('ALTER TABLE public.reports ADD CONSTRAINT reports_reason_check '
                 'CHECK (reason = ANY (%L::text[]))', v_values);
END $$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['call_device_capabilities', 'call_plans'] LOOP
    EXECUTE format('ALTER TABLE private.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON private.%I FROM PUBLIC, anon, authenticated', t);
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 2. Shared helpers
-- ---------------------------------------------------------------------------

CREATE FUNCTION private.call_first_name(p_user uuid)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT coalesce((SELECT nullif(trim(p.first_name), '') FROM public.profiles p
                   WHERE p.user_id = p_user), 'Silarah member');
$function$;

CREATE FUNCTION private.call_user_can_ring(p_user uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM private.call_device_capabilities c
    JOIN public.user_fcm_tokens t ON t.user_id = c.user_id AND t.device_id = c.device_id
    WHERE c.user_id = p_user AND c.can_ring
  );
$function$;

-- Who the viewer may see on the other side of a call or plan: nobody when
-- either has blocked the other or the other account is gone, banned or
-- switched off (same rule as the chat inbox).
CREATE FUNCTION private.call_peer_unavailable(p_viewer uuid, p_other uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT coalesce(private.call_member_block_reason(p_other) IN (
           'account_deleted', 'account_banned', 'account_restricted'), false)
    OR EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (b.blocker_id = p_viewer AND b.blocked_id = p_other)
         OR (b.blocker_id = p_other AND b.blocked_id = p_viewer)
    );
$function$;

-- What the viewer sees for one call (spec 12.3 / 12.4): the caller never
-- learns why a call was not answered.
CREATE FUNCTION private.call_outcome_for(
  p_viewer uuid, p_caller uuid, p_status text, p_connected_seconds integer,
  p_session_status text
)
RETURNS text
LANGUAGE sql IMMUTABLE
AS $function$
  SELECT CASE
    WHEN p_status = 'ringing' THEN 'ringing'
    WHEN p_status = 'accepted' AND p_session_status IN ('creating', 'active') THEN 'live'
    WHEN p_status = 'accepted' AND coalesce(p_connected_seconds, 0) > 0 THEN 'answered'
    WHEN p_caller = p_viewer THEN 'no_answer'
    WHEN p_status = 'declined' THEN 'declined'
    WHEN p_status = 'accepted' THEN 'not_connected'
    ELSE 'missed'
  END;
$function$;

-- A call the callee missed: not answered, not declined by them, never the
-- calls they blocked, and not a call the system stopped (block, switch).
CREATE FUNCTION private.call_missed_for_callee(p_status text, p_reason text)
RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $function$
  SELECT p_status = 'missed'
    OR (p_status = 'unavailable' AND p_reason IS DISTINCT FROM 'calls_blocked')
    OR (p_status = 'cancelled' AND p_reason = 'caller_cancelled');
$function$;

-- The man on a call must hold Premium; a pair where he does not can neither
-- call nor plan a call (spec 2, 13.1).
CREATE FUNCTION private.call_pair_premium_ok(p_a uuid, p_b uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT (private.call_is_female(p_a) OR public.has_active_premium(p_a))
     AND (private.call_is_female(p_b) OR public.has_active_premium(p_b))
     AND (public.has_active_premium(p_a) OR public.has_active_premium(p_b));
$function$;

CREATE FUNCTION private.call_mode_of(p_user uuid)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT coalesce((SELECT mp.call_mode FROM private.call_member_prefs mp
                   WHERE mp.user_id = p_user), 'ring');
$function$;

-- The monthly brake (spec 5): never below what members are entitled to.
CREATE FUNCTION private.call_month_cap_minutes()
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT greatest(s.monthly_cap_minutes,
                  CASE WHEN s.auto_cap_at > now() - interval '3 hours'
                       THEN coalesce(s.auto_cap_minutes, 0) ELSE 0 END)
  FROM private.call_settings s WHERE s.id;
$function$;

-- Hourly: Premium members x included minutes + unused pack minutes, + 25%.
CREATE FUNCTION private.call_refresh_month_cap()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_settings private.call_settings := private.call_settings_row();
  v_premium bigint;
  v_packs bigint;
  v_cap integer;
BEGIN
  SELECT count(*) INTO v_premium FROM (
    SELECT u.id FROM public.users u
    WHERE u.subscription_status IN ('active', 'grace')
      AND (u.subscription_expires_at IS NULL OR u.subscription_expires_at > now())
    UNION
    SELECT g.user_id FROM public.promotional_premium_grants g
    WHERE g.starts_at <= now() AND g.expires_at > now()
    UNION
    SELECT t.user_id FROM private.test_premium_grants t
    WHERE t.revoked_at IS NULL AND t.starts_at <= now() AND t.expires_at > now()
  ) premium;
  SELECT coalesce(sum(greatest(w.pack_minutes, 0)), 0) INTO v_packs FROM private.call_wallets w;
  v_cap := least(2000000000::bigint,
                 ceil((v_premium * v_settings.included_minutes + v_packs) * 1.25))::integer;
  UPDATE private.call_settings SET auto_cap_minutes = v_cap, auto_cap_at = now() WHERE id;
  RETURN v_cap;
END;
$function$;

-- Missed calls the callee has not seen yet.
CREATE FUNCTION private.call_unseen_missed(p_user uuid, p_from uuid DEFAULT NULL)
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT count(*)::integer
  FROM private.call_requests r
  WHERE r.callee_id = p_user
    AND (p_from IS NULL OR r.caller_id = p_from)
    AND private.call_missed_for_callee(r.status, r.reason)
    AND r.hidden_by_callee_at IS NULL
    AND r.created_at > coalesce(
      (SELECT mp.calls_seen_at FROM private.call_member_prefs mp WHERE mp.user_id = p_user),
      '-infinity'::timestamptz);
$function$;

-- ---------------------------------------------------------------------------
-- 3. Changed 323 functions (full definitions, changes marked "324:")
-- ---------------------------------------------------------------------------

-- 324: a missed call is a data-only push the phone renders in its own
-- language (spec 12.3), sent by call-worker; call_service_missed_push
-- decides whether and how.
CREATE OR REPLACE FUNCTION private.call_queue_missed_note(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  PERFORM private.call_enqueue_job('missed_push', p_request_id);
END;
$function$;

CREATE FUNCTION private.call_enqueue_plan_job(p_kind text, p_plan_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO private.call_jobs(kind, plan_id)
  VALUES (p_kind, p_plan_id)
  ON CONFLICT (kind, plan_id)
    WHERE status IN ('pending', 'processing') AND plan_id IS NOT NULL
  DO NOTHING;
END;
$function$;

-- 324: ring pushes go only to phones that can ring.
DROP FUNCTION public.call_service_device_tokens(uuid);
CREATE FUNCTION public.call_service_device_tokens(p_user uuid)
RETURNS TABLE (fcm_token text, device_id text, can_ring boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT t.fcm_token, t.device_id, coalesce(c.can_ring, false)
  FROM public.user_fcm_tokens t
  LEFT JOIN private.call_device_capabilities c
    ON c.user_id = t.user_id AND c.device_id = t.device_id
  WHERE t.user_id = p_user
  ORDER BY t.updated_at DESC
  LIMIT 5;
END;
$function$;

-- 324: jobs can carry a plan.
DROP FUNCTION public.call_service_checkout_jobs(integer);
CREATE FUNCTION public.call_service_checkout_jobs(p_limit integer DEFAULT 20)
RETURNS TABLE (
  id bigint, kind text, request_id uuid, user_id uuid, plan_id uuid,
  attempts integer, lease_token uuid
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
#variable_conflict use_column
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  PERFORM private.call_enqueue_due_work();
  RETURN QUERY
  UPDATE private.call_jobs j
  SET status = 'processing', lease_token = gen_random_uuid(), leased_at = now(),
      attempts = j.attempts + 1
  WHERE j.id IN (
    SELECT q.id FROM private.call_jobs q
    WHERE (q.status = 'pending' AND q.next_attempt_at <= now())
       OR (q.status = 'processing' AND q.leased_at < now() - interval '2 minutes')
    ORDER BY q.next_attempt_at, q.id
    LIMIT least(greatest(p_limit, 1), 50)
    FOR UPDATE SKIP LOCKED
  )
  RETURNING j.id, j.kind, j.request_id, j.user_id, j.plan_id, j.attempts, j.lease_token;
END;
$function$;

-- 324: also wakes for planned-call reminders and expiry.
CREATE OR REPLACE FUNCTION private.call_watchdog()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  -- Nothing to do in the common case: no open calls, no queued work, no
  -- plan due for its reminder or its end.
  IF NOT EXISTS (SELECT 1 FROM private.call_requests WHERE status = 'ringing')
    AND NOT EXISTS (SELECT 1 FROM private.call_sessions
                    WHERE status IN ('creating', 'active', 'ending', 'ended'))
    AND NOT EXISTS (SELECT 1 FROM private.call_jobs
                    WHERE status IN ('pending', 'processing') AND next_attempt_at <= now())
    AND NOT EXISTS (SELECT 1 FROM private.call_plans cp
                    WHERE cp.status IN ('proposed', 'accepted')
                      AND (cp.planned_for < now()
                           OR (cp.status = 'accepted' AND cp.reminder_sent_at IS NULL
                               AND cp.planned_for <= now() + interval '5 minutes'))) THEN
    RETURN;
  END IF;
  PERFORM private.call_enqueue_due_work();
  IF EXISTS (
    SELECT 1 FROM private.call_jobs
    WHERE (status = 'pending' AND next_attempt_at <= now())
       OR (status = 'processing' AND leased_at < now() - interval '2 minutes')
  ) THEN
    PERFORM private.call_wake_worker();
  END IF;
END;
$function$;

-- 324: hidden rows and planned calls are part of the export.
CREATE OR REPLACE FUNCTION private.call_history_export(p_user uuid)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT jsonb_build_object(
    'notice', 'Calls are never recorded. This lists when calls happened, how long they lasted and your call minutes.',
    'calls', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'match_id', r.match_id,
        'direction', CASE WHEN r.caller_id = p_user THEN 'outgoing' ELSE 'incoming' END,
        'status', CASE WHEN r.caller_id = p_user OR r.status <> 'unavailable'
          THEN r.status ELSE 'missed' END,
        'created_at', r.created_at,
        'answered_at', r.answered_at,
        'connected_seconds', s.connected_seconds,
        'charged_minutes', CASE WHEN r.caller_id = p_user THEN s.charged_minutes END,
        'removed_from_history_at', CASE WHEN r.caller_id = p_user
          THEN r.hidden_by_caller_at ELSE r.hidden_by_callee_at END
      ) ORDER BY r.created_at)
      FROM private.call_requests r
      LEFT JOIN private.call_sessions s ON s.request_id = r.id
      WHERE r.caller_id = p_user
         OR (r.callee_id = p_user AND NOT (r.status = 'unavailable' AND r.reason = 'calls_blocked'))
    ), '[]'::jsonb),
    'planned_calls', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'match_id', cp.match_id,
        'planned_for', cp.planned_for,
        'proposed_by_me', cp.proposer_id = p_user,
        'status', cp.status,
        'created_at', cp.created_at
      ) ORDER BY cp.created_at)
      FROM private.call_plans cp
      WHERE cp.proposer_id = p_user OR cp.invitee_id = p_user
    ), '[]'::jsonb),
    'call_setting', coalesce((SELECT mp.call_mode FROM private.call_member_prefs mp
                              WHERE mp.user_id = p_user), 'ring'),
    'minutes_ledger', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'kind', l.kind, 'pack_minutes', l.pack_minutes_delta,
        'included_minutes', l.included_minutes_delta, 'product_id', l.product_id,
        'created_at', l.created_at) ORDER BY l.id)
      FROM private.call_ledger l WHERE l.user_id = p_user
    ), '[]'::jsonb),
    'pack_minutes', coalesce((SELECT w.pack_minutes FROM private.call_wallets w
                              WHERE w.user_id = p_user), 0)
  );
$function$;

-- 324: no ring without a phone that can ring; first name only in the push;
-- the monthly brake.
CREATE OR REPLACE FUNCTION public.call_service_request(p_caller uuid, p_match_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_settings private.call_settings := private.call_settings_row();
  v_reason text;
  v_callee uuid;
  v_existing private.call_requests%ROWTYPE;
  v_state record;
  v_block_until timestamptz;
  v_mode text;
  v_pair private.call_pair_prefs%ROWTYPE;
  v_unavailable text;
  v_notify boolean := true;
  v_id uuid;
  v_token text;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF NOT v_settings.calls_enabled THEN
    RETURN jsonb_build_object('outcome', 'calls_disabled');
  END IF;
  IF private.call_member_block_reason(p_caller) IS NOT NULL THEN
    RETURN jsonb_build_object('outcome', 'account_restricted');
  END IF;
  v_reason := private.call_match_block_reason(p_match_id, p_caller);
  IF v_reason IS NOT NULL THEN
    RETURN jsonb_build_object('outcome', 'not_allowed', 'reason', v_reason);
  END IF;
  v_callee := private.call_match_other(p_match_id, p_caller);
  IF NOT public.has_active_premium(p_caller) THEN
    RETURN jsonb_build_object('outcome', 'premium_required');
  END IF;

  -- Both members, in a fixed order, so two simultaneous calls cannot both
  -- pass the busy check.
  PERFORM pg_advisory_xact_lock(hashtextextended(least(p_caller, v_callee)::text, 323));
  PERFORM pg_advisory_xact_lock(hashtextextended(greatest(p_caller, v_callee)::text, 323));
  PERFORM private.call_expire_ringing(p_caller);
  PERFORM private.call_expire_ringing(v_callee);

  -- Glare: they are already calling me in this chat. Answer that call.
  SELECT * INTO v_existing FROM private.call_requests r
  WHERE r.status = 'ringing' AND r.caller_id = v_callee AND r.callee_id = p_caller
    AND r.match_id = p_match_id AND r.ring_expires_at > now()
  ORDER BY r.created_at DESC LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('outcome', 'glare', 'request_id', v_existing.id);
  END IF;

  IF private.call_user_busy(p_caller) THEN
    RETURN jsonb_build_object('outcome', 'busy_self');
  END IF;

  SELECT * INTO v_state FROM private.call_wallet_state(p_caller, true);
  IF v_state.pack_minutes < 0 THEN
    RETURN jsonb_build_object('outcome', 'balance_negative',
      'pack_minutes', v_state.pack_minutes);
  END IF;
  IF v_state.available_minutes < 1 THEN
    RETURN jsonb_build_object('outcome', 'no_minutes');
  END IF;

  v_block_until := private.call_unanswered_block_until(p_caller, v_callee);
  IF v_block_until IS NOT NULL THEN
    RETURN jsonb_build_object('outcome', 'limit_reached', 'retry_after', v_block_until);
  END IF;

  -- 324: the brake is never below what members are entitled to (spec 5).
  IF private.call_month_committed_minutes() + 1 > private.call_month_cap_minutes() THEN
    RETURN jsonb_build_object('outcome', 'capacity');
  END IF;

  -- From here on the caller always sees the same neutral answer when the
  -- callee is not rung, whatever the reason.
  SELECT coalesce((SELECT mp.call_mode FROM private.call_member_prefs mp
                   WHERE mp.user_id = v_callee), 'ring') INTO v_mode;
  SELECT * INTO v_pair FROM private.call_pair_prefs pp
  WHERE pp.user_id = v_callee AND pp.other_user_id = p_caller;

  v_unavailable := CASE
    WHEN private.call_member_block_reason(v_callee) IN ('account_deleted', 'account_banned')
      THEN 'callee_unavailable'
    WHEN coalesce(v_pair.calls_blocked, false) THEN 'calls_blocked'
    WHEN private.call_member_block_reason(v_callee) IS NOT NULL THEN 'callee_unavailable'
    WHEN NOT private.call_premium_rule_ok(p_caller, v_callee) THEN 'callee_needs_premium'
    WHEN v_mode = 'off' THEN 'calls_off'
    WHEN v_mode = 'silent' THEN 'silent'
    WHEN coalesce(v_pair.muted, false) THEN 'muted'
    WHEN private.call_in_quiet_hours(v_callee) THEN 'quiet_hours'
    WHEN private.call_user_busy(v_callee) THEN 'busy'
    -- 324: no phone of theirs can ring (notifications off or an app
    -- version without calling). Same neutral answer for the caller.
    WHEN NOT private.call_user_can_ring(v_callee) THEN 'no_device'
    ELSE NULL
  END;
  -- A member who blocked calls from this person is not told about them, and
  -- deleted/banned accounts receive nothing.
  v_notify := v_unavailable IS DISTINCT FROM 'calls_blocked'
    AND private.call_member_block_reason(v_callee) IS DISTINCT FROM 'account_deleted'
    AND private.call_member_block_reason(v_callee) IS DISTINCT FROM 'account_banned';

  IF v_unavailable IS NOT NULL THEN
    INSERT INTO private.call_requests(match_id, caller_id, callee_id, status, reason, closed_at)
    VALUES (p_match_id, p_caller, v_callee, 'unavailable', v_unavailable, now())
    RETURNING id INTO v_id;
    IF v_notify THEN PERFORM private.call_queue_missed_note(v_id); END IF;
    RETURN jsonb_build_object('outcome', 'unavailable', 'request_id', v_id);
  END IF;

  v_token := encode(extensions.gen_random_bytes(24), 'hex');
  INSERT INTO private.call_requests(
    match_id, caller_id, callee_id, status, decline_token_hash, ring_expires_at
  ) VALUES (
    p_match_id, p_caller, v_callee, 'ringing',
    encode(extensions.digest(v_token, 'sha256'), 'hex'),
    now() + make_interval(secs => v_settings.ring_timeout_seconds)
  ) RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'outcome', 'ringing',
    'request_id', v_id,
    'match_id', p_match_id,
    'callee_id', v_callee,
    -- 324: pushes carry the first name only (spec 12.3).
    'caller_name', private.call_first_name(p_caller),
    'decline_token', v_token,
    'ring_expires_at', now() + make_interval(secs => v_settings.ring_timeout_seconds)
  );
END;
$function$;

-- 324: planned-call reminders and expiry.
CREATE OR REPLACE FUNCTION private.call_enqueue_due_work()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_settings private.call_settings := private.call_settings_row();
  v_row record;
  v_count integer := 0;
BEGIN
  v_count := v_count + private.call_expire_ringing(NULL);

  -- Global switch off: end everything.
  IF NOT v_settings.calls_enabled THEN
    FOR v_row IN
      SELECT r.id FROM private.call_requests r WHERE r.status = 'ringing'
      UNION
      SELECT s.request_id FROM private.call_sessions s WHERE s.status IN ('creating', 'active')
    LOOP
      IF private.call_end_request(v_row.id, 'calls_disabled') THEN v_count := v_count + 1; END IF;
    END LOOP;
  END IF;

  FOR v_row IN
    SELECT s.* FROM private.call_sessions s
    WHERE s.status IN ('creating', 'active')
    FOR UPDATE SKIP LOCKED
  LOOP
    IF v_row.status = 'creating' AND v_row.accepted_at < now() - interval '60 seconds' THEN
      PERFORM private.call_end_request(v_row.request_id, 'create_timeout');
      v_count := v_count + 1;
    ELSIF private.call_member_block_reason(v_row.caller_id) IS NOT NULL
      OR private.call_member_block_reason(v_row.callee_id) IS NOT NULL THEN
      PERFORM private.call_end_request(v_row.request_id, 'member_unavailable');
      v_count := v_count + 1;
    ELSIF private.call_match_block_reason(v_row.match_id, v_row.caller_id) IS NOT NULL THEN
      PERFORM private.call_end_request(v_row.request_id, 'match_closed');
      v_count := v_count + 1;
    ELSIF NOT private.call_premium_rule_ok(v_row.caller_id, v_row.callee_id) THEN
      PERFORM private.call_end_request(v_row.request_id, 'premium_lost');
      v_count := v_count + 1;
    ELSIF v_row.status = 'active' AND v_row.both_joined_at IS NULL
      AND v_row.accepted_at < now() - make_interval(secs => v_settings.join_timeout_seconds) THEN
      PERFORM private.call_enqueue_job('join_check', v_row.request_id);
      v_count := v_count + 1;
    ELSIF v_row.accepted_at
      < now() - make_interval(secs => v_row.max_duration_seconds + 120) THEN
      -- Stream's own timer should have ended it; make sure.
      PERFORM private.call_end_request(v_row.request_id, 'overdue');
      v_count := v_count + 1;
    END IF;
  END LOOP;

  -- An end that never got confirmed is retried; an ended call is settled.
  FOR v_row IN
    SELECT s.request_id, s.status FROM private.call_sessions s
    WHERE (s.status = 'ending' AND s.end_requested_at < now() - interval '60 seconds')
       OR (s.status = 'ended' AND coalesce(s.ended_at, s.accepted_at) < now() - interval '60 seconds')
  LOOP
    PERFORM private.call_enqueue_job(
      CASE WHEN v_row.status = 'ending' THEN 'end_stream_call' ELSE 'settle' END,
      v_row.request_id);
  END LOOP;

  -- 324: planned calls. The reminder is taken once (reminder_sent_at) and
  -- sent by call-worker; plans past their window are closed.
  FOR v_row IN
    UPDATE private.call_plans cp SET reminder_sent_at = now()
    WHERE cp.status = 'accepted' AND cp.reminder_sent_at IS NULL
      AND cp.planned_for <= now() + make_interval(mins => v_settings.plan_reminder_minutes)
      AND cp.planned_for > now() - make_interval(mins => v_settings.plan_window_minutes)
    RETURNING cp.id
  LOOP
    PERFORM private.call_enqueue_plan_job('plan_reminder', v_row.id);
    v_count := v_count + 1;
  END LOOP;
  v_count := v_count + private.call_close_due_plans();

  DELETE FROM private.stream_webhook_deliveries WHERE received_at < now() - interval '7 days';
  DELETE FROM private.call_jobs WHERE status IN ('done', 'dead') AND created_at < now() - interval '30 days';
  RETURN v_count;
END;
$function$;

-- 324: the hold respects the brake, which covers entitled minutes.
CREATE OR REPLACE FUNCTION private.call_place_hold(p_request_id uuid, p_caller uuid)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_settings private.call_settings := private.call_settings_row();
  v_state record;
  v_hold integer;
  v_included integer;
  v_pack integer;
  v_cap_room integer;
BEGIN
  SELECT * INTO v_state FROM private.call_wallet_state(p_caller, true);
  v_cap_room := private.call_month_cap_minutes() - private.call_month_committed_minutes();
  v_hold := least(v_state.available_minutes, v_settings.max_hold_minutes, greatest(v_cap_room, 0));
  IF v_hold < 1 THEN RETURN 0; END IF;
  v_included := least(v_hold, v_state.included_remaining);
  v_pack := v_hold - v_included;

  IF v_included > 0 THEN
    UPDATE private.call_included_periods
    SET used_minutes = used_minutes + v_included
    WHERE user_id = p_caller AND period_start = v_state.period_start;
  END IF;
  IF v_pack > 0 THEN
    UPDATE private.call_wallets
    SET pack_minutes = pack_minutes - v_pack, updated_at = now()
    WHERE user_id = p_caller;
  END IF;
  INSERT INTO private.call_holds(request_id, included_minutes, pack_minutes, period_start)
  VALUES (p_request_id, v_included, v_pack, v_state.period_start);
  INSERT INTO private.call_ledger(
    user_id, kind, pack_minutes_delta, included_minutes_delta, request_id
  ) VALUES (p_caller, 'hold', -v_pack, -v_included, p_request_id);
  RETURN v_hold;
END;
$function$;

CREATE OR REPLACE FUNCTION public.call_service_settle(
  p_request_id uuid,
  p_connected_seconds integer,
  p_source text,
  p_stream_session_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_cap integer;
  v_settings private.call_settings := private.call_settings_row();
  v_session private.call_sessions%ROWTYPE;
  v_seconds integer := greatest(coalesce(p_connected_seconds, 0), 0);
  v_charge integer;
  v_result record;
  v_month date := private.call_month_start();
  v_used integer;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_session FROM private.call_sessions WHERE request_id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('outcome', 'not_found'); END IF;
  IF v_session.status IN ('settled', 'failed') THEN
    RETURN jsonb_build_object('outcome', 'already_settled',
      'charged_minutes', v_session.charged_minutes);
  END IF;
  IF v_session.status <> 'ended' THEN
    RETURN jsonb_build_object('outcome', 'not_ended');
  END IF;

  v_charge := least(ceil(v_seconds / 60.0)::integer, v_session.hold_minutes);
  SELECT * INTO v_result FROM private.call_release_holds(
    p_request_id, v_charge, 'settled:' || left(coalesce(p_source, 'unknown'), 40));
  UPDATE private.call_sessions
  SET status = 'settled',
      connected_seconds = v_seconds,
      charged_minutes = v_charge,
      charged_included_minutes = v_result.charged_included,
      charged_pack_minutes = v_result.charged_pack,
      settled_at = now(),
      settle_source = left(p_source, 40),
      stream_session_id = coalesce(stream_session_id, left(p_stream_session_id, 200))
  WHERE request_id = p_request_id;
  UPDATE private.call_requests SET closed_at = coalesce(closed_at, now())
  WHERE id = p_request_id;

  INSERT INTO private.call_usage_months(month_start, charged_minutes)
  VALUES (v_month, v_charge)
  ON CONFLICT (month_start) DO UPDATE
  SET charged_minutes = private.call_usage_months.charged_minutes + EXCLUDED.charged_minutes,
      updated_at = now()
  RETURNING charged_minutes INTO v_used;

  -- 324: alerts against the brake actually in force.
  v_cap := private.call_month_cap_minutes();
  IF v_cap > 0 THEN
    PERFORM private.set_operational_alert(
      'voice_call_minutes_70',
      format('Voice calls used %s of the %s-minute monthly brake (70%% alert).', v_used, v_cap),
      v_used, v_used >= v_cap * 0.7);
    PERFORM private.set_operational_alert(
      'voice_call_minutes_90',
      format('Voice calls used %s of the %s-minute monthly brake (90%% alert). New calls pause at 100%%.',
             v_used, v_cap),
      v_used, v_used >= v_cap * 0.9);
  END IF;

  RETURN jsonb_build_object(
    'outcome', 'settled',
    'connected_seconds', v_seconds,
    'charged_minutes', v_charge,
    'charged_included_minutes', v_result.charged_included,
    'charged_pack_minutes', v_result.charged_pack
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_call_overview()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_settings private.call_settings := private.call_settings_row();
BEGIN
  -- 324: staff roles are super_admin, moderator and support.
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator', 'support']) THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  RETURN jsonb_build_object(
    'calls_enabled', v_settings.calls_enabled,
    'monthly_cap_minutes', v_settings.monthly_cap_minutes,
    'effective_cap_minutes', private.call_month_cap_minutes(),
    'auto_cap_minutes', v_settings.auto_cap_minutes,
    -- Stream audio: $0.30 per 1,000 participant minutes, 2 per call minute.
    'estimated_stream_cost_usd', round(coalesce((SELECT charged_minutes FROM private.call_usage_months
                                       WHERE month_start = private.call_month_start()), 0) * 0.0006, 2),
    'month_charged_minutes', coalesce((SELECT charged_minutes FROM private.call_usage_months
                                       WHERE month_start = private.call_month_start()), 0),
    'open_hold_minutes', coalesce((SELECT sum(hold_minutes) FROM private.call_sessions
                                   WHERE status IN ('creating', 'active', 'ending', 'ended')), 0),
    'live_calls', (SELECT count(*) FROM private.call_sessions WHERE status IN ('creating', 'active')),
    'calls_today', (SELECT count(*) FROM private.call_requests WHERE created_at > now() - interval '24 hours'),
    'dead_jobs', (SELECT count(*) FROM private.call_jobs WHERE status = 'dead')
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4. Ring capability and missed-call pushes (service side)
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.set_my_call_ring_capability(p_device_id text, p_can_ring boolean)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := private.assert_authenticated();
BEGIN
  IF p_device_id IS NULL OR char_length(p_device_id) NOT BETWEEN 8 AND 128
    OR p_can_ring IS NULL THEN
    RAISE EXCEPTION 'invalid_device' USING ERRCODE = '22023';
  END IF;
  INSERT INTO private.call_device_capabilities(user_id, device_id, can_ring)
  VALUES (v_me, p_device_id, p_can_ring)
  ON CONFLICT (user_id, device_id) DO UPDATE
  SET can_ring = EXCLUDED.can_ring, updated_at = now();
  -- At most 10 remembered phones per member.
  DELETE FROM private.call_device_capabilities c
  WHERE c.user_id = v_me AND c.device_id IN (
    SELECT c2.device_id FROM private.call_device_capabilities c2
    WHERE c2.user_id = v_me ORDER BY c2.updated_at DESC OFFSET 10);
  RETURN p_can_ring;
END;
$function$;

-- What the missed-call push for p_request_id says, or send = false.
CREATE FUNCTION public.call_service_missed_push(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_request private.call_requests%ROWTYPE;
  v_mode text;
  v_wants boolean;
  v_muted boolean;
  v_count integer;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_request FROM private.call_requests WHERE id = p_request_id;
  IF NOT FOUND
    OR NOT private.call_missed_for_callee(v_request.status, v_request.reason)
    OR private.call_member_block_reason(v_request.callee_id)
         IN ('account_deleted', 'account_banned')
    OR private.call_peer_unavailable(v_request.callee_id, v_request.caller_id) THEN
    RETURN jsonb_build_object('send', false);
  END IF;
  SELECT coalesce((SELECT mp.call_mode FROM private.call_member_prefs mp
                   WHERE mp.user_id = v_request.callee_id), 'ring') INTO v_mode;
  SELECT coalesce((SELECT np.missed_call FROM public.notification_prefs np
                   WHERE np.user_id = v_request.callee_id), true) INTO v_wants;
  IF v_mode = 'off' OR NOT v_wants THEN
    RETURN jsonb_build_object('send', false);
  END IF;
  -- Opened the Calls tab since: nothing to tell.
  v_count := private.call_unseen_missed(v_request.callee_id, v_request.caller_id);
  IF v_count = 0 THEN
    RETURN jsonb_build_object('send', false);
  END IF;
  SELECT coalesce((SELECT pp.muted FROM private.call_pair_prefs pp
                   WHERE pp.user_id = v_request.callee_id
                     AND pp.other_user_id = v_request.caller_id), false) INTO v_muted;
  RETURN jsonb_build_object(
    'send', true,
    'request_id', v_request.id,
    'callee_id', v_request.callee_id,
    'caller_id', v_request.caller_id,
    'match_id', v_request.match_id,
    'caller_name', private.call_first_name(v_request.caller_id),
    'count', v_count,
    'variant', CASE
      WHEN NOT private.call_is_female(v_request.callee_id)
        AND NOT public.has_active_premium(v_request.callee_id) THEN 'premium'
      ELSE 'missed' END,
    'silent', v_mode = 'silent' OR v_muted OR v_request.reason = 'busy'
      OR private.call_in_quiet_hours(v_request.callee_id)
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5. Calls tab (member RPCs)
-- ---------------------------------------------------------------------------

-- One page of the member's own call log, newest first. Cursor: the last
-- row's (created_at, request_id). p_filter: all | missed | incoming |
-- outgoing. p_query matches the first name the member can see.
-- p_other_user_id: only calls with that member (the call details sheet).
CREATE FUNCTION public.get_my_call_log(
  p_filter text DEFAULT 'all',
  p_query text DEFAULT NULL,
  p_before timestamptz DEFAULT NULL,
  p_before_id uuid DEFAULT NULL,
  p_limit integer DEFAULT 40,
  p_other_user_id uuid DEFAULT NULL
)
RETURNS TABLE (
  request_id uuid,
  created_at timestamptz,
  direction text,
  outcome text,
  talk_seconds integer,
  minutes_used integer,
  match_id uuid,
  other_user_id uuid,
  other_first_name text,
  other_last_name text,
  member_unavailable boolean,
  unseen boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
#variable_conflict use_column
DECLARE
  v_me uuid := private.assert_authenticated();
  v_filter text := coalesce(nullif(p_filter, ''), 'all');
  v_limit integer := least(greatest(coalesce(p_limit, 40), 1), 100);
  v_pattern text;
  v_seen timestamptz;
BEGIN
  IF v_filter NOT IN ('all', 'missed', 'incoming', 'outgoing') THEN
    RAISE EXCEPTION 'invalid_filter' USING ERRCODE = '22023';
  END IF;
  IF (p_before IS NULL) <> (p_before_id IS NULL) THEN
    RAISE EXCEPTION 'invalid_cursor' USING ERRCODE = '22023';
  END IF;
  IF nullif(trim(coalesce(p_query, '')), '') IS NOT NULL THEN
    v_pattern := '%' || replace(replace(replace(left(trim(p_query), 40),
      '\', '\\'), '%', '\%'), '_', '\_') || '%';
  END IF;
  SELECT mp.calls_seen_at INTO v_seen FROM private.call_member_prefs mp WHERE mp.user_id = v_me;

  RETURN QUERY
  WITH mine AS (
    (
      SELECT r.id, r.created_at, r.caller_id, r.callee_id, r.match_id, r.status, r.reason,
             r.callee_id AS other_id
      FROM private.call_requests r
      WHERE v_filter IN ('all', 'outgoing')
        AND r.caller_id = v_me AND r.hidden_by_caller_at IS NULL
        AND (p_other_user_id IS NULL OR r.callee_id = p_other_user_id)
        AND (p_before IS NULL OR (r.created_at, r.id) < (p_before, p_before_id))
        AND (v_pattern IS NULL OR EXISTS (
          SELECT 1 FROM public.profiles p
          WHERE p.user_id = r.callee_id AND p.first_name ILIKE v_pattern))
      ORDER BY r.created_at DESC, r.id DESC
      LIMIT v_limit
    )
    UNION ALL
    (
      SELECT r.id, r.created_at, r.caller_id, r.callee_id, r.match_id, r.status, r.reason,
             r.caller_id AS other_id
      FROM private.call_requests r
      WHERE v_filter IN ('all', 'incoming', 'missed')
        AND r.callee_id = v_me AND r.hidden_by_callee_at IS NULL
        AND (p_other_user_id IS NULL OR r.caller_id = p_other_user_id)
        AND NOT (r.status = 'unavailable' AND r.reason = 'calls_blocked')
        AND (v_filter <> 'missed' OR private.call_missed_for_callee(r.status, r.reason))
        AND (p_before IS NULL OR (r.created_at, r.id) < (p_before, p_before_id))
        AND (v_pattern IS NULL OR EXISTS (
          SELECT 1 FROM public.profiles p
          WHERE p.user_id = r.caller_id AND p.first_name ILIKE v_pattern))
      ORDER BY r.created_at DESC, r.id DESC
      LIMIT v_limit
    )
  ),
  page AS (
    SELECT * FROM mine ORDER BY mine.created_at DESC, mine.id DESC LIMIT v_limit
  )
  SELECT
    page.id,
    page.created_at,
    CASE WHEN page.caller_id = v_me THEN 'outgoing' ELSE 'incoming' END,
    private.call_outcome_for(v_me, page.caller_id, page.status, s.connected_seconds, s.status),
    CASE WHEN page.status = 'accepted' THEN s.connected_seconds END,
    CASE WHEN page.caller_id = v_me THEN s.charged_minutes END,
    page.match_id,
    CASE WHEN peer.unavailable THEN NULL ELSE page.other_id END,
    CASE WHEN peer.unavailable THEN 'Silarah member'
      ELSE coalesce(nullif(trim(op.first_name), ''), 'Member') END,
    CASE WHEN peer.unavailable THEN ''
      WHEN m.status = 'active' THEN coalesce(nullif(trim(op.last_name), ''), '')
      ELSE left(coalesce(trim(op.last_name), ''), 1) END,
    peer.unavailable,
    page.callee_id = v_me
      AND private.call_missed_for_callee(page.status, page.reason)
      AND page.created_at > coalesce(v_seen, '-infinity'::timestamptz)
  FROM page
  LEFT JOIN private.call_sessions s ON s.request_id = page.id
  LEFT JOIN public.matches m ON m.id = page.match_id
  LEFT JOIN public.profiles op ON op.user_id = page.other_id
  CROSS JOIN LATERAL (
    SELECT private.call_peer_unavailable(v_me, page.other_id) AS unavailable
  ) peer
  ORDER BY page.created_at DESC, page.id DESC;
END;
$function$;

-- Plans the viewer can see, open ones first (spec 13).
CREATE FUNCTION private.call_plans_for(p_viewer uuid, p_open_only boolean, p_limit integer)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT coalesce(jsonb_agg(pl ORDER BY (pl->>'open')::boolean DESC,
    CASE WHEN (pl->>'open')::boolean THEN (pl->>'planned_for')::timestamptz END ASC,
    (pl->>'planned_for')::timestamptz DESC), '[]'::jsonb)
  FROM (
    SELECT jsonb_build_object(
      'id', cp.id,
      'match_id', cp.match_id,
      'planned_for', cp.planned_for,
      'status', cp.status,
      'open', cp.status IN ('proposed', 'accepted'),
      'i_proposed', cp.proposer_id = p_viewer,
      'other_user_id', CASE WHEN peer.unavailable THEN NULL ELSE other.id END,
      'other_first_name', CASE WHEN peer.unavailable THEN 'Silarah member'
        ELSE coalesce(nullif(trim(op.first_name), ''), 'Member') END,
      'other_last_name', CASE WHEN peer.unavailable THEN ''
        WHEN m.status = 'active' THEN coalesce(nullif(trim(op.last_name), ''), '')
        ELSE left(coalesce(trim(op.last_name), ''), 1) END,
      'member_unavailable', peer.unavailable,
      -- What this member can do now.
      'action', CASE
        WHEN cp.status = 'proposed' AND cp.invitee_id = p_viewer THEN 'respond'
        WHEN cp.status <> 'accepted' THEN 'none'
        WHEN now() < cp.planned_for
               - make_interval(mins => (private.call_settings_row()).plan_reminder_minutes) THEN 'wait_for_time'
        WHEN public.has_active_premium(p_viewer) THEN 'call'
        WHEN NOT private.call_is_female(p_viewer) THEN 'paywall'
        ELSE 'wait_for_call'
      END
    ) AS pl
    FROM private.call_plans cp
    JOIN public.matches m ON m.id = cp.match_id
    CROSS JOIN LATERAL (
      SELECT CASE WHEN cp.proposer_id = p_viewer THEN cp.invitee_id ELSE cp.proposer_id END AS id
    ) other
    LEFT JOIN public.profiles op ON op.user_id = other.id
    CROSS JOIN LATERAL (
      SELECT private.call_peer_unavailable(p_viewer, other.id) AS unavailable
    ) peer
    WHERE (cp.proposer_id = p_viewer OR cp.invitee_id = p_viewer)
      AND (NOT p_open_only OR (cp.status IN ('proposed', 'accepted')
           AND cp.planned_for > now()
                 - make_interval(mins => (private.call_settings_row()).plan_window_minutes)
           AND m.status = 'active' AND NOT peer.unavailable))
    ORDER BY cp.planned_for DESC
    LIMIT least(greatest(p_limit, 1), 100)
  ) plans;
$function$;

-- Everything above the Calls tab history in one call.
CREATE FUNCTION public.get_my_call_overview()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_settings private.call_settings := private.call_settings_row();
  v_state record;
  v_tz text;
  v_month_start timestamptz;
  v_talk integer;
BEGIN
  SELECT * INTO v_state FROM private.call_wallet_state(v_me, false);
  SELECT CASE WHEN EXISTS (SELECT 1 FROM private.timezone_names tz WHERE tz.name = u.timezone)
           THEN u.timezone ELSE 'UTC' END
  INTO v_tz FROM public.users u WHERE u.id = v_me;
  v_month_start := date_trunc('month', now() AT TIME ZONE coalesce(v_tz, 'UTC'))
                   AT TIME ZONE coalesce(v_tz, 'UTC');
  SELECT coalesce(sum(s.connected_seconds), 0)::integer INTO v_talk
  FROM private.call_sessions s
  WHERE (s.caller_id = v_me OR s.callee_id = v_me)
    AND s.accepted_at >= v_month_start AND coalesce(s.connected_seconds, 0) > 0;
  RETURN jsonb_build_object(
    'calls_enabled', v_settings.calls_enabled,
    'premium', v_state.premium,
    'female', private.call_is_female(v_me),
    'call_mode', coalesce((SELECT mp.call_mode FROM private.call_member_prefs mp
                           WHERE mp.user_id = v_me), 'ring'),
    'included_minutes', v_state.included_remaining,
    'included_granted', v_state.included_granted,
    'included_period_end', v_state.period_end,
    'pack_minutes', v_state.pack_minutes,
    'available_minutes', v_state.available_minutes,
    'can_buy_packs', v_state.premium
      AND v_state.pack_refund_count < v_settings.max_pack_refunds,
    'month_talk_seconds', v_talk,
    'unseen_missed', private.call_unseen_missed(v_me),
    'plans', private.call_plans_for(v_me, true, 20)
  );
END;
$function$;

CREATE FUNCTION public.get_my_call_plans()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT private.call_plans_for(private.assert_authenticated(), false, 50);
$function$;

-- Opening the Calls tab: the badge clears here and on the member's other
-- phones.
CREATE FUNCTION public.mark_calls_seen()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_unseen integer := private.call_unseen_missed(v_me);
BEGIN
  INSERT INTO private.call_member_prefs(user_id, calls_seen_at) VALUES (v_me, now())
  ON CONFLICT (user_id) DO UPDATE SET calls_seen_at = now(), updated_at = now();
  IF v_unseen > 0 THEN
    PERFORM private.call_enqueue_job('seen_push', NULL, v_me);
  END IF;
  RETURN v_unseen;
END;
$function$;

-- Remove from history: only for this member.
CREATE FUNCTION public.hide_my_calls(p_request_ids uuid[])
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_caller integer;
  v_callee integer;
BEGIN
  IF p_request_ids IS NULL OR cardinality(p_request_ids) = 0 THEN RETURN 0; END IF;
  IF cardinality(p_request_ids) > 200 THEN
    RAISE EXCEPTION 'too_many_calls' USING ERRCODE = '22023';
  END IF;
  UPDATE private.call_requests SET hidden_by_caller_at = now()
  WHERE id = ANY (p_request_ids) AND caller_id = v_me AND hidden_by_caller_at IS NULL
    AND status <> 'ringing';
  GET DIAGNOSTICS v_caller = ROW_COUNT;
  UPDATE private.call_requests SET hidden_by_callee_at = now()
  WHERE id = ANY (p_request_ids) AND callee_id = v_me AND hidden_by_callee_at IS NULL
    AND status <> 'ringing';
  GET DIAGNOSTICS v_callee = ROW_COUNT;
  RETURN v_caller + v_callee;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 6. Planned calls (spec 13)
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.propose_call_plan(p_match_id uuid, p_planned_for timestamptz)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_settings private.call_settings := private.call_settings_row();
  v_other uuid;
  v_open uuid;
  v_id uuid;
BEGIN
  IF NOT v_settings.calls_enabled THEN
    RETURN jsonb_build_object('outcome', 'calls_disabled');
  END IF;
  IF private.call_member_block_reason(v_me) IS NOT NULL THEN
    RETURN jsonb_build_object('outcome', 'account_restricted');
  END IF;
  IF private.call_match_block_reason(p_match_id, v_me) IS NOT NULL THEN
    RETURN jsonb_build_object('outcome', 'not_allowed');
  END IF;
  -- A free man can neither call nor plan a call.
  IF NOT private.call_is_female(v_me) AND NOT public.has_active_premium(v_me) THEN
    RETURN jsonb_build_object('outcome', 'premium_required');
  END IF;
  -- Their own calls must be able to ring to be called back.
  IF private.call_mode_of(v_me) = 'off' THEN
    RETURN jsonb_build_object('outcome', 'calls_off_self');
  END IF;
  IF p_planned_for IS NULL
    OR p_planned_for < now() + make_interval(mins => v_settings.plan_min_lead_minutes)
    OR p_planned_for > now() + make_interval(days => v_settings.plan_max_days_ahead) THEN
    RETURN jsonb_build_object('outcome', 'invalid_time');
  END IF;
  v_other := private.call_match_other(p_match_id, v_me);
  PERFORM pg_advisory_xact_lock(hashtextextended(p_match_id::text, 324));
  SELECT cp.id INTO v_open FROM private.call_plans cp
  WHERE cp.match_id = p_match_id AND cp.status IN ('proposed', 'accepted')
    AND cp.planned_for > now() - make_interval(mins => v_settings.plan_window_minutes);
  IF v_open IS NOT NULL THEN
    RETURN jsonb_build_object('outcome', 'already_planned', 'plan_id', v_open);
  END IF;
  -- A plan that is still open but past its window no longer blocks a new one.
  UPDATE private.call_plans SET status = 'expired', closed_at = now()
  WHERE match_id = p_match_id AND status IN ('proposed', 'accepted');
  IF (SELECT count(*) FROM private.call_plans cp
      WHERE cp.proposer_id = v_me AND cp.status IN ('proposed', 'accepted')
        AND cp.planned_for > now() - make_interval(mins => v_settings.plan_window_minutes))
       >= v_settings.plan_max_open
    -- Proposing and cancelling in a loop would notify the other member each
    -- time: a few proposals per chat per 24 hours.
    OR (SELECT count(*) FROM private.call_plans cp
        WHERE cp.proposer_id = v_me AND cp.match_id = p_match_id
          AND cp.created_at > now() - interval '24 hours') >= v_settings.plan_max_per_chat_day THEN
    RETURN jsonb_build_object('outcome', 'limit_reached');
  END IF;
  -- Neutral: never say whether they turned calls off, blocked calls, or
  -- (a free man) cannot talk.
  IF private.call_member_block_reason(v_other) IS NOT NULL
    OR NOT private.call_pair_premium_ok(v_me, v_other)
    OR private.call_mode_of(v_other) = 'off'
    OR coalesce((SELECT pp.calls_blocked FROM private.call_pair_prefs pp
                 WHERE pp.user_id = v_other AND pp.other_user_id = v_me), false) THEN
    RETURN jsonb_build_object('outcome', 'unavailable');
  END IF;

  INSERT INTO private.call_plans(match_id, proposer_id, invitee_id, planned_for)
  VALUES (p_match_id, v_me, v_other, date_trunc('minute', p_planned_for))
  RETURNING id INTO v_id;
  PERFORM private.call_plan_notify(v_id, v_other, 'proposed');
  RETURN jsonb_build_object('outcome', 'proposed', 'plan_id', v_id);
END;
$function$;

CREATE FUNCTION public.respond_call_plan(p_plan_id uuid, p_accept boolean)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_plan private.call_plans%ROWTYPE;
BEGIN
  SELECT * INTO v_plan FROM private.call_plans WHERE id = p_plan_id FOR UPDATE;
  IF NOT FOUND OR v_plan.invitee_id <> v_me THEN
    RETURN jsonb_build_object('outcome', 'not_found');
  END IF;
  IF v_plan.status <> 'proposed' OR v_plan.planned_for <= now() THEN
    RETURN jsonb_build_object('outcome', 'closed', 'status', v_plan.status);
  END IF;
  IF coalesce(p_accept, false) THEN
    IF private.call_match_block_reason(v_plan.match_id, v_me) IS NOT NULL
      OR private.call_member_block_reason(v_me) IS NOT NULL THEN
      RETURN jsonb_build_object('outcome', 'not_allowed');
    END IF;
    -- A free man accepts only with Premium; the other side is never told why.
    IF NOT private.call_is_female(v_me) AND NOT public.has_active_premium(v_me) THEN
      RETURN jsonb_build_object('outcome', 'premium_required');
    END IF;
    IF NOT private.call_pair_premium_ok(v_me, v_plan.proposer_id) THEN
      RETURN jsonb_build_object('outcome', 'not_allowed');
    END IF;
    IF private.call_mode_of(v_me) = 'off' THEN
      RETURN jsonb_build_object('outcome', 'calls_off_self');
    END IF;
    UPDATE private.call_plans SET status = 'accepted', responded_at = now() WHERE id = p_plan_id;
    PERFORM private.call_plan_notify(p_plan_id, v_plan.proposer_id, 'accepted');
    RETURN jsonb_build_object('outcome', 'accepted');
  END IF;
  -- Declined: the proposer sees it was not accepted, never why, and gets no push.
  UPDATE private.call_plans
  SET status = 'declined', responded_at = now(), closed_at = now(), closed_by = v_me
  WHERE id = p_plan_id;
  RETURN jsonb_build_object('outcome', 'declined');
END;
$function$;

CREATE FUNCTION public.cancel_call_plan(p_plan_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_plan private.call_plans%ROWTYPE;
  v_other uuid;
BEGIN
  SELECT * INTO v_plan FROM private.call_plans WHERE id = p_plan_id FOR UPDATE;
  IF NOT FOUND OR v_me NOT IN (v_plan.proposer_id, v_plan.invitee_id) THEN
    RETURN jsonb_build_object('outcome', 'not_found');
  END IF;
  IF v_plan.status NOT IN ('proposed', 'accepted') THEN
    RETURN jsonb_build_object('outcome', 'closed', 'status', v_plan.status);
  END IF;
  UPDATE private.call_plans SET status = 'cancelled', closed_at = now(), closed_by = v_me
  WHERE id = p_plan_id;
  v_other := CASE WHEN v_plan.proposer_id = v_me THEN v_plan.invitee_id ELSE v_plan.proposer_id END;
  IF v_plan.status = 'accepted' AND v_plan.planned_for
       > now() - make_interval(mins => (private.call_settings_row()).plan_window_minutes) THEN
    PERFORM private.call_plan_notify(p_plan_id, v_other, 'cancelled');
  END IF;
  RETURN jsonb_build_object('outcome', 'cancelled');
END;
$function$;

-- In-app notification (and push, after quiet hours) about a plan. First
-- name only; opens the Calls tab.
CREATE FUNCTION private.call_plan_notify(p_plan_id uuid, p_to uuid, p_event text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_plan private.call_plans%ROWTYPE;
  v_from uuid;
  v_name text;
BEGIN
  SELECT * INTO v_plan FROM private.call_plans WHERE id = p_plan_id;
  IF NOT FOUND THEN RETURN; END IF;
  v_from := CASE WHEN v_plan.proposer_id = p_to THEN v_plan.invitee_id ELSE v_plan.proposer_id END;
  IF coalesce((SELECT mp.call_mode FROM private.call_member_prefs mp
               WHERE mp.user_id = p_to), 'ring') = 'off' THEN
    RETURN;
  END IF;
  v_name := private.call_first_name(v_from);
  BEGIN
    PERFORM public.queue_notification(
      p_to,
      'call_plan',
      CASE p_event WHEN 'proposed' THEN 'Call time suggested'
                   WHEN 'accepted' THEN 'Call time accepted'
                   ELSE 'Call time cancelled' END,
      v_name || CASE p_event WHEN 'proposed' THEN ' suggested a time to talk.'
                             WHEN 'accepted' THEN ' accepted your call time.'
                             ELSE ' cancelled the call time.' END,
      'silarah://calls'
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Call plan note for % not queued: %', p_plan_id, SQLERRM;
  END;
END;
$function$;

-- The reminder 5 minutes before: who gets it and what it says.
CREATE FUNCTION public.call_service_plan_reminder(p_plan_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_plan private.call_plans%ROWTYPE;
  v_to jsonb := '[]'::jsonb;
  v_user uuid;
  v_other uuid;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_plan FROM private.call_plans WHERE id = p_plan_id;
  IF NOT FOUND OR v_plan.status <> 'accepted'
    OR v_plan.planned_for < now()
         - make_interval(mins => (private.call_settings_row()).plan_window_minutes)
    OR private.call_match_block_reason(v_plan.match_id, v_plan.proposer_id) IS NOT NULL THEN
    RETURN jsonb_build_object('send', false, 'to', v_to);
  END IF;
  FOREACH v_user IN ARRAY ARRAY[v_plan.proposer_id, v_plan.invitee_id] LOOP
    v_other := CASE WHEN v_user = v_plan.proposer_id THEN v_plan.invitee_id ELSE v_plan.proposer_id END;
    IF private.call_member_block_reason(v_user) IS NULL
      AND coalesce((SELECT mp.call_mode FROM private.call_member_prefs mp
                    WHERE mp.user_id = v_user), 'ring') <> 'off' THEN
      v_to := v_to || jsonb_build_array(jsonb_build_object(
        'user_id', v_user,
        'other_name', private.call_first_name(v_other),
        'match_id', v_plan.match_id,
        'plan_id', v_plan.id,
        'planned_for', v_plan.planned_for,
        -- Quiet hours: shown, but without sound (spec 13.3).
        'silent', private.call_in_quiet_hours(v_user)
          OR private.call_mode_of(v_user) = 'silent'));
    END IF;
  END LOOP;
  RETURN jsonb_build_object('send', jsonb_array_length(v_to) > 0, 'to', v_to);
END;
$function$;

-- Closes plans past their window: done when the two connected around the
-- planned time, otherwise expired. Plans whose chat ended are cancelled.
CREATE FUNCTION private.call_close_due_plans()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_settings private.call_settings := private.call_settings_row();
  v_count integer := 0;
  v_n integer;
BEGIN
  -- Plans end when the chat ends, someone blocks, or the man's Premium ends.
  UPDATE private.call_plans cp SET status = 'cancelled', closed_at = now()
  WHERE cp.status IN ('proposed', 'accepted')
    AND (private.call_match_block_reason(cp.match_id, cp.proposer_id) IS NOT NULL
         OR NOT private.call_pair_premium_ok(cp.proposer_id, cp.invitee_id));
  GET DIAGNOSTICS v_n = ROW_COUNT; v_count := v_count + v_n;

  UPDATE private.call_plans cp
  SET status = CASE WHEN cp.status = 'accepted' AND EXISTS (
        SELECT 1 FROM private.call_requests r
        JOIN private.call_sessions s ON s.request_id = r.id
        WHERE r.match_id = cp.match_id
          AND r.created_at BETWEEN cp.planned_for - make_interval(mins => v_settings.plan_min_lead_minutes)
                               AND cp.planned_for + make_interval(mins => v_settings.plan_window_minutes)
          AND coalesce(s.connected_seconds, 0) > 0
      ) THEN 'done' ELSE 'expired' END,
      closed_at = now()
  WHERE cp.status IN ('proposed', 'accepted')
    AND cp.planned_for < CASE WHEN cp.status = 'proposed' THEN now()
                              ELSE now() - make_interval(mins => v_settings.plan_window_minutes) END;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_count := v_count + v_n;
  RETURN v_count;
END;
$function$;

-- Guardian mode: planned call times only (spec 13.4).
CREATE FUNCTION public.get_guardian_match_call_plans(p_match_id uuid)
RETURNS TABLE (planned_for timestamptz, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF NOT public.can_read_guardian_mirror(p_match_id) THEN
    RAISE EXCEPTION 'guardian_access_required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT cp.planned_for, cp.status FROM private.call_plans cp
  WHERE cp.match_id = p_match_id AND cp.status IN ('accepted', 'done', 'expired')
  ORDER BY cp.planned_for DESC
  LIMIT 50;
END;
$function$;

-- Every number the app tells a member about calling (spec 12.6). Any
-- signed-in account (Guardians too: their call log follows the switch).
CREATE FUNCTION public.get_calling_rules()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT jsonb_build_object(
    'calls_enabled', s.calls_enabled,
    'unanswered_call_limit', s.unanswered_call_limit,
    'included_minutes', s.included_minutes,
    'included_period_days', s.included_period_days,
    'max_call_minutes', s.max_hold_minutes,
    'ring_seconds', s.ring_timeout_seconds,
    'max_pack_refunds', s.max_pack_refunds,
    'min_minutes_to_call', 1,
    'plan_min_lead_minutes', s.plan_min_lead_minutes,
    'plan_max_days_ahead', s.plan_max_days_ahead,
    'plan_window_minutes', s.plan_window_minutes,
    'plan_reminder_minutes', s.plan_reminder_minutes,
    'plan_max_open', s.plan_max_open,
    'plan_max_per_chat_day', s.plan_max_per_chat_day,
    'log_retention_months', s.log_retention_months
  )
  FROM private.call_settings s
  WHERE s.id AND auth.uid() IS NOT NULL;
$function$;

-- Daily: call records older than the retention period go, except while an
-- open report between the two members needs them (spec 12.7). Minutes
-- ledger rows are the member's account history and go with the account.
CREATE FUNCTION private.call_purge_old_records()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_cutoff timestamptz := now()
    - make_interval(months => (private.call_settings_row()).log_retention_months);
  v_n integer;
  v_total integer := 0;
BEGIN
  DELETE FROM private.call_requests r
  WHERE r.created_at < v_cutoff
    AND r.status NOT IN ('ringing')
    AND NOT EXISTS (SELECT 1 FROM private.call_sessions s
                    WHERE s.request_id = r.id AND s.status NOT IN ('settled', 'failed'))
    AND NOT EXISTS (
      SELECT 1 FROM public.reports rp
      WHERE rp.status = 'pending'
        AND ((rp.reporter_id = r.caller_id AND rp.reported_user_id = r.callee_id)
          OR (rp.reporter_id = r.callee_id AND rp.reported_user_id = r.caller_id)));
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;
  DELETE FROM private.call_plans cp
  WHERE cp.created_at < v_cutoff AND cp.status NOT IN ('proposed', 'accepted');
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;
  RETURN v_total;
END;
$function$;

-- Staff: one member's calls (times, lengths, results; never audio).
CREATE FUNCTION public.admin_member_call_history(p_user uuid, p_limit integer DEFAULT 100)
RETURNS TABLE (
  request_id uuid, created_at timestamptz, direction text, other_user_id uuid,
  status text, reason text, connected_seconds integer, charged_minutes integer,
  hidden_by_member boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator', 'support']) THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT r.id, r.created_at,
         CASE WHEN r.caller_id = p_user THEN 'outgoing' ELSE 'incoming' END,
         CASE WHEN r.caller_id = p_user THEN r.callee_id ELSE r.caller_id END,
         r.status, r.reason, s.connected_seconds,
         CASE WHEN r.caller_id = p_user THEN s.charged_minutes END,
         CASE WHEN r.caller_id = p_user THEN r.hidden_by_caller_at IS NOT NULL
              ELSE r.hidden_by_callee_at IS NOT NULL END
  FROM private.call_requests r
  LEFT JOIN private.call_sessions s ON s.request_id = r.id
  WHERE r.caller_id = p_user OR r.callee_id = p_user
  ORDER BY r.created_at DESC
  LIMIT least(greatest(coalesce(p_limit, 100), 1), 500);
END;
$function$;

-- Staff: the calls behind a report (both directions, last 90 days).
CREATE FUNCTION public.admin_report_call_context(p_report_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_report public.reports%ROWTYPE;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator']) THEN
    RAISE EXCEPTION 'Moderator authorization required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_report FROM public.reports WHERE id = p_report_id;
  IF NOT FOUND THEN RETURN NULL; END IF;
  RETURN jsonb_build_object(
    'reported_called_reporter', (
      SELECT count(*) FROM private.call_requests r
      WHERE r.caller_id = v_report.reported_user_id AND r.callee_id = v_report.reporter_id
        AND r.created_at > now() - interval '90 days'),
    'reported_unanswered_24h', (
      SELECT count(*) FROM private.call_requests r
      WHERE r.caller_id = v_report.reported_user_id AND r.callee_id = v_report.reporter_id
        AND r.status IN ('declined', 'cancelled', 'missed', 'unavailable')
        AND r.created_at > v_report.created_at - interval '24 hours'
        AND r.created_at <= v_report.created_at),
    'calls', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'created_at', r.created_at,
        'from', CASE WHEN r.caller_id = v_report.reporter_id THEN 'reporter' ELSE 'reported' END,
        'status', r.status,
        'reason', r.reason,
        'connected_seconds', s.connected_seconds
      ) ORDER BY r.created_at DESC)
      FROM private.call_requests r
      LEFT JOIN private.call_sessions s ON s.request_id = r.id
      WHERE ((r.caller_id = v_report.reporter_id AND r.callee_id = v_report.reported_user_id)
          OR (r.caller_id = v_report.reported_user_id AND r.callee_id = v_report.reporter_id))
        AND r.created_at > now() - interval '90 days'
    ), '[]'::jsonb)
  );
END;
$function$;

-- Staff: a support correction of a member's pack minutes, with a reason,
-- in the ledger and the admin audit log.
CREATE FUNCTION public.admin_adjust_call_minutes(p_user uuid, p_pack_minutes integer, p_reason text)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_balance integer;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'support']) THEN
    RAISE EXCEPTION 'Support authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_pack_minutes IS NULL OR p_pack_minutes = 0 OR abs(p_pack_minutes) > 1000 THEN
    RAISE EXCEPTION 'invalid_minutes' USING ERRCODE = '22023';
  END IF;
  IF nullif(trim(coalesce(p_reason, '')), '') IS NULL OR length(trim(p_reason)) < 5 THEN
    RAISE EXCEPTION 'reason_required' USING ERRCODE = '22023';
  END IF;
  PERFORM 1 FROM private.call_wallet_state(p_user, true);
  UPDATE private.call_wallets SET pack_minutes = pack_minutes + p_pack_minutes, updated_at = now()
  WHERE user_id = p_user RETURNING pack_minutes INTO v_balance;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'member_not_found' USING ERRCODE = 'P0002';
  END IF;
  INSERT INTO private.call_ledger(user_id, kind, pack_minutes_delta, note)
  VALUES (p_user, 'admin_adjust', p_pack_minutes, left(trim(p_reason), 500));
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (auth.uid(), public.current_admin_role(), 'voice_call_minutes_adjusted',
          jsonb_build_object('user_id', p_user, 'pack_minutes', p_pack_minutes,
                             'balance', v_balance, 'reason', left(trim(p_reason), 500)));
  RETURN v_balance;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 7. Chat inbox: the latest call in each chat (spec 12.3)
-- ---------------------------------------------------------------------------

-- Same function as before (306/313) plus last_call_at / last_call_outcome.
-- Extra result columns need a new definition; old app versions read
-- columns by name and ignore the new ones.
DROP FUNCTION public.get_chat_inbox(integer, timestamp with time zone);
CREATE FUNCTION public.get_chat_inbox(p_limit integer DEFAULT 50, p_before timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS TABLE(match_id uuid, other_user_id uuid, other_first_name text, other_last_initial text, match_status text, closure_reason text, match_created_at timestamp with time zone, last_message_id uuid, last_message_content text, last_message_sender_id uuid, last_message_created_at timestamp with time zone, last_message_read_at timestamp with time zone, unread_count integer, closed_by uuid, content_locked boolean, member_unavailable boolean, last_call_at timestamp with time zone, last_call_outcome text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_gender text;
  v_suspended_until timestamptz;
  v_content_locked boolean;
BEGIN
  PERFORM private.assert_active_member(v_me, false);
  SELECT u.gender, u.messaging_suspended_until
  INTO v_gender, v_suspended_until
  FROM public.users u
  WHERE u.id = v_me;

  v_content_locked :=
    (v_suspended_until IS NOT NULL AND v_suspended_until > now())
    OR (v_gender IS DISTINCT FROM 'female' AND NOT public.has_active_premium(v_me));

  RETURN QUERY
  WITH visible_matches AS (
    SELECT m.*,
      CASE WHEN m.user_a = v_me THEN m.user_b ELSE m.user_a END AS other_id
    FROM public.matches m
    WHERE (m.user_a = v_me AND m.hidden_by_a_at IS NULL)
       OR (m.user_b = v_me AND m.hidden_by_b_at IS NULL)
  ),
  inbox AS (
    SELECT
      m.id AS match_id,
      m.other_id,
      m.status::text AS match_status,
      m.closure_reason,
      m.closed_by,
      m.created_at AS match_created_at,
      lm.id AS last_message_id,
      lm.content AS last_message_content,
      lm.sender_id AS last_message_sender_id,
      lm.created_at AS last_message_created_at,
      lm.read_at AS last_message_read_at,
      coalesce(uc.unread_count, 0)::integer AS unread_count,
      coalesce(lm.created_at, m.created_at) AS sort_at,
      NOT (
        ou.id IS NOT NULL
        AND ou.deleted_at IS NULL
        AND coalesce(ou.is_banned, false) = false
        AND coalesce(op.visibility, 'deactivated') NOT IN ('suspended', 'deactivated')
      ) AS member_unavailable,
      op.first_name,
      op.last_name,
      lc.created_at AS last_call_at,
      lc.outcome AS last_call_outcome
    FROM visible_matches m
    LEFT JOIN public.users ou ON ou.id = m.other_id
    LEFT JOIN public.profiles op ON op.user_id = m.other_id
    LEFT JOIN LATERAL (
      SELECT msg.id, msg.content, msg.sender_id, msg.created_at, msg.read_at
      FROM public.messages msg
      WHERE msg.match_id = m.id
      ORDER BY msg.created_at DESC, msg.id DESC
      LIMIT 1
    ) lm ON true
    LEFT JOIN LATERAL (
      SELECT count(*)::integer AS unread_count
      FROM public.messages msg
      WHERE msg.match_id = m.id
        AND msg.receiver_id = v_me
        AND msg.read_at IS NULL
    ) uc ON true
    -- 324: the latest call in this chat as this member sees it (never the
    -- calls they blocked). Shown in the preview when newer than the last
    -- message, also for a locked chat (call metadata, spec 12.3).
    LEFT JOIN LATERAL (
      SELECT r.created_at,
             private.call_outcome_for(v_me, r.caller_id, r.status,
                                      cs.connected_seconds, cs.status) AS outcome
      FROM private.call_requests r
      LEFT JOIN private.call_sessions cs ON cs.request_id = r.id
      WHERE r.match_id = m.id
        AND (r.caller_id = v_me
             OR (r.callee_id = v_me
                 AND NOT (r.status = 'unavailable' AND r.reason = 'calls_blocked')))
      ORDER BY r.created_at DESC
      LIMIT 1
    ) lc ON true
  )
  SELECT
    inbox.match_id,
    CASE WHEN inbox.member_unavailable THEN NULL ELSE inbox.other_id END,
    CASE WHEN inbox.member_unavailable THEN 'Silarah member'
      ELSE coalesce(nullif(inbox.first_name, ''), 'Member') END,
    CASE WHEN inbox.member_unavailable THEN ''
      WHEN inbox.match_status = 'active'
        THEN coalesce(nullif(inbox.last_name, ''), '')
      ELSE left(coalesce(inbox.last_name, ''), 1) END,
    inbox.match_status,
    CASE WHEN inbox.member_unavailable OR v_content_locked THEN NULL ELSE inbox.closure_reason END,
    inbox.match_created_at,
    inbox.last_message_id,
    CASE WHEN v_content_locked THEN NULL::text ELSE inbox.last_message_content END,
    inbox.last_message_sender_id,
    inbox.last_message_created_at,
    inbox.last_message_read_at,
    inbox.unread_count,
    CASE WHEN inbox.member_unavailable THEN NULL ELSE inbox.closed_by END,
    v_content_locked,
    inbox.member_unavailable,
    CASE WHEN inbox.member_unavailable THEN NULL ELSE inbox.last_call_at END,
    CASE WHEN inbox.member_unavailable THEN NULL ELSE inbox.last_call_outcome END
  FROM inbox
  WHERE p_before IS NULL OR inbox.sort_at < p_before
  ORDER BY inbox.sort_at DESC, inbox.match_id DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
END;
$function$;

REVOKE ALL ON FUNCTION public.get_chat_inbox(integer, timestamp with time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_chat_inbox(integer, timestamp with time zone) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 8. Grants
-- ---------------------------------------------------------------------------

DO $$
DECLARE f text;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure::text FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE (n.nspname = 'private' AND p.proname LIKE 'call\_%')
       OR (n.nspname = 'public' AND (p.proname LIKE 'call\_service\_%'
           OR p.proname IN ('set_my_call_ring_capability', 'get_my_call_log',
             'get_my_call_overview', 'get_my_call_plans', 'mark_calls_seen',
             'hide_my_calls', 'propose_call_plan', 'respond_call_plan',
             'cancel_call_plan', 'get_guardian_match_call_plans', 'get_calling_rules',
             'admin_member_call_history', 'admin_report_call_context',
             'admin_adjust_call_minutes')))
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', f);
  END LOOP;
  FOR f IN
    SELECT p.oid::regprocedure::text FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname LIKE 'call\_service\_%'
  LOOP
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
  END LOOP;
END $$;

GRANT EXECUTE ON FUNCTION public.set_my_call_ring_capability(text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_call_log(text, text, timestamptz, uuid, integer, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_call_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_call_plans() TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_calls_seen() TO authenticated;
GRANT EXECUTE ON FUNCTION public.hide_my_calls(uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.propose_call_plan(uuid, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_call_plan(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_call_plan(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_guardian_match_call_plans(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_calling_rules() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_member_call_history(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_report_call_context(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_adjust_call_minutes(uuid, integer, text) TO authenticated;
-- 323 grants that the redefinitions above keep.
GRANT EXECUTE ON FUNCTION public.get_my_call_wallet() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_call_preferences() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_my_call_mode(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_chat_call_prefs(uuid, boolean, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_chat_call_state(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_guardian_match_calls(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_calls_enabled(boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_call_overview() TO authenticated;

-- Hourly cap refresh and daily retention purge (cheap single statements).
SELECT private.call_refresh_month_cap();
SELECT cron.schedule('voice_call_cap_hourly', '17 * * * *',
  'SELECT private.call_refresh_month_cap();');
SELECT cron.schedule('voice_call_retention_daily', '41 3 * * *',
  'SELECT private.call_purge_old_records();');
