-- Call minutes: money integrity (docs/voice_calling_spec.md 6.1-6.4, added
-- 23 Nov 2026). Builds on 323 and 324. Calling still ships OFF.
--
--   * Included minutes follow Premium runs, not reads. A run starts when
--     Premium starts and ends when Premium actually ends: at the moment its
--     coverage ran out (stored as premium_covered_until), or at once when an
--     event withdraws it (expiration, revocation, refund, a grant removed).
--     Triggers on the subscription state and on both grant tables, an expiry
--     sweep every 15 minutes and every balance read all apply the same
--     rules, so the result never depends on who notices first. A renewal,
--     plan change, recovered billing retry or un-cancellation continues the
--     run; only a new purchase after Premium ended starts a fresh one. Grace
--     and billing retry count as Premium. A refunded Premium payment still
--     forfeits that period's minutes (323).
--   * A pack refund applies only against the recorded purchase of that store
--     transaction, to the member who received it. A refund that arrives
--     before its purchase is kept and netted when the purchase arrives. A
--     reversed refund gives the minutes back once and lowers the refund
--     count.
--   * A pack paid by a store account that matches no member (an anonymous
--     RevenueCat ID, a deleted account) is never dropped: it is kept in
--     private.call_pack_unclaimed, staff are alerted, and it is credited on a
--     later transfer or alias of that store account, or by staff with one
--     audited action.
--   * Calling terms: once the legal phase sets
--     call_settings.calling_consent_version, a member must have accepted that
--     version (or later) to call or plan a call. Until then nothing changes.
--   * The minutes card says when Premium ends if it will not renew.
--   * The data export gets a minutes summary.

-- ---------------------------------------------------------------------------
-- 1. Schema
-- ---------------------------------------------------------------------------

ALTER TABLE private.call_wallets
  -- End of the member's unbroken Premium coverage as last seen ('infinity'
  -- when it has no end). The run ends at this moment unless an event
  -- extends it first.
  ADD COLUMN premium_covered_until timestamptz,
  -- The run that ended last, so a renewal after a lapse continues it.
  ADD COLUMN last_run_anchor_at timestamptz,
  ADD COLUMN last_run_ended_at timestamptz;

COMMENT ON COLUMN private.call_wallets.included_anchor_at IS
  'Start of the current Premium run (NULL: no run). Set and cleared only by private.call_sync_premium_run.';

ALTER TABLE private.call_ledger DROP CONSTRAINT call_ledger_kind_check;
ALTER TABLE private.call_ledger ADD CONSTRAINT call_ledger_kind_check CHECK (kind IN (
  'pack_purchase', 'pack_refund', 'pack_refund_reversal', 'included_forfeit',
  'hold', 'release', 'charge', 'admin_adjust'
));
CREATE UNIQUE INDEX uq_call_ledger_pack_refund_reversal
  ON private.call_ledger(transaction_id) WHERE kind = 'pack_refund_reversal';

-- A pack refund whose purchase has not arrived (or not been claimed) yet.
CREATE TABLE private.call_pack_pending_refunds (
  transaction_id text PRIMARY KEY,
  app_user_id text NOT NULL,
  product_id text NOT NULL,
  provider_event_id text NOT NULL UNIQUE,
  received_at timestamptz NOT NULL DEFAULT now(),
  applied_at timestamptz,
  reversed_at timestamptz
);

-- A paid pack the webhook could not give to a member.
CREATE TABLE private.call_pack_unclaimed (
  provider_event_id text PRIMARY KEY,
  app_user_id text NOT NULL,
  aliases text[] NOT NULL DEFAULT '{}',
  product_id text NOT NULL,
  transaction_id text,
  store text,
  environment text,
  reason text NOT NULL,
  event_at timestamptz,
  received_at timestamptz NOT NULL DEFAULT now(),
  claimed_at timestamptz,
  claimed_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  claimed_by uuid,
  claim_source text
);
CREATE INDEX idx_call_pack_unclaimed_open ON private.call_pack_unclaimed(received_at)
  WHERE claimed_at IS NULL;
CREATE INDEX idx_call_pack_unclaimed_aliases ON private.call_pack_unclaimed USING gin(aliases);

ALTER TABLE private.call_pack_pending_refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.call_pack_unclaimed ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.call_pack_pending_refunds, private.call_pack_unclaimed
  FROM PUBLIC, anon, authenticated;

-- Calling terms. The legal phase sets the version (and the consent type if
-- it is not the Terms of Service); NULL means no check.
ALTER TABLE private.call_settings
  ADD COLUMN calling_consent_type text NOT NULL DEFAULT 'terms_of_service',
  ADD COLUMN calling_consent_version text;

-- ---------------------------------------------------------------------------
-- 2. Premium runs (spec 6.1)
-- ---------------------------------------------------------------------------

