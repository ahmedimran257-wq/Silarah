-- Voice calling (docs/voice_calling_spec.md, approved 22 Nov 2026).
--
-- Members call each other inside Silarah through Stream Video (call type
-- silarah_voice, audio only), so nobody needs to share a phone number.
-- Our server owns everything that costs money or touches safety:
--
--   * ringing goes through our own FCM push (edge function `calls`), and the
--     Stream call is created only when the callee answers;
--   * the caller's minutes are HELD at answer (min(balance, 60)) and settled
--     afterwards from Stream's own record of who was connected when;
--   * Stream's max_duration_seconds (= hold + 30 s) is the hard stop, even if
--     this server is down;
--   * any block, report, unmatch, ban, pause, deletion, lost Premium or the
--     global switch ends a live call (triggers below + call-worker);
--   * calling ships OFF: private.call_settings.calls_enabled = false.
--
-- Every table is private. Members reach calling only through the RPCs at the
-- end of this file; the money-moving RPCs are service_role only and are
-- called by the `calls`, `stream-webhook`, `call-worker` and
-- `revenuecat-webhook` edge functions after they authenticate the request.

-- ---------------------------------------------------------------------------
-- 1. Settings (one row) and pack products
-- ---------------------------------------------------------------------------

CREATE TABLE private.call_settings (
  id boolean PRIMARY KEY DEFAULT true CHECK (id),
  calls_enabled boolean NOT NULL DEFAULT false,
  -- Below Stream's free $100/month (~166,000 two-person minutes) until a card
  -- is attached and revenue covers it.
  monthly_cap_minutes integer NOT NULL DEFAULT 100000
    CHECK (monthly_cap_minutes >= 0),
  included_minutes integer NOT NULL DEFAULT 30 CHECK (included_minutes >= 0),
  included_period_days integer NOT NULL DEFAULT 30
    CHECK (included_period_days BETWEEN 1 AND 366),
  max_hold_minutes integer NOT NULL DEFAULT 60
    CHECK (max_hold_minutes BETWEEN 1 AND 240),
  ring_timeout_seconds integer NOT NULL DEFAULT 30
    CHECK (ring_timeout_seconds BETWEEN 10 AND 120),
  join_timeout_seconds integer NOT NULL DEFAULT 20
    CHECK (join_timeout_seconds BETWEEN 5 AND 120),
  connect_allowance_seconds integer NOT NULL DEFAULT 30
    CHECK (connect_allowance_seconds BETWEEN 0 AND 120),
  unanswered_call_limit integer NOT NULL DEFAULT 3
    CHECK (unanswered_call_limit BETWEEN 1 AND 50),
  max_pack_refunds integer NOT NULL DEFAULT 2
    CHECK (max_pack_refunds BETWEEN 0 AND 50),
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid
);
INSERT INTO private.call_settings(id) VALUES (true) ON CONFLICT DO NOTHING;

CREATE TABLE private.call_settings_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  changed_at timestamptz NOT NULL DEFAULT now(),
  changed_by uuid,
  old_row jsonb NOT NULL,
  new_row jsonb NOT NULL
);

CREATE TABLE private.call_pack_products (
  product_id text PRIMARY KEY CHECK (product_id ~ '^silarah_calls_[0-9]+$'),
  minutes integer NOT NULL CHECK (minutes > 0),
  sort_order integer NOT NULL,
  active boolean NOT NULL DEFAULT true
);
INSERT INTO private.call_pack_products(product_id, minutes, sort_order) VALUES
  ('silarah_calls_20', 20, 1),
  ('silarah_calls_60', 60, 2),
  ('silarah_calls_150', 150, 3),
  ('silarah_calls_350', 350, 4)