-- End of p_user's unbroken Premium coverage from now: the latest end of
-- what covers now, carried on by grants that start before it ends. NULL when
-- not Premium; 'infinity' when the coverage has no end date.
CREATE FUNCTION private.call_premium_covered_until(p_user uuid)
RETURNS timestamptz
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_end timestamptz;
  v_next timestamptz;
BEGIN
  IF NOT public.has_active_premium(p_user) THEN
    RETURN NULL;
  END IF;
  SELECT max(c.ends) INTO v_end FROM (
    SELECT coalesce(u.subscription_expires_at, 'infinity'::timestamptz) AS ends
    FROM public.users u
    WHERE u.id = p_user AND u.subscription_status IN ('active', 'grace')
      AND (u.subscription_expires_at IS NULL OR u.subscription_expires_at > now())
    UNION ALL
    SELECT g.expires_at FROM public.promotional_premium_grants g
    WHERE g.user_id = p_user AND g.starts_at <= now() AND g.expires_at > now()
    UNION ALL
    SELECT t.expires_at FROM private.test_premium_grants t
    WHERE t.user_id = p_user AND t.revoked_at IS NULL
      AND t.starts_at <= now() AND t.expires_at > now()
  ) c;
  LOOP
    EXIT WHEN v_end IS NULL OR v_end = 'infinity'::timestamptz;
    SELECT max(x.ends) INTO v_next FROM (
      SELECT g.expires_at AS ends FROM public.promotional_premium_grants g
      WHERE g.user_id = p_user AND g.starts_at <= v_end AND g.expires_at > v_end
      UNION ALL
      SELECT t.expires_at FROM private.test_premium_grants t
      WHERE t.user_id = p_user AND t.revoked_at IS NULL
        AND t.starts_at <= v_end AND t.expires_at > v_end
    ) x;
    EXIT WHEN v_next IS NULL;
    v_end := v_next;
  END LOOP;
  RETURN v_end;
END;
$function$;

-- The run state p_user should have now, from the stored run and Premium as
-- it is. p_event: the subscription event that changed Premium (NULL for
-- grants, the sweep and reads).
CREATE FUNCTION private.call_premium_run_target(
  p_user uuid, p_wallet private.call_wallets, p_event text
)
RETURNS TABLE (anchor_at timestamptz, covered_until timestamptz,
               last_anchor_at timestamptz, last_ended_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_anchor timestamptz := p_wallet.included_anchor_at;
  v_until timestamptz := p_wallet.premium_covered_until;
  v_last_anchor timestamptz := p_wallet.last_run_anchor_at;
  v_last_end timestamptz := p_wallet.last_run_ended_at;
BEGIN
  -- Coverage ran out at a known moment: the run ended then.
  IF v_anchor IS NOT NULL AND v_until IS NOT NULL AND v_until <= now() THEN
    v_last_anchor := v_anchor;
    v_last_end := v_until;
    v_anchor := NULL;
    v_until := NULL;
  END IF;

  IF NOT public.has_active_premium(p_user) THEN
    -- Withdrawn before its time by an event.
    IF v_anchor IS NOT NULL THEN
      v_last_anchor := v_anchor;
      v_last_end := now();
      v_anchor := NULL;
    END IF;
    v_until := NULL;
  ELSE
    IF v_anchor IS NULL THEN
      IF v_last_anchor IS NOT NULL AND p_event IS NOT NULL AND p_event <> 'INITIAL_PURCHASE' THEN
        -- The subscription carried on (renewal, recovered billing retry,
        -- plan change, un-cancellation): same run, same periods.
        v_anchor := v_last_anchor;
      ELSE
        -- A new run: when its coverage began (a grant's start), never
        -- before the last run ended.
        SELECT greatest(coalesce(v_last_end, '-infinity'::timestamptz),
                        least(now(), coalesce(min(s.starts_at), now())))
        INTO v_anchor
        FROM (
          SELECT g.starts_at FROM public.promotional_premium_grants g
          WHERE g.user_id = p_user AND g.starts_at <= now() AND g.expires_at > now()
          UNION ALL
          SELECT t.starts_at FROM private.test_premium_grants t
          WHERE t.user_id = p_user AND t.revoked_at IS NULL
            AND t.starts_at <= now() AND t.expires_at > now()
        ) s;
      END IF;
    END IF;
    v_until := private.call_premium_covered_until(p_user);
  END IF;
  RETURN QUERY SELECT v_anchor, v_until, v_last_anchor, v_last_end;
END;
$function$;

-- Brings p_user's stored run up to date. Idempotent: every caller (the
-- triggers, the sweep, a balance read) gets the same result.
CREATE FUNCTION private.call_sync_premium_run(p_user uuid, p_event text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_wallet private.call_wallets%ROWTYPE;
  v_target record;
BEGIN
  -- The account is being deleted (grant rows cascade): nothing to keep.
  IF NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = p_user) THEN
    RETURN;
  END IF;
  SELECT * INTO v_wallet FROM private.call_wallets w WHERE w.user_id = p_user;
  IF NOT FOUND AND NOT public.has_active_premium(p_user) THEN
    RETURN;
  END IF;
  IF FOUND THEN
    SELECT * INTO v_target FROM private.call_premium_run_target(p_user, v_wallet, p_event);
    IF v_target.anchor_at IS NOT DISTINCT FROM v_wallet.included_anchor_at
      AND v_target.covered_until IS NOT DISTINCT FROM v_wallet.premium_covered_until
      AND v_target.last_anchor_at IS NOT DISTINCT FROM v_wallet.last_run_anchor_at
      AND v_target.last_ended_at IS NOT DISTINCT FROM v_wallet.last_run_ended_at THEN
      RETURN;
    END IF;
  END IF;

  INSERT INTO private.call_wallets(user_id) VALUES (p_user) ON CONFLICT (user_id) DO NOTHING;
  SELECT * INTO v_wallet FROM private.call_wallets w WHERE w.user_id = p_user FOR UPDATE;
  SELECT * INTO v_target FROM private.call_premium_run_target(p_user, v_wallet, p_event);
  UPDATE private.call_wallets
  SET included_anchor_at = v_target.anchor_at,
      premium_covered_until = v_target.covered_until,
      last_run_anchor_at = v_target.last_anchor_at,
      last_run_ended_at = v_target.last_ended_at,
      updated_at = now()
  WHERE user_id = p_user;
END;
$function$;

-- Subscription state or a grant changed.
CREATE FUNCTION private.call_on_premium_source_change()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_event text;
BEGIN
  IF TG_TABLE_NAME = 'users' THEN
    -- The event the billing RPC just wrote (it records the event first).
    SELECT e.event_type INTO v_event FROM public.subscription_events e
    WHERE e.user_id = NEW.id AND e.event_timestamp_ms = NEW.last_billing_event_ts
      AND e.event_type NOT IN ('PRODUCT_REPLACED', 'PRODUCT_CHANGE_FROM')
    ORDER BY e.id DESC LIMIT 1;
    PERFORM private.call_sync_premium_run(NEW.id, v_event);
    RETURN NULL;
  END IF;
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    PERFORM private.call_sync_premium_run(OLD.user_id, NULL);
  END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') AND (TG_OP = 'INSERT' OR NEW.user_id <> OLD.user_id) THEN
    PERFORM private.call_sync_premium_run(NEW.user_id, NULL);
  END IF;
  RETURN NULL;
END;
$function$;

CREATE TRIGGER trg_call_premium_run_subscription
AFTER UPDATE OF subscription_status, subscription_expires_at ON public.users
FOR EACH ROW
WHEN (OLD.subscription_status IS DISTINCT FROM NEW.subscription_status
      OR OLD.subscription_expires_at IS DISTINCT FROM NEW.subscription_expires_at)
EXECUTE FUNCTION private.call_on_premium_source_change();
CREATE TRIGGER trg_call_premium_run_promo
AFTER INSERT OR UPDATE OR DELETE ON public.promotional_premium_grants
FOR EACH ROW EXECUTE FUNCTION private.call_on_premium_source_change();
CREATE TRIGGER trg_call_premium_run_test
AFTER INSERT OR UPDATE OR DELETE ON private.test_premium_grants
FOR EACH ROW EXECUTE FUNCTION private.call_on_premium_source_change();

-- Every 15 minutes: runs whose coverage ran out, and grants that began
-- without an event.
CREATE FUNCTION private.call_sync_due_premium_runs()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_user uuid;
  v_count integer := 0;
BEGIN
  FOR v_user IN
    SELECT w.user_id FROM private.call_wallets w
    WHERE w.included_anchor_at IS NOT NULL AND w.premium_covered_until <= now()
    UNION
    SELECT g.user_id FROM public.promotional_premium_grants g
    WHERE g.starts_at <= now() AND g.starts_at > now() - interval '1 day' AND g.expires_at > now()
    UNION
    SELECT t.user_id FROM private.test_premium_grants t
    WHERE t.revoked_at IS NULL AND t.starts_at <= now()
      AND t.starts_at > now() - interval '1 day' AND t.expires_at > now()
  LOOP
    PERFORM private.call_sync_premium_run(v_user, NULL);
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$function$;

-- Balance for p_user (replaces 323). The run is brought up to date first;
-- this function never decides on its own that Premium ended.
CREATE OR REPLACE FUNCTION private.call_wallet_state(p_user uuid, p_lock boolean DEFAULT false)
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
  v_premium boolean;
  v_period private.call_included_periods%ROWTYPE;
  v_start timestamptz;
  v_len interval := make_interval(days => v_settings.included_period_days);
  v_k bigint;
  v_included integer := 0;
BEGIN
  PERFORM private.call_sync_premium_run(p_user, NULL);
  INSERT INTO private.call_wallets(user_id) VALUES (p_user)
  ON CONFLICT (user_id) DO NOTHING;
  IF p_lock THEN
    SELECT * INTO v_wallet FROM private.call_wallets w WHERE w.user_id = p_user FOR UPDATE;
  ELSE
    SELECT * INTO v_wallet FROM private.call_wallets w WHERE w.user_id = p_user;
  END IF;
  v_premium := v_wallet.included_anchor_at IS NOT NULL AND public.has_active_premium(p_user);

  IF v_premium THEN
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

-- ---------------------------------------------------------------------------
-- 3. Calling terms (spec 6.5)
-- ---------------------------------------------------------------------------

-- '2.1' >= '2.0'; non-numeric versions must match exactly.
CREATE FUNCTION private.call_version_at_least(p_have text, p_need text)
RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $function$
  SELECT CASE
    WHEN p_have IS NULL THEN false
    WHEN p_have ~ '^[0-9]+(\.[0-9]+)*$' AND p_need ~ '^[0-9]+(\.[0-9]+)*$'
      THEN string_to_array(p_have, '.')::integer[] >= string_to_array(p_need, '.')::integer[]
    ELSE p_have = p_need
  END;
$function$;

CREATE FUNCTION private.call_consent_ok(p_user uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT s.calling_consent_version IS NULL OR EXISTS (
    SELECT 1 FROM public.user_consents c
    WHERE c.user_id = p_user
      AND c.consent_type = s.calling_consent_type
      AND c.revoked_at IS NULL
      AND private.call_version_at_least(c.version, s.calling_consent_version)
  )
  FROM private.call_settings s WHERE s.id;
$function$;

-- Will the subscription renew? Only an active subscription whose latest
-- event keeps it going. Grants never renew. When unsure: no.
CREATE FUNCTION private.call_premium_renews(p_user uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT coalesce((
    SELECT u.subscription_status = 'active'
      AND (u.subscription_expires_at IS NULL OR u.subscription_expires_at > now())
      AND coalesce((
        SELECT e.event_type FROM public.subscription_events e
        WHERE e.user_id = u.id AND e.product_id IS NOT NULL
          AND e.event_type NOT IN ('PRODUCT_CHANGE', 'PRODUCT_CHANGE_FROM', 'PRODUCT_REPLACED')
        ORDER BY e.event_timestamp_ms DESC, e.id DESC LIMIT 1
      ), '') IN ('INITIAL_PURCHASE', 'RENEWAL', 'UNCANCELLATION',
                 'SUBSCRIPTION_EXTENDED', 'REFUND_REVERSED')
    FROM public.users u WHERE u.id = p_user
  ), false);
$function$;

-- What the minutes card says about the period and Premium's end (spec 6.4).
CREATE FUNCTION private.call_wallet_terms(p_user uuid)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT jsonb_build_object(
    'premium_until', CASE WHEN w.premium_covered_until = 'infinity'::timestamptz THEN NULL
                          ELSE w.premium_covered_until END,
    'will_renew', private.call_premium_renews(p_user),
    'consent_required', NOT private.call_consent_ok(p_user)
  )
  FROM (SELECT p_user AS id) me
  LEFT JOIN private.call_wallets w ON w.user_id = me.id;
$function$;

-- ---------------------------------------------------------------------------
-- 4. Packs: purchase, refund, reversal, unclaimed (spec 6.2, 6.3)
-- ---------------------------------------------------------------------------

CREATE FUNCTION private.call_is_uuid(p_value text)
RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $function$
  SELECT coalesce(p_value ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', false);
$function$;

-- Takes p_minutes back for one refunded transaction. False if already taken.
CREATE FUNCTION private.call_apply_pack_refund(
  p_user uuid, p_event_id text, p_transaction_id text, p_product_id text, p_minutes integer
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  PERFORM 1 FROM private.call_wallets WHERE user_id = p_user FOR UPDATE;
  BEGIN
    INSERT INTO private.call_ledger(
      user_id, kind, pack_minutes_delta, product_id, transaction_id, provider_event_id
    ) VALUES (p_user, 'pack_refund', -p_minutes, p_product_id, p_transaction_id, p_event_id);
  EXCEPTION WHEN unique_violation THEN
    RETURN false;
  END;
  -- The balance may go negative (minutes already used, or held by a call
  -- now); that blocks calling until a top-up.
  UPDATE private.call_wallets
  SET pack_minutes = pack_minutes - p_minutes,
      pack_refund_count = pack_refund_count + 1,
      updated_at = now()
  WHERE user_id = p_user;
  RETURN true;
END;
$function$;

-- Credits one purchased pack; nets a refund that arrived first.
CREATE FUNCTION private.call_credit_pack(
  p_user uuid, p_event_id text, p_transaction_id text, p_product_id text, p_note text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_minutes integer;
  v_pending private.call_pack_pending_refunds%ROWTYPE;
  v_refunded boolean := false;
BEGIN
  SELECT pp.minutes INTO v_minutes FROM private.call_pack_products pp
  WHERE pp.product_id = p_product_id;
  IF v_minutes IS NULL THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'unknown_product');
  END IF;
  IF nullif(trim(coalesce(p_transaction_id, '')), '') IS NULL
    OR nullif(trim(coalesce(p_event_id, '')), '') IS NULL THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'missing_transaction');
  END IF;
  -- A member in the deletion grace period is still a member: a payment that
  -- completes then is theirs (lost only if the account is purged).
  IF p_user IS NULL OR NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = p_user) THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'unknown_user');
  END IF;
  INSERT INTO private.call_wallets(user_id) VALUES (p_user) ON CONFLICT (user_id) DO NOTHING;
  PERFORM 1 FROM private.call_wallets WHERE user_id = p_user FOR UPDATE;

  BEGIN
    INSERT INTO private.call_ledger(
      user_id, kind, pack_minutes_delta, product_id, transaction_id, provider_event_id, note
    ) VALUES (p_user, 'pack_purchase', v_minutes, p_product_id, p_transaction_id, p_event_id, p_note);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'duplicate');
  END;
  UPDATE private.call_wallets
  SET pack_minutes = pack_minutes + v_minutes, updated_at = now()
  WHERE user_id = p_user;

  SELECT * INTO v_pending FROM private.call_pack_pending_refunds pr
  WHERE pr.transaction_id = p_transaction_id AND pr.applied_at IS NULL AND pr.reversed_at IS NULL
  FOR UPDATE;
  IF FOUND THEN
    v_refunded := private.call_apply_pack_refund(
      p_user, v_pending.provider_event_id, p_transaction_id, p_product_id, v_minutes);
    UPDATE private.call_pack_pending_refunds SET applied_at = now()
    WHERE transaction_id = p_transaction_id;
  END IF;
  RETURN jsonb_build_object('applied', true, 'minutes', v_minutes, 'refunded', v_refunded);
END;
$function$;

-- Credits one unclaimed pack to p_user.
CREATE FUNCTION private.call_claim_unclaimed_pack(
  p_event_id text, p_user uuid, p_source text, p_staff uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_row private.call_pack_unclaimed%ROWTYPE;
  v_result jsonb;
BEGIN
  SELECT * INTO v_row FROM private.call_pack_unclaimed WHERE provider_event_id = p_event_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'not_found');
  END IF;
  IF v_row.claimed_at IS NOT NULL THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'already_claimed');
  END IF;
  -- A store event without a transaction id is still one purchase: its event.
  v_result := private.call_credit_pack(
    p_user, v_row.provider_event_id,
    coalesce(v_row.transaction_id, 'event:' || v_row.provider_event_id), v_row.product_id,
    'claimed:' || p_source);
  -- 'duplicate': this store transaction was already credited (RevenueCat
  -- also sent it under the member's ID). Close it without a second credit.
  IF (v_result->>'applied')::boolean OR v_result->>'reason' = 'duplicate' THEN
    UPDATE private.call_pack_unclaimed
    SET claimed_at = now(), claimed_user_id = p_user, claimed_by = p_staff,
        claim_source = CASE WHEN (v_result->>'applied')::boolean THEN p_source
                            ELSE p_source || ':already_credited' END
    WHERE provider_event_id = p_event_id;
  END IF;
  RETURN v_result;
END;
$function$;

-- Webhook: a pack purchase. Same as 323 for a member; anything else is kept.
CREATE OR REPLACE FUNCTION public.call_service_credit_pack(
  p_user uuid, p_event_id text, p_transaction_id text, p_product_id text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  RETURN private.call_credit_pack(p_user, p_event_id, p_transaction_id, p_product_id, NULL);
END;
$function$;

-- Webhook: a pack refund. Applied only against the recorded purchase of
-- that transaction, to the member who received it. With no purchase yet it
-- is kept and netted when the purchase arrives.
DROP FUNCTION public.call_service_refund_pack(uuid, text, text, text);
CREATE FUNCTION public.call_service_refund_pack(
  p_app_user_id text, p_event_id text, p_transaction_id text, p_product_id text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_purchase private.call_ledger%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF nullif(trim(coalesce(p_transaction_id, '')), '') IS NULL
    OR nullif(trim(coalesce(p_event_id, '')), '') IS NULL THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'missing_transaction');
  END IF;
  SELECT * INTO v_purchase FROM private.call_ledger l
  WHERE l.kind = 'pack_purchase' AND l.transaction_id = p_transaction_id;
  IF NOT FOUND THEN
    IF NOT EXISTS (SELECT 1 FROM private.call_pack_products pp WHERE pp.product_id = p_product_id) THEN
      RETURN jsonb_build_object('applied', false, 'reason', 'unknown_product');
    END IF;
    INSERT INTO private.call_pack_pending_refunds(
      transaction_id, app_user_id, product_id, provider_event_id
    ) VALUES (p_transaction_id, coalesce(p_app_user_id, ''), p_product_id, p_event_id)
    ON CONFLICT DO NOTHING;
    RETURN jsonb_build_object('applied', false, 'reason', 'pending_purchase');
  END IF;
  IF NOT private.call_apply_pack_refund(
    v_purchase.user_id, p_event_id, p_transaction_id, v_purchase.product_id,
    v_purchase.pack_minutes_delta) THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'duplicate');
  END IF;
  RETURN jsonb_build_object('applied', true, 'minutes', -v_purchase.pack_minutes_delta,
                            'user_id', v_purchase.user_id);
END;
$function$;

-- Webhook: a pack refund was reversed (or the purchase un-cancelled). The
-- minutes come back once and the refund no longer counts.
CREATE FUNCTION public.call_service_reverse_pack_refund(
  p_app_user_id text, p_event_id text, p_transaction_id text, p_product_id text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_refund private.call_ledger%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF nullif(trim(coalesce(p_transaction_id, '')), '') IS NULL
    OR nullif(trim(coalesce(p_event_id, '')), '') IS NULL THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'missing_transaction');
  END IF;
  -- A refund still waiting for its purchase is simply dropped.
  UPDATE private.call_pack_pending_refunds SET reversed_at = now()
  WHERE transaction_id = p_transaction_id AND applied_at IS NULL AND reversed_at IS NULL;
  IF FOUND THEN
    RETURN jsonb_build_object('applied', true, 'reason', 'pending_refund_dropped');
  END IF;
  SELECT * INTO v_refund FROM private.call_ledger l
  WHERE l.kind = 'pack_refund' AND l.transaction_id = p_transaction_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'no_refund');
  END IF;
  PERFORM 1 FROM private.call_wallets WHERE user_id = v_refund.user_id FOR UPDATE;
  BEGIN
    INSERT INTO private.call_ledger(
      user_id, kind, pack_minutes_delta, product_id, transaction_id, provider_event_id
    ) VALUES (v_refund.user_id, 'pack_refund_reversal', -v_refund.pack_minutes_delta,
              v_refund.product_id, p_transaction_id, p_event_id);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'duplicate');
  END;
  UPDATE private.call_wallets
  SET pack_minutes = pack_minutes - v_refund.pack_minutes_delta,
      pack_refund_count = greatest(pack_refund_count - 1, 0),
      updated_at = now()
  WHERE user_id = v_refund.user_id;
  RETURN jsonb_build_object('applied', true, 'minutes', -v_refund.pack_minutes_delta,
                            'user_id', v_refund.user_id);