ON CONFLICT (product_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Minutes: wallet, included periods, ledger, monthly usage
-- ---------------------------------------------------------------------------

CREATE TABLE private.call_wallets (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  -- Pack minutes never expire. A refund after use can take this negative,
  -- which blocks calling until the member tops up.
  pack_minutes integer NOT NULL DEFAULT 0,
  -- Start of the member's current Premium run; included periods are
  -- consecutive 30-day windows from here. Cleared when Premium is seen off.
  included_anchor_at timestamptz,
  pack_refund_count integer NOT NULL DEFAULT 0 CHECK (pack_refund_count >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE private.call_included_periods (
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  period_start timestamptz NOT NULL,
  period_end timestamptz NOT NULL,
  granted_minutes integer NOT NULL CHECK (granted_minutes >= 0),
  used_minutes integer NOT NULL DEFAULT 0 CHECK (used_minutes >= 0),
  forfeited_at timestamptz,
  PRIMARY KEY (user_id, period_start),
  CHECK (period_end > period_start)
);

CREATE TABLE private.call_ledger (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN (
    'pack_purchase', 'pack_refund', 'included_forfeit', 'hold', 'release',
    'charge', 'admin_adjust'
  )),
  pack_minutes_delta integer NOT NULL DEFAULT 0,
  included_minutes_delta integer NOT NULL DEFAULT 0,
  request_id uuid,
  product_id text,
  transaction_id text,
  provider_event_id text,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_call_ledger_user ON private.call_ledger(user_id, created_at DESC);
-- One credit and one refund per store transaction; one row per RevenueCat
-- event. These make pack webhooks idempotent.
CREATE UNIQUE INDEX uq_call_ledger_pack_purchase
  ON private.call_ledger(transaction_id) WHERE kind = 'pack_purchase';
CREATE UNIQUE INDEX uq_call_ledger_pack_refund
  ON private.call_ledger(transaction_id) WHERE kind = 'pack_refund';
CREATE UNIQUE INDEX uq_call_ledger_provider_event
  ON private.call_ledger(provider_event_id) WHERE provider_event_id IS NOT NULL;

CREATE TABLE private.call_usage_months (
  month_start date PRIMARY KEY,
  charged_minutes integer NOT NULL DEFAULT 0 CHECK (charged_minutes >= 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 3. Calls: requests (ringing), sessions (answered), holds, Stream events
-- ---------------------------------------------------------------------------

CREATE TABLE private.call_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id uuid NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  caller_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  callee_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status text NOT NULL CHECK (status IN (
    'ringing', 'accepted', 'declined', 'cancelled', 'missed', 'unavailable',
    'failed'
  )),
  reason text,
  decline_token_hash text,
  created_at timestamptz NOT NULL DEFAULT now(),
  ring_expires_at timestamptz,
  answered_at timestamptz,
  closed_at timestamptz,
  answered_device text,
  CHECK (caller_id <> callee_id)
);
CREATE INDEX idx_call_requests_caller ON private.call_requests(caller_id, created_at DESC);
CREATE INDEX idx_call_requests_callee ON private.call_requests(callee_id, created_at DESC);
CREATE INDEX idx_call_requests_match ON private.call_requests(match_id, created_at DESC);
CREATE INDEX idx_call_requests_ringing ON private.call_requests(ring_expires_at)
  WHERE status = 'ringing';
-- A member rings at most one person at a time.
CREATE UNIQUE INDEX uq_call_requests_one_ringing_per_caller
  ON private.call_requests(caller_id) WHERE status = 'ringing';

CREATE TABLE private.call_sessions (
  request_id uuid PRIMARY KEY REFERENCES private.call_requests(id) ON DELETE CASCADE,
  stream_call_id text NOT NULL UNIQUE CHECK (stream_call_id ~ '^[a-z0-9]{32}$'),
  match_id uuid NOT NULL,
  caller_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  callee_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status text NOT NULL CHECK (status IN (
    'creating', 'active', 'ending', 'ended', 'settled', 'failed'
  )),
  hold_minutes integer NOT NULL CHECK (hold_minutes >= 0),
  max_duration_seconds integer NOT NULL CHECK (max_duration_seconds > 0),
  accepted_at timestamptz NOT NULL DEFAULT now(),
  stream_created_at timestamptz,
  caller_joined_at timestamptz,
  callee_joined_at timestamptz,
  both_joined_at timestamptz,
  end_requested_at timestamptz,
  end_reason text,
  ended_at timestamptz,
  stream_session_id text,
  connected_seconds integer,
  charged_minutes integer,
  charged_included_minutes integer,
  charged_pack_minutes integer,
  settled_at timestamptz,
  settle_source text,
  last_error text
);
CREATE INDEX idx_call_sessions_open_caller ON private.call_sessions(caller_id)
  WHERE status IN ('creating', 'active', 'ending', 'ended');
CREATE INDEX idx_call_sessions_open_callee ON private.call_sessions(callee_id)
  WHERE status IN ('creating', 'active', 'ending', 'ended');
CREATE INDEX idx_call_sessions_open ON private.call_sessions(status, accepted_at)
  WHERE status IN ('creating', 'active', 'ending', 'ended');

CREATE TABLE private.call_holds (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  request_id uuid NOT NULL REFERENCES private.call_sessions(request_id) ON DELETE CASCADE,
  included_minutes integer NOT NULL CHECK (included_minutes >= 0),
  pack_minutes integer NOT NULL CHECK (pack_minutes >= 0),
  period_start timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_call_holds_request ON private.call_holds(request_id, id);

CREATE TABLE private.stream_webhook_deliveries (
  webhook_id text PRIMARY KEY,
  event_type text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_stream_webhook_deliveries_received
  ON private.stream_webhook_deliveries(received_at);

CREATE TABLE private.call_participant_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  request_id uuid NOT NULL REFERENCES private.call_sessions(request_id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  user_session_id text,
  stream_session_id text,
  kind text NOT NULL CHECK (kind IN ('joined', 'left')),
  occurred_at timestamptz NOT NULL,
  duration_seconds integer,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_call_participant_events_request
  ON private.call_participant_events(request_id, occurred_at);

-- ---------------------------------------------------------------------------
-- 4. Member controls
-- ---------------------------------------------------------------------------

CREATE TABLE private.call_member_prefs (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  call_mode text NOT NULL DEFAULT 'ring' CHECK (call_mode IN ('ring', 'silent', 'off')),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE private.call_pair_prefs (
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  other_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  muted boolean NOT NULL DEFAULT false,
  calls_blocked boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, other_user_id),
  CHECK (user_id <> other_user_id)
);

-- ---------------------------------------------------------------------------
-- 5. Work queue for the call-worker edge function
-- ---------------------------------------------------------------------------

CREATE TABLE private.call_jobs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  kind text NOT NULL CHECK (kind IN (
    'end_stream_call', 'join_check', 'settle', 'cancel_ring',
    'delete_stream_user'
  )),
  request_id uuid,
  user_id uuid,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'done', 'dead')),
  attempts integer NOT NULL DEFAULT 0,
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  lease_token uuid,
  leased_at timestamptz,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  done_at timestamptz,
  CHECK (request_id IS NOT NULL OR user_id IS NOT NULL)
);
CREATE UNIQUE INDEX uq_call_jobs_open_request
  ON private.call_jobs(kind, request_id)
  WHERE status IN ('pending', 'processing') AND request_id IS NOT NULL;
CREATE UNIQUE INDEX uq_call_jobs_open_user
  ON private.call_jobs(kind, user_id)
  WHERE status IN ('pending', 'processing') AND request_id IS NULL;
CREATE INDEX idx_call_jobs_due ON private.call_jobs(next_attempt_at)
  WHERE status IN ('pending', 'processing');

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'call_settings', 'call_settings_audit', 'call_pack_products',
    'call_wallets', 'call_included_periods', 'call_ledger',
    'call_usage_months', 'call_requests', 'call_sessions', 'call_holds',
    'stream_webhook_deliveries', 'call_participant_events',
    'call_member_prefs', 'call_pair_prefs', 'call_jobs'
  ] LOOP
    EXECUTE format('ALTER TABLE private.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON private.%I FROM PUBLIC, anon, authenticated', t);
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 6. Helpers
-- ---------------------------------------------------------------------------

CREATE FUNCTION private.call_settings_row()
RETURNS private.call_settings
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT s FROM private.call_settings s WHERE s.id;
$function$;

CREATE FUNCTION private.call_is_female(p_user uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  -- Same rule as can_open_chat: anyone not recorded as female is treated as
  -- the man on the call and must hold Premium.
  SELECT coalesce((
    SELECT lower(trim(coalesce(u.gender, ''))) = 'female'
    FROM public.users u WHERE u.id = p_user
  ), false);
$function$;

-- Short name for the other member's screens and the ring push: first name
-- and surname initial only (spec 7).
CREATE FUNCTION private.call_display_name(p_user uuid)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT coalesce((
    SELECT trim(
      coalesce(nullif(trim(p.first_name), ''), 'Silarah member')
      || CASE WHEN nullif(trim(coalesce(p.last_name, '')), '') IS NULL THEN ''
              ELSE ' ' || upper(left(trim(p.last_name), 1)) || '.' END
    )
    FROM public.profiles p WHERE p.user_id = p_user
  ), 'Silarah member');
$function$;

-- NULL when the member can use calling; otherwise why not.
CREATE FUNCTION private.call_member_block_reason(p_user uuid)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT CASE
    WHEN u.id IS NULL OR u.deleted_at IS NOT NULL THEN 'account_deleted'
    WHEN coalesce(u.is_banned, false) THEN 'account_banned'
    WHEN u.messaging_suspended_until IS NOT NULL
      AND u.messaging_suspended_until > now() THEN 'account_suspended'
    WHEN coalesce(p.visibility, 'deactivated') IN ('suspended', 'deactivated')
      THEN 'account_restricted'
    WHEN p.visibility = 'paused' THEN 'profile_paused'
    ELSE NULL
  END
  FROM (SELECT p_user AS id) target
  LEFT JOIN public.users u ON u.id = target.id
  LEFT JOIN public.profiles p ON p.user_id = target.id;
$function$;

-- NULL when the match allows a call between p_me and the other member.
CREATE FUNCTION private.call_match_block_reason(p_match_id uuid, p_me uuid)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_match public.matches%ROWTYPE;
  v_other uuid;
BEGIN
  SELECT * INTO v_match FROM public.matches m
  WHERE m.id = p_match_id AND (m.user_a = p_me OR m.user_b = p_me);
  IF NOT FOUND THEN RETURN 'not_found'; END IF;
  IF (v_match.user_a = p_me AND v_match.hidden_by_a_at IS NOT NULL)
    OR (v_match.user_b = p_me AND v_match.hidden_by_b_at IS NOT NULL) THEN
    RETURN 'not_found';
  END IF;
  IF coalesce(v_match.status, 'active') <> 'active' THEN RETURN 'match_closed'; END IF;
  v_other := CASE WHEN v_match.user_a = p_me THEN v_match.user_b ELSE v_match.user_a END;
  IF EXISTS (
    SELECT 1 FROM public.blocks b
    WHERE (b.blocker_id = p_me AND b.blocked_id = v_other)
       OR (b.blocker_id = v_other AND b.blocked_id = p_me)
  ) THEN
    RETURN 'blocked';
  END IF;
  IF NOT private.guardian_approvals_complete(p_match_id) THEN
    RETURN 'guardian_approval_required';
  END IF;
  RETURN NULL;
END;
$function$;

CREATE FUNCTION private.call_match_other(p_match_id uuid, p_me uuid)
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT CASE WHEN m.user_a = p_me THEN m.user_b ELSE m.user_a END
  FROM public.matches m
  WHERE m.id = p_match_id AND (m.user_a = p_me OR m.user_b = p_me);
$function$;

-- The caller always holds Premium, and so does the man on the call.
CREATE FUNCTION private.call_premium_rule_ok(p_caller uuid, p_callee uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT public.has_active_premium(p_caller)
    AND (private.call_is_female(p_callee) OR public.has_active_premium(p_callee));
$function$;

-- Same quiet-hours rule queue_notification uses (default 23:00-08:00 in the
-- member's own time zone).
CREATE FUNCTION private.call_in_quiet_hours(p_user uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_tz text;
  v_start time;
  v_end time;
  v_local time;
BEGIN
  SELECT
    CASE WHEN EXISTS (SELECT 1 FROM private.timezone_names tz WHERE tz.name = u.timezone)
      THEN u.timezone ELSE 'UTC' END,
    coalesce(np.quiet_start, time '23:00'),
    coalesce(np.quiet_end, time '08:00')
  INTO v_tz, v_start, v_end
  FROM public.users u
  LEFT JOIN public.notification_prefs np ON np.user_id = u.id
  WHERE u.id = p_user;
  IF v_tz IS NULL THEN RETURN false; END IF;
  v_local := (now() AT TIME ZONE v_tz)::time;
  RETURN CASE
    WHEN v_start = v_end THEN false
    WHEN v_start < v_end THEN v_local >= v_start AND v_local < v_end
    ELSE v_local >= v_start OR v_local < v_end
  END;
END;
$function$;

-- When the member's current Premium run began: the earliest start among the
-- sources that are active right now (store plan, referral grant, test grant).
CREATE FUNCTION private.call_premium_started_at(p_user uuid)
RETURNS timestamptz
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT least(now(), coalesce(least(
    (
      SELECT max(to_timestamp(se.event_timestamp_ms / 1000.0))
      FROM public.subscription_events se
      JOIN public.users u ON u.id = se.user_id
      WHERE se.user_id = p_user
        AND se.event_type = 'INITIAL_PURCHASE'
        AND u.subscription_status IN ('active', 'grace')
        AND (u.subscription_expires_at IS NULL OR u.subscription_expires_at > now())
    ),
    (
      SELECT min(g.starts_at) FROM public.promotional_premium_grants g
      WHERE g.user_id = p_user AND g.starts_at <= now() AND g.expires_at > now()
    ),
    (
      SELECT min(t.starts_at) FROM private.test_premium_grants t
      WHERE t.user_id = p_user AND t.revoked_at IS NULL
        AND t.starts_at <= now() AND t.expires_at > now()
    )
  ), now()));
$function$;

-- Balance for p_user. Creates the wallet and the current included period as
-- needed, so it is VOLATILE. p_lock takes the wallet row lock.
CREATE FUNCTION private.call_wallet_state(p_user uuid, p_lock boolean DEFAULT false)
RETURNS TABLE (
  premium boolean,
  included_remaining integer,
  included_granted integer,
  period_start timestamptz,
  period_end timestamptz,
  pack_minutes integer,
  available_minutes integer,
  pack_refund_count integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
#variable_conflict use_column
DECLARE
  v_settings private.call_settings := private.call_settings_row();
  v_wallet private.call_wallets%ROWTYPE;
  v_premium boolean := public.has_active_premium(p_user);
  v_period private.call_included_periods%ROWTYPE;
  v_start timestamptz;
  v_len interval := make_interval(days => v_settings.included_period_days);
  v_k bigint;
  v_included integer := 0;
BEGIN
  INSERT INTO private.call_wallets(user_id) VALUES (p_user)
  ON CONFLICT (user_id) DO NOTHING;
  IF p_lock THEN
    SELECT * INTO v_wallet FROM private.call_wallets w WHERE w.user_id = p_user FOR UPDATE;
  ELSE
    SELECT * INTO v_wallet FROM private.call_wallets w WHERE w.user_id = p_user;
  END IF;

  IF NOT v_premium THEN
    IF v_wallet.included_anchor_at IS NOT NULL THEN
      UPDATE private.call_wallets SET included_anchor_at = NULL, updated_at = now()
      WHERE user_id = p_user;
    END IF;
  ELSE
    IF v_wallet.included_anchor_at IS NULL THEN
      v_wallet.included_anchor_at := private.call_premium_started_at(p_user);
      UPDATE private.call_wallets
      SET included_anchor_at = v_wallet.included_anchor_at, updated_at = now()
      WHERE user_id = p_user;
    END IF;
    v_k := floor(extract(epoch FROM (now() - v_wallet.included_anchor_at))
                 / extract(epoch FROM v_len))::bigint;
    v_start := v_wallet.included_anchor_at + v_len * v_k;
    INSERT INTO private.call_included_periods(
      user_id, period_start, period_end, granted_minutes
    ) VALUES (p_user, v_start, v_start + v_len, v_settings.included_minutes)
    ON CONFLICT (user_id, period_start) DO NOTHING;
    SELECT * INTO v_period FROM private.call_included_periods cp
    WHERE cp.user_id = p_user AND cp.period_start = v_start;
    v_included := CASE WHEN v_period.forfeited_at IS NOT NULL THEN 0
      ELSE greatest(v_period.granted_minutes - v_period.used_minutes, 0) END;
  END IF;

  RETURN QUERY SELECT
    v_premium,
    v_included,
    coalesce(v_period.granted_minutes, 0),
    v_period.period_start,
    v_period.period_end,
    v_wallet.pack_minutes,
    CASE WHEN NOT v_premium OR v_wallet.pack_minutes < 0 THEN 0
      ELSE v_included + v_wallet.pack_minutes END,
    v_wallet.pack_refund_count;
END;
$function$;

CREATE FUNCTION private.call_month_start()
RETURNS date
LANGUAGE sql STABLE SET search_path TO ''
AS $function$
  SELECT date_trunc('month', now() AT TIME ZONE 'UTC')::date;
$function$;

-- Minutes this month already charged plus minutes held by open calls.
CREATE FUNCTION private.call_month_committed_minutes()
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT coalesce((
    SELECT um.charged_minutes FROM private.call_usage_months um
    WHERE um.month_start = private.call_month_start()
  ), 0) + coalesce((
    SELECT sum(s.hold_minutes)::integer FROM private.call_sessions s
    WHERE s.status IN ('creating', 'active', 'ending', 'ended')
  ), 0);
$function$;

-- Is p_user in a call or a ringing call right now?
CREATE FUNCTION private.call_user_busy(p_user uuid, p_except uuid DEFAULT NULL)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM private.call_requests r
    WHERE r.status = 'ringing' AND r.ring_expires_at > now()
      AND (r.caller_id = p_user OR r.callee_id = p_user)
      AND r.id IS DISTINCT FROM p_except
  ) OR EXISTS (
    SELECT 1 FROM private.call_sessions s
    WHERE s.status IN ('creating', 'active', 'ending')
      AND (s.caller_id = p_user OR s.callee_id = p_user)
      AND s.request_id IS DISTINCT FROM p_except
  );
$function$;

-- 3 unanswered calls to the same person in 24 h: no more calls to them until
-- the caller's next local midnight. An answered call between them resets it.
CREATE FUNCTION private.call_unanswered_block_until(p_caller uuid, p_callee uuid)
RETURNS timestamptz
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_limit integer := (private.call_settings_row()).unanswered_call_limit;
  v_last_answered timestamptz;
  v_count integer;
  v_latest timestamptz;
  v_tz text := private.member_timezone(p_caller);
  v_until timestamptz;
BEGIN
  SELECT max(r.answered_at) INTO v_last_answered
  FROM private.call_requests r
  WHERE r.answered_at IS NOT NULL
    AND ((r.caller_id = p_caller AND r.callee_id = p_callee)
      OR (r.caller_id = p_callee AND r.callee_id = p_caller));

  SELECT count(*), max(r.created_at) INTO v_count, v_latest
  FROM private.call_requests r
  WHERE r.caller_id = p_caller AND r.callee_id = p_callee
    AND r.status IN ('declined', 'cancelled', 'missed', 'unavailable')
    AND r.created_at > now() - interval '24 hours'
    AND (v_last_answered IS NULL OR r.created_at > v_last_answered);

  IF v_count < v_limit THEN RETURN NULL; END IF;
  v_until := (date_trunc('day', v_latest AT TIME ZONE v_tz) + interval '1 day')
             AT TIME ZONE v_tz;
  RETURN CASE WHEN v_until > now() THEN v_until ELSE NULL END;
END;
$function$;

CREATE FUNCTION private.call_queue_missed_note(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_request private.call_requests%ROWTYPE;
BEGIN
  SELECT * INTO v_request FROM private.call_requests WHERE id = p_request_id;
  IF NOT FOUND THEN RETURN; END IF;
  BEGIN
    PERFORM public.queue_notification(
      v_request.callee_id,
      'missed_call',
      'Missed call',
      coalesce((SELECT nullif(trim(p.first_name), '') FROM public.profiles p
                WHERE p.user_id = v_request.caller_id), 'A Silarah member')
        || ' tried to call you.',
      '/chat/' || v_request.match_id::text
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Missed-call note for % not queued: %', p_request_id, SQLERRM;
  END;
END;
$function$;

CREATE FUNCTION private.call_enqueue_job(
  p_kind text,
  p_request_id uuid,
  p_user_id uuid DEFAULT NULL,
  p_delay interval DEFAULT interval '0 seconds'
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF p_request_id IS NOT NULL THEN
    INSERT INTO private.call_jobs(kind, request_id, user_id, next_attempt_at)
    VALUES (p_kind, p_request_id, p_user_id, now() + p_delay)
    ON CONFLICT (kind, request_id)
      WHERE status IN ('pending', 'processing') AND request_id IS NOT NULL
    DO NOTHING;
  ELSE
    INSERT INTO private.call_jobs(kind, user_id, next_attempt_at)
    VALUES (p_kind, p_user_id, now() + p_delay)
    ON CONFLICT (kind, user_id)
      WHERE status IN ('pending', 'processing') AND request_id IS NULL
    DO NOTHING;
  END IF;
END;
$function$;

CREATE FUNCTION private.call_wake_worker()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  PERFORM private.invoke_edge_worker('call-worker', 'call_worker');
EXCEPTION WHEN OTHERS THEN
  -- The 10-second watchdog retries; never fail the caller's transaction.
  RAISE WARNING 'call-worker wake-up deferred: %', SQLERRM;
END;
$function$;

-- Ends one call: a ringing request is closed and its ring cancelled; an
-- answered call is marked ending and queued for Stream mark_ended.
-- Returns true when something changed.
CREATE FUNCTION private.call_end_request(p_request_id uuid, p_reason text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_request private.call_requests%ROWTYPE;
  v_session private.call_sessions%ROWTYPE;
BEGIN
  SELECT * INTO v_request FROM private.call_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;

  IF v_request.status = 'ringing' THEN
    UPDATE private.call_requests
    SET status = 'cancelled', reason = p_reason, closed_at = now()
    WHERE id = p_request_id;
    PERFORM private.call_enqueue_job('cancel_ring', p_request_id, v_request.callee_id);
    RETURN true;
  END IF;

  SELECT * INTO v_session FROM private.call_sessions
  WHERE request_id = p_request_id FOR UPDATE;
  IF FOUND AND v_session.status IN ('creating', 'active') THEN
    UPDATE private.call_sessions
    SET status = 'ending',
        end_requested_at = now(),
        end_reason = p_reason
    WHERE request_id = p_request_id;
    PERFORM private.call_enqueue_job('end_stream_call', p_request_id);
    RETURN true;
  END IF;
  RETURN false;
END;
$function$;

-- Ends every open call that involves p_user (and p_other, when given).
CREATE FUNCTION private.call_end_for_users(p_user uuid, p_other uuid, p_reason text)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_id uuid;
  v_count integer := 0;
BEGIN
  FOR v_id IN
    SELECT r.id FROM private.call_requests r
    WHERE r.status = 'ringing'
      AND (r.caller_id = p_user OR r.callee_id = p_user)
      AND (p_other IS NULL OR r.caller_id = p_other OR r.callee_id = p_other)
    UNION
    SELECT s.request_id FROM private.call_sessions s
    WHERE s.status IN ('creating', 'active')
      AND (s.caller_id = p_user OR s.callee_id = p_user)
      AND (p_other IS NULL OR s.caller_id = p_other OR s.callee_id = p_other)
  LOOP
    IF private.call_end_request(v_id, p_reason) THEN v_count := v_count + 1; END IF;
  END LOOP;
  IF v_count > 0 THEN PERFORM private.call_wake_worker(); END IF;
  RETURN v_count;
END;
$function$;

-- Gives back every held minute of a call (no charge).
CREATE FUNCTION private.call_release_holds(p_request_id uuid, p_charge integer, p_note text)
RETURNS TABLE (charged_included integer, charged_pack integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
#variable_conflict use_column
DECLARE
  v_session private.call_sessions%ROWTYPE;
  v_total_included integer;
  v_total_pack integer;
  v_charge integer;
  v_charge_included integer;
  v_charge_pack integer;
  v_refund_included integer;
  v_refund_pack integer;
  v_hold record;
  v_give integer;
BEGIN
  SELECT * INTO v_session FROM private.call_sessions WHERE request_id = p_request_id;
  SELECT coalesce(sum(h.included_minutes), 0)::integer, coalesce(sum(h.pack_minutes), 0)::integer
  INTO v_total_included, v_total_pack
  FROM private.call_holds h WHERE h.request_id = p_request_id;

  v_charge := least(greatest(coalesce(p_charge, 0), 0), v_total_included + v_total_pack);
  -- Included minutes are used before pack minutes.
  v_charge_included := least(v_charge, v_total_included);
  v_charge_pack := v_charge - v_charge_included;
  v_refund_included := v_total_included - v_charge_included;
  v_refund_pack := v_total_pack - v_charge_pack;

  PERFORM 1 FROM private.call_wallets w WHERE w.user_id = v_session.caller_id FOR UPDATE;
  IF v_refund_pack > 0 THEN
    UPDATE private.call_wallets
    SET pack_minutes = pack_minutes + v_refund_pack, updated_at = now()
    WHERE user_id = v_session.caller_id;
  END IF;
  -- Unused included minutes go back to the periods they came from, newest
  -- hold first.
  FOR v_hold IN
    SELECT h.included_minutes, h.period_start FROM private.call_holds h
    WHERE h.request_id = p_request_id AND h.included_minutes > 0
    ORDER BY h.id DESC
  LOOP
    EXIT WHEN v_refund_included <= 0;
    v_give := least(v_refund_included, v_hold.included_minutes);
    UPDATE private.call_included_periods
    SET used_minutes = greatest(used_minutes - v_give, 0)
    WHERE user_id = v_session.caller_id AND period_start = v_hold.period_start;
    v_refund_included := v_refund_included - v_give;
  END LOOP;

  IF v_total_included - v_charge_included > 0 OR v_refund_pack > 0 THEN
    INSERT INTO private.call_ledger(
      user_id, kind, pack_minutes_delta, included_minutes_delta, request_id, note
    ) VALUES (
      v_session.caller_id, 'release', v_refund_pack,
      v_total_included - v_charge_included, p_request_id, p_note
    );
  END IF;
  INSERT INTO private.call_ledger(
    user_id, kind, pack_minutes_delta, included_minutes_delta, request_id, note
  ) VALUES (
    v_session.caller_id, 'charge', 0, 0, p_request_id,
    format('charged %s min (%s included, %s pack)', v_charge, v_charge_included, v_charge_pack)
  );
  RETURN QUERY SELECT v_charge_included, v_charge_pack;
END;
$function$;

-- Places a hold of up to max_hold_minutes on the caller's balance.
CREATE FUNCTION private.call_place_hold(p_request_id uuid, p_caller uuid)
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
  v_cap_room := v_settings.monthly_cap_minutes - private.call_month_committed_minutes();
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

-- ---------------------------------------------------------------------------
-- 7. Service RPCs used by the `calls` edge function (service_role only)
-- ---------------------------------------------------------------------------

-- Closes ringing requests whose time ran out (lazy; the watchdog also does it).
CREATE FUNCTION private.call_expire_ringing(p_user uuid DEFAULT NULL)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_id uuid;
  v_count integer := 0;
BEGIN
  FOR v_id IN
    SELECT r.id FROM private.call_requests r
    WHERE r.status = 'ringing' AND r.ring_expires_at <= now()
      AND (p_user IS NULL OR r.caller_id = p_user OR r.callee_id = p_user)
    FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE private.call_requests
    SET status = 'missed', reason = 'timeout', closed_at = now()
    WHERE id = v_id AND status = 'ringing';
    PERFORM private.call_queue_missed_note(v_id);
    PERFORM private.call_enqueue_job('cancel_ring', v_id,
      (SELECT callee_id FROM private.call_requests WHERE id = v_id));
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$function$;

CREATE FUNCTION public.call_service_request(p_caller uuid, p_match_id uuid)
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

  IF private.call_month_committed_minutes() + 1 > v_settings.monthly_cap_minutes THEN
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
    'caller_name', private.call_display_name(p_caller),
    'decline_token', v_token,
    'ring_expires_at', now() + make_interval(secs => v_settings.ring_timeout_seconds)
  );
END;
$function$;

-- The callee's devices could not be reached at all.
CREATE FUNCTION public.call_service_mark_unreachable(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  UPDATE private.call_requests
  SET status = 'missed', reason = 'no_device', closed_at = now()
  WHERE id = p_request_id AND status = 'ringing';
  IF FOUND THEN PERFORM private.call_queue_missed_note(p_request_id); END IF;
END;
$function$;

CREATE FUNCTION public.call_service_accept(
  p_user uuid, p_request_id uuid, p_device_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_settings private.call_settings := private.call_settings_row();
  v_request private.call_requests%ROWTYPE;
  v_fail text;
  v_hold integer;
  v_stream_id text;
  v_max integer;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_request FROM private.call_requests WHERE id = p_request_id;
  IF NOT FOUND OR v_request.callee_id <> p_user THEN
    RETURN jsonb_build_object('outcome', 'not_found');
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(least(v_request.caller_id, v_request.callee_id)::text, 323));
  PERFORM pg_advisory_xact_lock(hashtextextended(greatest(v_request.caller_id, v_request.callee_id)::text, 323));
  -- First device to answer wins; the rest see "answered".
  SELECT * INTO v_request FROM private.call_requests WHERE id = p_request_id FOR UPDATE;
  IF v_request.status = 'accepted' THEN
    RETURN jsonb_build_object('outcome', 'already_answered');
  END IF;
  IF v_request.status <> 'ringing' THEN
    RETURN jsonb_build_object('outcome', v_request.status);
  END IF;
  IF v_request.ring_expires_at <= now() THEN
    UPDATE private.call_requests SET status = 'missed', reason = 'timeout', closed_at = now()
    WHERE id = p_request_id;
    PERFORM private.call_queue_missed_note(p_request_id);
    RETURN jsonb_build_object('outcome', 'missed');
  END IF;

  v_fail := CASE
    WHEN NOT v_settings.calls_enabled THEN 'calls_disabled'
    WHEN private.call_member_block_reason(v_request.caller_id) IS NOT NULL THEN 'caller_unavailable'
    WHEN private.call_member_block_reason(v_request.callee_id) IS NOT NULL THEN 'account_restricted'
    WHEN private.call_match_block_reason(v_request.match_id, v_request.callee_id) IS NOT NULL THEN 'not_allowed'
    WHEN NOT private.call_premium_rule_ok(v_request.caller_id, v_request.callee_id) THEN 'premium_required'
    WHEN private.call_user_busy(v_request.caller_id, p_request_id) THEN 'caller_busy'
    WHEN private.call_user_busy(v_request.callee_id, p_request_id) THEN 'busy_self'
    ELSE NULL
  END;
  IF v_fail IS NOT NULL THEN
    UPDATE private.call_requests SET status = 'failed', reason = v_fail, closed_at = now()
    WHERE id = p_request_id;
    PERFORM private.call_enqueue_job('cancel_ring', p_request_id, v_request.callee_id);
    RETURN jsonb_build_object('outcome', 'failed', 'reason', v_fail);
  END IF;

  v_stream_id := replace(p_request_id::text, '-', '');
  INSERT INTO private.call_sessions(
    request_id, stream_call_id, match_id, caller_id, callee_id, status,
    hold_minutes, max_duration_seconds
  ) VALUES (
    p_request_id, v_stream_id, v_request.match_id, v_request.caller_id,
    v_request.callee_id, 'creating', 0, 1
  );
  v_hold := private.call_place_hold(p_request_id, v_request.caller_id);
  IF v_hold < 1 THEN
    DELETE FROM private.call_sessions WHERE request_id = p_request_id;
    UPDATE private.call_requests SET status = 'failed', reason = 'caller_no_minutes', closed_at = now()
    WHERE id = p_request_id;
    PERFORM private.call_enqueue_job('cancel_ring', p_request_id, v_request.callee_id);
    RETURN jsonb_build_object('outcome', 'failed', 'reason', 'caller_no_minutes');
  END IF;
  v_max := v_hold * 60 + v_settings.connect_allowance_seconds;
  UPDATE private.call_sessions
  SET hold_minutes = v_hold, max_duration_seconds = v_max
  WHERE request_id = p_request_id;
  UPDATE private.call_requests
  SET status = 'accepted', answered_at = now(), answered_device = left(p_device_id, 200)
  WHERE id = p_request_id;

  RETURN jsonb_build_object(
    'outcome', 'accepted',
    'request_id', p_request_id,
    'match_id', v_request.match_id,
    'stream_call_id', v_stream_id,
    'call_type', 'silarah_voice',
    'caller_id', v_request.caller_id,
    'callee_id', v_request.callee_id,
    'caller_name', private.call_display_name(v_request.caller_id),
    'callee_name', private.call_display_name(v_request.callee_id),
    'hold_minutes', v_hold,
    'max_duration_seconds', v_max
  );
END;
$function$;

CREATE FUNCTION public.call_service_session_started(p_request_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  UPDATE private.call_sessions
  SET status = 'active', stream_created_at = now()
  WHERE request_id = p_request_id AND status = 'creating';
  RETURN FOUND;
END;
$function$;

-- Stream refused to create the call: nobody talked, so every minute goes back.
CREATE FUNCTION public.call_service_session_failed(p_request_id uuid, p_error text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  PERFORM 1 FROM private.call_sessions WHERE request_id = p_request_id
    AND status = 'creating' FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  PERFORM private.call_release_holds(p_request_id, 0, 'stream_create_failed');
  UPDATE private.call_sessions
  SET status = 'failed', last_error = left(p_error, 500), ended_at = now(),
      settled_at = now(), settle_source = 'create_failed',
      connected_seconds = 0, charged_minutes = 0,
      charged_included_minutes = 0, charged_pack_minutes = 0
  WHERE request_id = p_request_id;
  UPDATE private.call_requests SET status = 'failed', reason = 'stream_create_failed', closed_at = now()
  WHERE id = p_request_id;
  -- In case Stream did create it before failing to answer.
  PERFORM private.call_enqueue_job('end_stream_call', p_request_id);
END;
$function$;

-- Token request: the call must be live and p_user one of its two members.
CREATE FUNCTION public.call_service_join(p_user uuid, p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_session private.call_sessions%ROWTYPE;
  v_request private.call_requests%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_request FROM private.call_requests WHERE id = p_request_id;
  IF NOT FOUND OR p_user NOT IN (v_request.caller_id, v_request.callee_id) THEN
    RETURN jsonb_build_object('outcome', 'not_found');
  END IF;
  IF v_request.status = 'ringing' THEN
    RETURN jsonb_build_object('outcome', 'ringing',
      'ring_expires_at', v_request.ring_expires_at);
  END IF;
  SELECT * INTO v_session FROM private.call_sessions WHERE request_id = p_request_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('outcome', v_request.status, 'reason', v_request.reason);
  END IF;
  IF v_session.status = 'creating' THEN
    RETURN jsonb_build_object('outcome', 'connecting');
  END IF;
  IF v_session.status <> 'active' THEN
    RETURN jsonb_build_object('outcome', 'ended', 'reason', v_session.end_reason);
  END IF;
  RETURN jsonb_build_object(
    'outcome', 'active',
    'request_id', p_request_id,
    'match_id', v_session.match_id,
    'stream_call_id', v_session.stream_call_id,
    'call_type', 'silarah_voice',
    'caller_id', v_session.caller_id,
    'callee_id', v_session.callee_id,
    'role', CASE WHEN p_user = v_session.caller_id THEN 'caller' ELSE 'callee' END,
    'my_name', private.call_display_name(p_user),
    'other_name', private.call_display_name(
      CASE WHEN p_user = v_session.caller_id THEN v_session.callee_id ELSE v_session.caller_id END),
    'hold_minutes', v_session.hold_minutes,
    'max_duration_seconds', v_session.max_duration_seconds,
    'accepted_at', v_session.accepted_at
  );
END;
$function$;

-- Hang up, cancel or decline from the app.
CREATE FUNCTION public.call_service_end(p_user uuid, p_request_id uuid, p_reason text DEFAULT 'hangup')
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_request private.call_requests%ROWTYPE;
  v_reason text := CASE WHEN p_reason IN ('hangup', 'timeout', 'declined', 'cancelled', 'reported')
    THEN p_reason ELSE 'hangup' END;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_request FROM private.call_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND OR p_user NOT IN (v_request.caller_id, v_request.callee_id) THEN
    RETURN jsonb_build_object('outcome', 'not_found');
  END IF;

  IF v_request.status = 'ringing' THEN
    IF p_user = v_request.callee_id THEN
      UPDATE private.call_requests SET status = 'declined', reason = 'declined', closed_at = now()
      WHERE id = p_request_id;
      PERFORM private.call_enqueue_job('cancel_ring', p_request_id, v_request.callee_id);
      RETURN jsonb_build_object('outcome', 'declined', 'callee_id', v_request.callee_id);
    END IF;
    IF v_reason = 'timeout' THEN
      UPDATE private.call_requests SET status = 'missed', reason = 'timeout', closed_at = now()
      WHERE id = p_request_id;
      PERFORM private.call_queue_missed_note(p_request_id);
    ELSE
      UPDATE private.call_requests SET status = 'cancelled', reason = 'caller_cancelled', closed_at = now()
      WHERE id = p_request_id;
      PERFORM private.call_queue_missed_note(p_request_id);
    END IF;
    PERFORM private.call_enqueue_job('cancel_ring', p_request_id, v_request.callee_id);
    RETURN jsonb_build_object('outcome', 'cancelled', 'callee_id', v_request.callee_id);
  END IF;

  IF private.call_end_request(p_request_id, v_reason) THEN
    RETURN jsonb_build_object('outcome', 'ending',
      'stream_call_id', (SELECT stream_call_id FROM private.call_sessions WHERE request_id = p_request_id));
  END IF;
  RETURN jsonb_build_object('outcome', 'already_ended');
END;
$function$;

-- Decline from the notification's Decline button, which has no session: the
-- single-use token arrived only in the push to the callee's own devices.
CREATE FUNCTION public.call_service_decline_with_token(p_request_id uuid, p_token text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_request private.call_requests%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_request FROM private.call_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND OR v_request.decline_token_hash IS NULL OR p_token IS NULL
    OR length(p_token) <> 48
    OR encode(extensions.digest(p_token, 'sha256'), 'hex') <> v_request.decline_token_hash THEN
    RETURN jsonb_build_object('outcome', 'not_found');
  END IF;
  IF v_request.status <> 'ringing' THEN
    RETURN jsonb_build_object('outcome', v_request.status);
  END IF;
  UPDATE private.call_requests
  SET status = 'declined', reason = 'declined', closed_at = now(), decline_token_hash = NULL
  WHERE id = p_request_id;
  PERFORM private.call_enqueue_job('cancel_ring', p_request_id, v_request.callee_id);
  RETURN jsonb_build_object('outcome', 'declined', 'callee_id', v_request.callee_id);
END;
$function$;

-- More minutes on a live call (after a top-up, or "still talking?" at the
-- hold limit). Only the caller pays, so only the caller can extend.
CREATE FUNCTION public.call_service_extend(p_user uuid, p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_settings private.call_settings := private.call_settings_row();
  v_session private.call_sessions%ROWTYPE;
  v_added integer;
  v_max integer;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_session FROM private.call_sessions WHERE request_id = p_request_id FOR UPDATE;
  IF NOT FOUND OR v_session.caller_id <> p_user THEN
    RETURN jsonb_build_object('outcome', 'not_found');
  END IF;
  IF v_session.status <> 'active' THEN
    RETURN jsonb_build_object('outcome', 'ended');
  END IF;
  IF NOT v_settings.calls_enabled
    OR NOT private.call_premium_rule_ok(v_session.caller_id, v_session.callee_id) THEN
    RETURN jsonb_build_object('outcome', 'not_allowed');
  END IF;
  v_added := private.call_place_hold(p_request_id, p_user);
  IF v_added < 1 THEN
    RETURN jsonb_build_object('outcome', 'no_minutes');
  END IF;
  v_max := (v_session.hold_minutes + v_added) * 60 + v_settings.connect_allowance_seconds;
  UPDATE private.call_sessions
  SET hold_minutes = hold_minutes + v_added, max_duration_seconds = v_max
  WHERE request_id = p_request_id;
  RETURN jsonb_build_object(
    'outcome', 'extended',
    'stream_call_id', v_session.stream_call_id,
    'added_minutes', v_added,
    'hold_minutes', v_session.hold_minutes + v_added,
    'max_duration_seconds', v_max
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 8. Stream webhook and worker RPCs (service_role only)
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.call_service_record_stream_event(
  p_webhook_id text,
  p_event_type text,
  p_stream_call_id text,
  p_stream_session_id text,
  p_user_id text,
  p_user_session_id text,
  p_occurred_at timestamptz,
  p_duration_seconds integer
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_session private.call_sessions%ROWTYPE;
  v_user uuid;
  v_action text := 'none';
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  INSERT INTO private.stream_webhook_deliveries(webhook_id, event_type)
  VALUES (left(p_webhook_id, 200), left(p_event_type, 100))
  ON CONFLICT (webhook_id) DO NOTHING;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('duplicate', true);
  END IF;

  SELECT * INTO v_session FROM private.call_sessions
  WHERE stream_call_id = p_stream_call_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('duplicate', false, 'known', false);
  END IF;
  IF p_user_id ~ '^[0-9a-f-]{36}$' THEN v_user := p_user_id::uuid; END IF;

  IF p_event_type IN ('call.session_participant_joined', 'call.session_participant_left')
    AND v_user IN (v_session.caller_id, v_session.callee_id) THEN
    INSERT INTO private.call_participant_events(
      request_id, user_id, user_session_id, stream_session_id, kind,
      occurred_at, duration_seconds
    ) VALUES (
      v_session.request_id, v_user, left(p_user_session_id, 200),
      left(p_stream_session_id, 200),
      CASE WHEN p_event_type = 'call.session_participant_joined' THEN 'joined' ELSE 'left' END,
      coalesce(p_occurred_at, now()), p_duration_seconds
    );
  END IF;

  IF p_event_type = 'call.session_participant_joined'
    AND v_user IN (v_session.caller_id, v_session.callee_id) THEN
    UPDATE private.call_sessions
    SET caller_joined_at = CASE WHEN v_user = caller_id
          THEN coalesce(caller_joined_at, coalesce(p_occurred_at, now())) ELSE caller_joined_at END,
        callee_joined_at = CASE WHEN v_user = callee_id
          THEN coalesce(callee_joined_at, coalesce(p_occurred_at, now())) ELSE callee_joined_at END,
        stream_session_id = coalesce(stream_session_id, left(p_stream_session_id, 200))
    WHERE request_id = v_session.request_id;
    UPDATE private.call_sessions
    SET both_joined_at = greatest(caller_joined_at, callee_joined_at)
    WHERE request_id = v_session.request_id
      AND both_joined_at IS NULL
      AND caller_joined_at IS NOT NULL AND callee_joined_at IS NOT NULL;
  ELSIF p_event_type = 'call.session_participant_left'
    AND v_user IN (v_session.caller_id, v_session.callee_id)
    AND v_session.status IN ('creating', 'active') THEN
    -- Either member leaving ends the call. The worker first confirms with
    -- Stream that the member has not reconnected.
    v_action := 'check_left';
  ELSIF p_event_type IN ('call.session_ended', 'call.ended') THEN
    UPDATE private.call_sessions
    SET status = CASE WHEN status IN ('creating', 'active', 'ending') THEN 'ended' ELSE status END,
        end_reason = coalesce(end_reason, CASE WHEN p_event_type = 'call.ended'
          THEN 'stream_ended' ELSE 'session_ended' END),
        ended_at = coalesce(ended_at, now()),
        stream_session_id = coalesce(stream_session_id, left(p_stream_session_id, 200))
    WHERE request_id = v_session.request_id;
    IF v_session.status NOT IN ('settled', 'failed') THEN
      PERFORM private.call_enqueue_job('settle', v_session.request_id, NULL, interval '3 seconds');
      v_action := 'settle';
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'duplicate', false, 'known', true,
    'request_id', v_session.request_id,
    'action', v_action
  );
END;
$function$;

-- Stream confirmed the call is over (mark_ended succeeded or it was gone).
CREATE FUNCTION public.call_service_stream_end_confirmed(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  UPDATE private.call_sessions
  SET status = CASE WHEN status IN ('creating', 'active', 'ending') THEN 'ended' ELSE status END,
      ended_at = coalesce(ended_at, now())
  WHERE request_id = p_request_id;
  IF EXISTS (SELECT 1 FROM private.call_sessions
             WHERE request_id = p_request_id AND status = 'ended') THEN
    PERFORM private.call_enqueue_job('settle', p_request_id, NULL, interval '5 seconds');
  END IF;
END;
$function$;

-- The server ends a call by itself (member left, join timeout, rule broken).
CREATE FUNCTION public.call_service_system_end(p_request_id uuid, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_changed boolean;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  v_changed := private.call_end_request(p_request_id, left(coalesce(p_reason, 'system'), 60));
  RETURN jsonb_build_object(
    'changed', v_changed,
    'status', (SELECT status FROM private.call_sessions WHERE request_id = p_request_id),
    'stream_call_id', (SELECT stream_call_id FROM private.call_sessions WHERE request_id = p_request_id)
  );
END;
$function$;

CREATE FUNCTION public.call_service_mark_both_joined(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  UPDATE private.call_sessions SET both_joined_at = coalesce(both_joined_at, now())
  WHERE request_id = p_request_id;
END;
$function$;

-- Charges what both members were connected for, rounded up per started
-- minute and capped at the hold; gives the rest back.
CREATE FUNCTION public.call_service_settle(
  p_request_id uuid,
  p_connected_seconds integer,
  p_source text,
  p_stream_session_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
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

  IF v_settings.monthly_cap_minutes > 0 THEN
    PERFORM private.set_operational_alert(
      'voice_call_minutes_70',
      format('Voice calls used %s of the %s-minute monthly cap (70%% alert).',
             v_used, v_settings.monthly_cap_minutes),
      v_used, v_used >= v_settings.monthly_cap_minutes * 0.7);
    PERFORM private.set_operational_alert(
      'voice_call_minutes_90',
      format('Voice calls used %s of the %s-minute monthly cap (90%% alert). New calls stop at 100%%.',
             v_used, v_settings.monthly_cap_minutes),
      v_used, v_used >= v_settings.monthly_cap_minutes * 0.9);
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

-- Facts the worker needs about one call.
CREATE FUNCTION public.call_service_session_info(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v jsonb;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT jsonb_build_object(
    'request_id', s.request_id,
    'stream_call_id', s.stream_call_id,
    'caller_id', s.caller_id,
    'callee_id', s.callee_id,
    'status', s.status,
    'hold_minutes', s.hold_minutes,
    'max_duration_seconds', s.max_duration_seconds,
    'accepted_at', s.accepted_at,
    'both_joined_at', s.both_joined_at,
    'end_requested_at', s.end_requested_at,
    'ended_at', s.ended_at,
    'stream_session_id', s.stream_session_id,
    'events', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'user_id', e.user_id, 'kind', e.kind, 'at', e.occurred_at,
        'duration_seconds', e.duration_seconds) ORDER BY e.occurred_at)
      FROM private.call_participant_events e WHERE e.request_id = s.request_id
    ), '[]'::jsonb)
  ) INTO v
  FROM private.call_sessions s WHERE s.request_id = p_request_id;
  RETURN v;
END;
$function$;

-- Scans for due work and queues it. Cheap; runs every 10 seconds.
CREATE FUNCTION private.call_enqueue_due_work()
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

  DELETE FROM private.stream_webhook_deliveries WHERE received_at < now() - interval '7 days';
  DELETE FROM private.call_jobs WHERE status IN ('done', 'dead') AND created_at < now() - interval '30 days';
  RETURN v_count;
END;
$function$;

CREATE FUNCTION private.call_watchdog()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  -- Nothing to do in the common case: no open calls, no queued work.
  IF NOT EXISTS (SELECT 1 FROM private.call_requests WHERE status = 'ringing')
    AND NOT EXISTS (SELECT 1 FROM private.call_sessions
                    WHERE status IN ('creating', 'active', 'ending', 'ended'))
    AND NOT EXISTS (SELECT 1 FROM private.call_jobs
                    WHERE status IN ('pending', 'processing') AND next_attempt_at <= now()) THEN
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

CREATE FUNCTION public.call_service_checkout_jobs(p_limit integer DEFAULT 20)
RETURNS TABLE (id bigint, kind text, request_id uuid, user_id uuid, attempts integer, lease_token uuid)
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
  RETURNING j.id, j.kind, j.request_id, j.user_id, j.attempts, j.lease_token;
END;
$function$;

CREATE FUNCTION public.call_service_finish_job(
  p_job_id bigint, p_lease_token uuid, p_success boolean, p_error text DEFAULT NULL,
  p_retry_seconds integer DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_job private.call_jobs%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_job FROM private.call_jobs WHERE id = p_job_id AND lease_token = p_lease_token FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  IF p_success THEN
    UPDATE private.call_jobs SET status = 'done', done_at = now(), last_error = NULL, lease_token = NULL
    WHERE id = p_job_id;
    RETURN;
  END IF;
  IF v_job.attempts >= 30 THEN
    UPDATE private.call_jobs SET status = 'dead', last_error = left(p_error, 500), lease_token = NULL
    WHERE id = p_job_id;
    PERFORM private.set_operational_alert(
      'voice_call_worker_dead_job',
      format('A voice-call job (%s) failed 30 times: %s', v_job.kind, left(coalesce(p_error, ''), 200)),
      1, true);
    RETURN;
  END IF;
  UPDATE private.call_jobs
  SET status = 'pending', lease_token = NULL, last_error = left(p_error, 500),
      next_attempt_at = now() + make_interval(secs => coalesce(p_retry_seconds,
        least(300, 5 * power(2, least(v_job.attempts, 6))::integer)))
  WHERE id = p_job_id;
END;
$function$;

-- Devices to ring, and which account they belong to.
CREATE FUNCTION public.call_service_device_tokens(p_user uuid)
RETURNS TABLE (fcm_token text, device_id text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT t.fcm_token, t.device_id FROM public.user_fcm_tokens t
  WHERE t.user_id = p_user
  ORDER BY t.updated_at DESC
  LIMIT 5;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 9. Packs (RevenueCat webhook, service_role only)
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.call_service_credit_pack(
  p_user uuid, p_event_id text, p_transaction_id text, p_product_id text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_minutes integer;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT pp.minutes INTO v_minutes FROM private.call_pack_products pp
  WHERE pp.product_id = p_product_id;
  IF v_minutes IS NULL THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'unknown_product');
  END IF;
  IF nullif(trim(p_transaction_id), '') IS NULL OR nullif(trim(p_event_id), '') IS NULL THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'missing_transaction');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_user) THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'unknown_user');
  END IF;
  INSERT INTO private.call_wallets(user_id) VALUES (p_user) ON CONFLICT (user_id) DO NOTHING;
  PERFORM 1 FROM private.call_wallets WHERE user_id = p_user FOR UPDATE;

  BEGIN
    INSERT INTO private.call_ledger(
      user_id, kind, pack_minutes_delta, product_id, transaction_id, provider_event_id
    ) VALUES (p_user, 'pack_purchase', v_minutes, p_product_id, p_transaction_id, p_event_id);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'duplicate');
  END;
  UPDATE private.call_wallets
  SET pack_minutes = pack_minutes + v_minutes, updated_at = now()
  WHERE user_id = p_user;
  RETURN jsonb_build_object('applied', true, 'minutes', v_minutes);
END;
$function$;

CREATE FUNCTION public.call_service_refund_pack(
  p_user uuid, p_event_id text, p_transaction_id text, p_product_id text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_minutes integer;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  SELECT pp.minutes INTO v_minutes FROM private.call_pack_products pp
  WHERE pp.product_id = p_product_id;
  IF v_minutes IS NULL THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'unknown_product');
  END IF;
  IF nullif(trim(p_transaction_id), '') IS NULL OR nullif(trim(p_event_id), '') IS NULL THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'missing_transaction');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_user) THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'unknown_user');
  END IF;
  INSERT INTO private.call_wallets(user_id) VALUES (p_user) ON CONFLICT (user_id) DO NOTHING;
  PERFORM 1 FROM private.call_wallets WHERE user_id = p_user FOR UPDATE;

  BEGIN
    INSERT INTO private.call_ledger(
      user_id, kind, pack_minutes_delta, product_id, transaction_id, provider_event_id
    ) VALUES (p_user, 'pack_refund', -v_minutes, p_product_id, p_transaction_id, p_event_id);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'duplicate');
  END;
  -- The balance may go negative; that blocks calling until a top-up.
  UPDATE private.call_wallets
  SET pack_minutes = pack_minutes - v_minutes,
      pack_refund_count = pack_refund_count + 1,
      updated_at = now()
  WHERE user_id = p_user;
  RETURN jsonb_build_object('applied', true, 'minutes', -v_minutes);
END;
$function$;

-- A refunded Premium payment removes the current period's included minutes.
CREATE FUNCTION public.call_service_forfeit_included(p_user uuid, p_event_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_period private.call_included_periods%ROWTYPE;
  v_remaining integer;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF EXISTS (SELECT 1 FROM private.call_ledger WHERE provider_event_id = p_event_id) THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'duplicate');
  END IF;
  SELECT * INTO v_period FROM private.call_included_periods cp
  WHERE cp.user_id = p_user AND cp.period_start <= now() AND cp.period_end > now()
    AND cp.forfeited_at IS NULL
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'no_current_period');
  END IF;
  v_remaining := greatest(v_period.granted_minutes - v_period.used_minutes, 0);
  UPDATE private.call_included_periods SET forfeited_at = now()
  WHERE user_id = p_user AND period_start = v_period.period_start;
  INSERT INTO private.call_ledger(user_id, kind, included_minutes_delta, provider_event_id, note)
  VALUES (p_user, 'included_forfeit', -v_remaining, p_event_id, 'premium_refunded');
  RETURN jsonb_build_object('applied', true, 'minutes', -v_remaining);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 10. Member RPCs (authenticated)
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.get_my_call_wallet()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_settings private.call_settings := private.call_settings_row();
  v_state record;
  v_held integer;
BEGIN
  SELECT * INTO v_state FROM private.call_wallet_state(v_me, false);
  SELECT coalesce(sum(s.hold_minutes), 0)::integer INTO v_held
  FROM private.call_sessions s
  WHERE s.caller_id = v_me AND s.status IN ('creating', 'active', 'ending', 'ended');
  RETURN jsonb_build_object(
    'calls_enabled', v_settings.calls_enabled,
    'premium', v_state.premium,
    'included_minutes', v_state.included_remaining,
    'included_granted', v_state.included_granted,
    'included_period_end', v_state.period_end,
    'pack_minutes', v_state.pack_minutes,
    'held_minutes', v_held,
    'available_minutes', v_state.available_minutes,
    'can_buy_packs', v_state.premium
      AND v_state.pack_refund_count < v_settings.max_pack_refunds,
    'packs', coalesce((
      SELECT jsonb_agg(jsonb_build_object('product_id', pp.product_id, 'minutes', pp.minutes)
                       ORDER BY pp.sort_order)
      FROM private.call_pack_products pp WHERE pp.active
    ), '[]'::jsonb)
  );
END;
$function$;

CREATE FUNCTION public.get_my_call_preferences()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT jsonb_build_object(
    'call_mode', coalesce((SELECT mp.call_mode FROM private.call_member_prefs mp
                           WHERE mp.user_id = auth.uid()), 'ring'),
    'calls_enabled', (private.call_settings_row()).calls_enabled
  )
  WHERE auth.uid() IS NOT NULL;
$function$;

CREATE FUNCTION public.set_my_call_mode(p_mode text)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := private.assert_authenticated();
BEGIN
  IF p_mode NOT IN ('ring', 'silent', 'off') THEN
    RAISE EXCEPTION 'invalid_call_mode' USING ERRCODE = '22023';
  END IF;
  INSERT INTO private.call_member_prefs(user_id, call_mode) VALUES (v_me, p_mode)
  ON CONFLICT (user_id) DO UPDATE SET call_mode = EXCLUDED.call_mode, updated_at = now();
  RETURN p_mode;
END;
$function$;

CREATE FUNCTION public.set_chat_call_prefs(p_match_id uuid, p_muted boolean, p_calls_blocked boolean)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_other uuid := private.call_match_other(p_match_id, v_me);
BEGIN
  IF v_other IS NULL THEN
    RAISE EXCEPTION 'chat_not_found' USING ERRCODE = 'P0001';
  END IF;
  INSERT INTO private.call_pair_prefs(user_id, other_user_id, muted, calls_blocked)
  VALUES (v_me, v_other, coalesce(p_muted, false), coalesce(p_calls_blocked, false))
  ON CONFLICT (user_id, other_user_id) DO UPDATE
  SET muted = EXCLUDED.muted, calls_blocked = EXCLUDED.calls_blocked, updated_at = now();
  IF coalesce(p_calls_blocked, false) THEN
    PERFORM private.call_end_for_users(v_me, v_other, 'calls_blocked');
  END IF;
  RETURN jsonb_build_object('muted', coalesce(p_muted, false),
                            'calls_blocked', coalesce(p_calls_blocked, false));
END;
$function$;

-- Call history in a chat, as the member sees it.
CREATE FUNCTION private.call_events_for(p_match_id uuid, p_viewer uuid, p_limit integer)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT coalesce(jsonb_agg(e ORDER BY (e->>'created_at')::timestamptz DESC), '[]'::jsonb)
  FROM (
    SELECT jsonb_build_object(
      'id', r.id,
      'created_at', r.created_at,
      'direction', CASE WHEN r.caller_id = p_viewer THEN 'outgoing' ELSE 'incoming' END,
      -- What the viewer is allowed to know: the caller never learns why a
      -- call was not answered.
      'outcome', CASE
        WHEN r.status = 'accepted' AND coalesce(s.connected_seconds, 0) > 0 THEN 'answered'
        WHEN r.status = 'accepted' THEN 'connecting_or_failed'
        WHEN r.status = 'ringing' THEN 'ringing'
        WHEN r.caller_id = p_viewer THEN 'not_answered'
        WHEN r.status = 'declined' THEN 'declined'
        ELSE 'missed'
      END,
      'duration_seconds', s.connected_seconds,
      'live', s.status IN ('creating', 'active')
    ) AS e
    FROM private.call_requests r
    LEFT JOIN private.call_sessions s ON s.request_id = r.id
    WHERE r.match_id = p_match_id
      AND (r.caller_id = p_viewer OR r.callee_id = p_viewer)
      -- A member who blocked calls from this person does not see them.
      AND NOT (r.callee_id = p_viewer AND r.status = 'unavailable' AND r.reason = 'calls_blocked')
    ORDER BY r.created_at DESC
    LIMIT least(greatest(p_limit, 1), 100)
  ) rows;
$function$;

CREATE FUNCTION public.get_chat_call_state(p_match_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_settings private.call_settings := private.call_settings_row();
  v_other uuid := private.call_match_other(p_match_id, v_me);
  v_pair private.call_pair_prefs%ROWTYPE;
  v_reason text;
  v_premium boolean;
  v_block_until timestamptz;
BEGIN
  IF v_other IS NULL THEN
    RAISE EXCEPTION 'chat_not_found' USING ERRCODE = 'P0001';
  END IF;
  SELECT * INTO v_pair FROM private.call_pair_prefs
  WHERE user_id = v_me AND other_user_id = v_other;
  v_premium := public.has_active_premium(v_me);
  v_reason := CASE
    WHEN NOT v_settings.calls_enabled THEN 'calls_disabled'
    WHEN private.call_member_block_reason(v_me) IS NOT NULL THEN 'account_restricted'
    WHEN private.call_match_block_reason(p_match_id, v_me) IS NOT NULL THEN 'not_allowed'
    WHEN NOT v_premium THEN 'premium_required'
    ELSE NULL
  END;
  IF v_reason IS NULL THEN
    v_block_until := private.call_unanswered_block_until(v_me, v_other);
    IF v_block_until IS NOT NULL THEN v_reason := 'limit_reached'; END IF;
  END IF;
  RETURN jsonb_build_object(
    'calls_enabled', v_settings.calls_enabled,
    'can_call', v_reason IS NULL,
    'reason', v_reason,
    'retry_after', v_block_until,
    'i_am_premium', v_premium,
    'i_am_female', private.call_is_female(v_me),
    'muted', coalesce(v_pair.muted, false),
    'calls_blocked', coalesce(v_pair.calls_blocked, false),
    'events', private.call_events_for(p_match_id, v_me, 30)
  );
END;
$function$;

-- Guardian mode: call time and length only, never content (spec 8).
CREATE FUNCTION public.get_guardian_match_calls(p_match_id uuid)
RETURNS TABLE (called_at timestamptz, duration_seconds integer, answered boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF NOT public.can_read_guardian_mirror(p_match_id) THEN
    RAISE EXCEPTION 'guardian_access_required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT r.created_at, s.connected_seconds, coalesce(s.connected_seconds, 0) > 0
  FROM private.call_requests r
  LEFT JOIN private.call_sessions s ON s.request_id = r.id
  WHERE r.match_id = p_match_id
    AND r.status IN ('accepted', 'declined', 'cancelled', 'missed')
  ORDER BY r.created_at DESC
  LIMIT 100;
END;
$function$;

-- Call history for the member's personal data export.
CREATE FUNCTION private.call_history_export(p_user uuid)
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
        'charged_minutes', CASE WHEN r.caller_id = p_user THEN s.charged_minutes END
      ) ORDER BY r.created_at)
      FROM private.call_requests r
      LEFT JOIN private.call_sessions s ON s.request_id = r.id
      WHERE r.caller_id = p_user
         OR (r.callee_id = p_user AND NOT (r.status = 'unavailable' AND r.reason = 'calls_blocked'))
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

-- Admin switch and overview.
CREATE FUNCTION public.admin_set_calls_enabled(p_enabled boolean, p_note text DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'Super admin authorization required' USING ERRCODE = '42501';
  END IF;
  UPDATE private.call_settings SET calls_enabled = coalesce(p_enabled, false),
    updated_at = now(), updated_by = auth.uid()
  WHERE id;
  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (auth.uid(), public.current_admin_role(), 'voice_calls_switched',
          jsonb_build_object('enabled', coalesce(p_enabled, false), 'note', left(p_note, 500)));
  RETURN coalesce(p_enabled, false);
END;
$function$;

CREATE FUNCTION public.admin_call_overview()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_settings private.call_settings := private.call_settings_row();
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'admin']) THEN
    RAISE EXCEPTION 'Admin authorization required' USING ERRCODE = '42501';
  END IF;
  RETURN jsonb_build_object(
    'calls_enabled', v_settings.calls_enabled,
    'monthly_cap_minutes', v_settings.monthly_cap_minutes,
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
-- 11. Safety triggers: end live calls when the relationship or account changes
-- ---------------------------------------------------------------------------

CREATE FUNCTION private.call_on_block()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  PERFORM private.call_end_for_users(NEW.blocker_id, NEW.blocked_id, 'blocked');
  RETURN NEW;
END;
$function$;
CREATE TRIGGER trg_call_end_on_block AFTER INSERT ON public.blocks
FOR EACH ROW EXECUTE FUNCTION private.call_on_block();

CREATE FUNCTION private.call_on_report()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  PERFORM private.call_end_for_users(NEW.reporter_id, NEW.reported_user_id, 'reported');
  RETURN NEW;
END;
$function$;
CREATE TRIGGER trg_call_end_on_report AFTER INSERT ON public.reports
FOR EACH ROW EXECUTE FUNCTION private.call_on_report();

CREATE FUNCTION private.call_on_match_closed()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  PERFORM private.call_end_for_users(NEW.user_a, NEW.user_b, 'match_closed');
  RETURN NEW;
END;
$function$;
CREATE TRIGGER trg_call_end_on_match_closed AFTER UPDATE OF status ON public.matches
FOR EACH ROW
WHEN (coalesce(OLD.status, 'active') = 'active' AND coalesce(NEW.status, 'active') <> 'active')
EXECUTE FUNCTION private.call_on_match_closed();

CREATE FUNCTION private.call_on_user_change()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
    PERFORM private.call_end_for_users(NEW.id, NULL, 'account_deleted');
    -- Stream user removed with the account (spec 7).
    PERFORM private.call_enqueue_job('delete_stream_user', NULL, NEW.id);
    PERFORM private.call_wake_worker();
  ELSIF coalesce(NEW.is_banned, false) AND NOT coalesce(OLD.is_banned, false) THEN
    PERFORM private.call_end_for_users(NEW.id, NULL, 'account_banned');
  ELSIF NEW.messaging_suspended_until IS DISTINCT FROM OLD.messaging_suspended_until
    AND NEW.messaging_suspended_until > now() THEN
    PERFORM private.call_end_for_users(NEW.id, NULL, 'account_suspended');
  ELSIF (NEW.subscription_status IS DISTINCT FROM OLD.subscription_status
         OR NEW.subscription_expires_at IS DISTINCT FROM OLD.subscription_expires_at)
    AND NOT public.has_active_premium(NEW.id) THEN
    -- Ends only the calls the rule no longer allows (a free woman may still
    -- be called by a Premium man).
    PERFORM private.call_end_for_users(s.caller_id, s.callee_id, 'premium_lost')
    FROM private.call_sessions s
    WHERE s.status IN ('creating', 'active')
      AND (s.caller_id = NEW.id OR s.callee_id = NEW.id)
      AND NOT private.call_premium_rule_ok(s.caller_id, s.callee_id);
  END IF;
  RETURN NEW;
END;
$function$;
CREATE TRIGGER trg_call_end_on_user_change
AFTER UPDATE OF deleted_at, is_banned, messaging_suspended_until,
  subscription_status, subscription_expires_at ON public.users
FOR EACH ROW EXECUTE FUNCTION private.call_on_user_change();

CREATE FUNCTION private.call_on_profile_visibility()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  PERFORM private.call_end_for_users(NEW.user_id, NULL, 'profile_' || NEW.visibility);
  RETURN NEW;
END;
$function$;
CREATE TRIGGER trg_call_end_on_profile_visibility AFTER UPDATE OF visibility ON public.profiles
FOR EACH ROW
WHEN (NEW.visibility IN ('paused', 'suspended', 'deactivated')
      AND OLD.visibility IS DISTINCT FROM NEW.visibility)
EXECUTE FUNCTION private.call_on_profile_visibility();

CREATE FUNCTION private.call_on_settings_change()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_id uuid;
  v_any boolean := false;
BEGIN
  INSERT INTO private.call_settings_audit(changed_by, old_row, new_row)
  VALUES (auth.uid(), to_jsonb(OLD), to_jsonb(NEW));
  IF OLD.calls_enabled AND NOT NEW.calls_enabled THEN
    FOR v_id IN
      SELECT r.id FROM private.call_requests r WHERE r.status = 'ringing'
      UNION
      SELECT s.request_id FROM private.call_sessions s WHERE s.status IN ('creating', 'active')
    LOOP
      IF private.call_end_request(v_id, 'calls_disabled') THEN v_any := true; END IF;
    END LOOP;
    IF v_any THEN PERFORM private.call_wake_worker(); END IF;
  END IF;
  RETURN NEW;
END;
$function$;
CREATE TRIGGER trg_call_settings_change AFTER UPDATE ON private.call_settings
FOR EACH ROW EXECUTE FUNCTION private.call_on_settings_change();

-- An account purged mid-call (staff "delete now") must not take the
-- caller's held minutes with it: release them before the rows cascade away.
CREATE FUNCTION private.call_before_user_purge()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_id uuid;
BEGIN
  FOR v_id IN
    SELECT s.request_id FROM private.call_sessions s
    WHERE s.callee_id = OLD.id AND s.caller_id <> OLD.id
      AND s.status IN ('creating', 'active', 'ending', 'ended')
  LOOP
    PERFORM private.call_release_holds(v_id, 0, 'callee_account_purged');
    UPDATE private.call_sessions SET status = 'settled', settled_at = now(),
      settle_source = 'account_purged', charged_minutes = 0
    WHERE request_id = v_id;
  END LOOP;
  RETURN OLD;
END;
$function$;
CREATE TRIGGER trg_call_before_user_purge BEFORE DELETE ON public.users
FOR EACH ROW EXECUTE FUNCTION private.call_before_user_purge();

-- ---------------------------------------------------------------------------
-- 12. Data export: add call history (spec 8)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_def text;
  v_anchor text := '''content_filter_events'', coalesce((';
BEGIN
  SELECT pg_get_functiondef('private.build_personal_data_export(text)'::regprocedure)
  INTO v_def;
  IF (length(v_def) - length(replace(v_def, v_anchor, ''))) / length(v_anchor) <> 1 THEN
    RAISE EXCEPTION 'build_personal_data_export changed shape; update migration 323';
  END IF;
  IF position('call_history_export' IN v_def) = 0 THEN
    v_def := replace(v_def, v_anchor,
      '''calls'', private.call_history_export(v_user_id),' || E'\n    ' || v_anchor);
    EXECUTE v_def;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 13. Grants and the 10-second watchdog
-- ---------------------------------------------------------------------------
DO $$
DECLARE f text;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure::text FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE (n.nspname = 'private' AND p.proname LIKE 'call\_%')
       OR (n.nspname = 'public' AND (p.proname LIKE 'call\_service\_%'
           OR p.proname IN ('get_my_call_wallet', 'get_my_call_preferences',
             'set_my_call_mode', 'set_chat_call_prefs', 'get_chat_call_state',
             'get_guardian_match_calls', 'admin_set_calls_enabled',
             'admin_call_overview')))
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', f);
  END LOOP;
END $$;

DO $$
DECLARE f text;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure::text FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname LIKE 'call\_service\_%'
  LOOP
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
  END LOOP;
END $$;

GRANT EXECUTE ON FUNCTION public.get_my_call_wallet() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_call_preferences() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_my_call_mode(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_chat_call_prefs(uuid, boolean, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_chat_call_state(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_guardian_match_calls(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_calls_enabled(boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_call_overview() TO authenticated;

SELECT cron.schedule('voice_call_watchdog_10s', '10 seconds',
  'SELECT private.call_watchdog();');