END;
$function$;

-- Webhook: a paid pack with no member to give it to. Kept, never dropped.
CREATE FUNCTION public.call_service_store_unclaimed_pack(
  p_event_id text, p_app_user_id text, p_aliases text[], p_product_id text,
  p_transaction_id text, p_store text, p_environment text, p_event_at timestamptz,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_stored text;
  v_user uuid;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF nullif(trim(coalesce(p_event_id, '')), '') IS NULL
    OR NOT EXISTS (SELECT 1 FROM private.call_pack_products pp WHERE pp.product_id = p_product_id) THEN
    RETURN jsonb_build_object('stored', false, 'reason', 'invalid');
  END IF;
  INSERT INTO private.call_pack_unclaimed(
    provider_event_id, app_user_id, aliases, product_id, transaction_id, store,
    environment, reason, event_at
  ) VALUES (
    p_event_id, coalesce(p_app_user_id, ''), coalesce(p_aliases, '{}'), p_product_id,
    nullif(trim(coalesce(p_transaction_id, '')), ''), p_store, p_environment,
    left(coalesce(p_reason, 'unknown'), 40), p_event_at
  ) ON CONFLICT (provider_event_id) DO NOTHING
  RETURNING provider_event_id INTO v_stored;
  IF v_stored IS NULL THEN
    RETURN jsonb_build_object('stored', false, 'reason', 'duplicate');
  END IF;
  -- One of the store account's other IDs is a member: credit at once.
  SELECT u.id INTO v_user FROM unnest(coalesce(p_aliases, '{}')) a(id)
  JOIN public.users u ON private.call_is_uuid(a.id) AND u.id = a.id::uuid AND u.deleted_at IS NULL
  LIMIT 1;
  IF v_user IS NOT NULL THEN
    RETURN jsonb_build_object('stored', true, 'claimed', true, 'user_id', v_user,
      'credit', private.call_claim_unclaimed_pack(p_event_id, v_user, 'alias', NULL));
  END IF;
  INSERT INTO public.admin_notifications(type, message)
  VALUES ('call_pack_unclaimed', format(
    'A call-minute pack (%s) was paid by a store account that matches no member. Open Voice calls in the admin panel to credit it.',
    p_product_id));
  RETURN jsonb_build_object('stored', true, 'claimed', false);
END;
$function$;

-- Webhook: p_user is now known under p_app_ids (a transfer, or aliases on
-- any of their events). Credits packs paid under those IDs.
CREATE FUNCTION public.call_service_claim_unclaimed_packs(p_user uuid, p_app_ids text[], p_source text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_event text;
  v_count integer := 0;
  v_result jsonb;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF p_user IS NULL OR coalesce(cardinality(p_app_ids), 0) = 0 THEN
    RETURN jsonb_build_object('claimed', 0);
  END IF;
  FOR v_event IN
    SELECT c.provider_event_id FROM private.call_pack_unclaimed c
    WHERE c.claimed_at IS NULL
      AND (c.app_user_id = ANY(p_app_ids) OR c.aliases && p_app_ids)
    ORDER BY c.received_at
  LOOP
    v_result := private.call_claim_unclaimed_pack(
      v_event, p_user, left(coalesce(p_source, 'transfer'), 30), NULL);
    IF (v_result->>'applied')::boolean THEN v_count := v_count + 1; END IF;
  END LOOP;
  RETURN jsonb_build_object('claimed', v_count);
END;
$function$;

-- Staff: packs waiting for a member, newest first.
CREATE FUNCTION public.admin_unclaimed_call_packs(p_include_claimed boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'support']) THEN
    RAISE EXCEPTION 'Support authorization required' USING ERRCODE = '42501';
  END IF;
  RETURN coalesce((
    SELECT jsonb_agg(jsonb_build_object(
      'event_id', c.provider_event_id,
      'app_user_id', c.app_user_id,
      'aliases', to_jsonb(c.aliases),
      'product_id', c.product_id,
      'minutes', (SELECT pp.minutes FROM private.call_pack_products pp WHERE pp.product_id = c.product_id),
      'transaction_id', c.transaction_id,
      'store', c.store,
      'environment', c.environment,
      'reason', c.reason,
      'event_at', c.event_at,
      'received_at', c.received_at,
      'claimed_at', c.claimed_at,
      'claimed_user_id', c.claimed_user_id,
      'claim_source', c.claim_source
    ) ORDER BY c.received_at DESC)
    FROM (
      SELECT * FROM private.call_pack_unclaimed c
      WHERE p_include_claimed OR c.claimed_at IS NULL
      ORDER BY c.received_at DESC LIMIT 200
    ) c
  ), '[]'::jsonb);
END;
$function$;

-- Staff: credit one unclaimed pack to a member, with a reason. Audited.
CREATE FUNCTION public.admin_claim_unclaimed_call_pack(p_event_id text, p_user uuid, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'support']) THEN
    RAISE EXCEPTION 'Support authorization required' USING ERRCODE = '42501';
  END IF;
  IF nullif(trim(coalesce(p_reason, '')), '') IS NULL OR length(trim(p_reason)) < 5 THEN
    RAISE EXCEPTION 'reason_required' USING ERRCODE = '22023';
  END IF;
  v_result := private.call_claim_unclaimed_pack(p_event_id, p_user, 'staff', auth.uid());
  IF (v_result->>'applied')::boolean OR v_result->>'reason' = 'duplicate' THEN
    INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
    VALUES (auth.uid(), public.current_admin_role(), 'voice_call_pack_claimed',
            jsonb_build_object('event_id', p_event_id, 'user_id', p_user,
                               'result', v_result, 'reason', left(trim(p_reason), 500)));
  END IF;
  RETURN v_result;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5. Calls, plans and the minutes card
-- ---------------------------------------------------------------------------

-- 325: calling terms for both members.
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
  -- 325: the calling terms, once the legal phase sets a version.
  IF NOT private.call_consent_ok(p_caller) THEN
    RETURN jsonb_build_object('outcome', 'consent_required');
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
    -- 325: the callee has not accepted the calling terms; told in the missed call.
    WHEN NOT private.call_consent_ok(v_callee) THEN 'consent_required'
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

-- 325: the missed call tells a member to accept the calling terms.
CREATE OR REPLACE FUNCTION public.call_service_missed_push(p_request_id uuid)
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
      -- 325: they could not be rung until they accept the calling terms.
      WHEN v_request.reason = 'consent_required' THEN 'consent'
      WHEN NOT private.call_is_female(v_request.callee_id)
        AND NOT public.has_active_premium(v_request.callee_id) THEN 'premium'
      ELSE 'missed' END,
    'silent', v_mode = 'silent' OR v_muted OR v_request.reason = 'busy'
      OR private.call_in_quiet_hours(v_request.callee_id)
  );
END;
$function$;

-- 325: calling terms.
CREATE OR REPLACE FUNCTION public.propose_call_plan(p_match_id uuid, p_planned_for timestamptz)
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
  IF NOT private.call_consent_ok(v_me) THEN
    RETURN jsonb_build_object('outcome', 'consent_required');
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
    OR NOT private.call_consent_ok(v_other)
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

-- 325: calling terms.
CREATE OR REPLACE FUNCTION public.respond_call_plan(p_plan_id uuid, p_accept boolean)
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
    IF NOT private.call_consent_ok(v_me) THEN
      RETURN jsonb_build_object('outcome', 'consent_required');
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

-- 325: when Premium ends, whether it renews, the calling terms.
CREATE OR REPLACE FUNCTION public.get_my_call_overview()
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
  ) || private.call_wallet_terms(v_me);
END;
$function$;

-- 325: when Premium ends, whether it renews, the calling terms.
CREATE OR REPLACE FUNCTION public.get_my_call_wallet()
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
  ) || private.call_wallet_terms(v_me);
END;
$function$;

-- 325: minutes summary.
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
                              WHERE w.user_id = p_user), 0),
    -- 325: the ledger in a few totals (spec 6.6).
    'minutes_summary', (
      SELECT jsonb_build_object(
        'packs_bought', count(*) FILTER (WHERE l.kind = 'pack_purchase'),
        'pack_minutes_bought',
          coalesce(sum(l.pack_minutes_delta) FILTER (WHERE l.kind = 'pack_purchase'), 0),
        'pack_minutes_refunded',
          coalesce(-sum(l.pack_minutes_delta) FILTER (WHERE l.kind = 'pack_refund'), 0)
          - coalesce(sum(l.pack_minutes_delta) FILTER (WHERE l.kind = 'pack_refund_reversal'), 0),
        'pack_minutes_adjusted_by_staff',
          coalesce(sum(l.pack_minutes_delta) FILTER (WHERE l.kind = 'admin_adjust'), 0),
        'included_minutes_forfeited',
          coalesce(-sum(l.included_minutes_delta) FILTER (WHERE l.kind = 'included_forfeit'), 0),
        'included_minutes_used', coalesce((
          SELECT sum(s.charged_included_minutes) FROM private.call_sessions s
          WHERE s.caller_id = p_user), 0),
        'pack_minutes_used', coalesce((
          SELECT sum(s.charged_pack_minutes) FROM private.call_sessions s
          WHERE s.caller_id = p_user), 0)
      )
      FROM private.call_ledger l WHERE l.user_id = p_user
    )
  );
$function$;

-- ---------------------------------------------------------------------------
-- 6. Existing wallets
-- ---------------------------------------------------------------------------

-- Members on Premium now keep the period they had (323's anchor, or their
-- Premium start); then every wallet is brought up to date once.
INSERT INTO private.call_wallets(user_id, included_anchor_at)
SELECT u.id, private.call_premium_started_at(u.id)
FROM public.users u
WHERE public.has_active_premium(u.id)
ON CONFLICT (user_id) DO UPDATE
SET included_anchor_at = coalesce(private.call_wallets.included_anchor_at,
                                  EXCLUDED.included_anchor_at);

DO $$
DECLARE v_user uuid;
BEGIN
  FOR v_user IN SELECT w.user_id FROM private.call_wallets w LOOP
    PERFORM private.call_sync_premium_run(v_user, NULL);
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 7. Grants and schedule
-- ---------------------------------------------------------------------------

DO $$
DECLARE f text;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure::text FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE (n.nspname = 'private' AND p.proname LIKE 'call\_%')
       OR (n.nspname = 'public' AND (p.proname LIKE 'call\_service\_%'
           OR p.proname IN ('admin_unclaimed_call_packs', 'admin_claim_unclaimed_call_pack')))
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

GRANT EXECUTE ON FUNCTION public.admin_unclaimed_call_packs(boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_claim_unclaimed_call_pack(text, uuid, text) TO authenticated;

SELECT cron.schedule('voice_call_premium_runs', '*/15 * * * *',
  'SELECT private.call_sync_due_premium_runs();');
