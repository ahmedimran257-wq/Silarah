-- Monthly and 3-month Premium are separate Google Play subscriptions. The app
-- refuses to sell one on top of the other, but a member can still end up
-- holding both (resubscribing from the Play Store, or a purchase made while
-- a payment was unconfirmed). users.subscription_status is one row per
-- member, so the last event used to win: refunding or expiring one plan
-- removed Premium the other plan was still paying for, and a short plan's
-- renewal could cut a longer plan's expiry.
--
-- Each event now also considers the latest ledger event of every other
-- subscription the member holds, and keeps whichever access lasts longest.
-- Only this member's few ledger rows are read, via
-- idx_subscription_events_user_time; webhook load is unchanged.

CREATE OR REPLACE FUNCTION public.apply_revenuecat_subscription_event(
  p_user_id uuid,
  p_provider_event_id text,
  p_event_type text,
  p_event_timestamp_ms bigint,
  p_subscription_status text,
  p_subscription_expires_at timestamp with time zone,
  p_product_id text DEFAULT NULL::text,
  p_currency text DEFAULT NULL::text,
  p_price numeric DEFAULT NULL::numeric,
  p_event_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_last_ts bigint;
  v_dedupe_key text;
  v_event_id uuid;
  v_status text := p_subscription_status;
  v_expires_at timestamptz := p_subscription_expires_at;
  v_other_status text;
  v_other_expires_at timestamptz;
BEGIN
  IF auth.role() <> 'service_role'
    OR p_subscription_status NOT IN ('none', 'active', 'grace')
    OR nullif(trim(p_provider_event_id), '') IS NULL
    OR char_length(p_provider_event_id) > 200
    OR p_event_timestamp_ms < 1514764800000
    OR p_event_timestamp_ms >
      (extract(epoch FROM now() + interval '5 minutes') * 1000)::bigint THEN
    RAISE EXCEPTION 'invalid_billing_event' USING ERRCODE = 'P0001';
  END IF;

  SELECT last_billing_event_ts INTO v_last_ts
  FROM public.users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'user_not_found');
  END IF;

  v_dedupe_key := 'revenuecat:' || p_provider_event_id;

  INSERT INTO public.subscription_events(
    user_id, provider_event_id, event_type, event_timestamp_ms, product_id,
    currency, price, expires_at
  ) VALUES (
    p_user_id, p_provider_event_id, p_event_type, p_event_timestamp_ms,
    p_product_id, p_currency, p_price, p_event_expires_at
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_event_id;

  IF v_event_id IS NULL THEN
    RETURN jsonb_build_object(
      'applied', false, 'reason', 'duplicate_event',
      'email_dedupe_key', v_dedupe_key
    );
  END IF;

  IF p_event_timestamp_ms <= coalesce(v_last_ts, 0) THEN
    RETURN jsonb_build_object(
      'applied', false, 'reason', 'stale_event',
      'email_dedupe_key', v_dedupe_key
    );
  END IF;

  -- Play reports products as "subscriptionId:basePlanId"; the subscription
  -- ID identifies the plan.
  IF p_product_id IS NOT NULL THEN
    SELECT
      CASE WHEN bool_or(latest.event_type <> 'BILLING_ISSUE') THEN 'active'
        WHEN count(*) > 0 THEN 'grace' END,
      max(latest.expires_at)
    INTO v_other_status, v_other_expires_at
    FROM (
      SELECT DISTINCT ON (split_part(e.product_id, ':', 1))
        e.event_type, e.expires_at
      FROM public.subscription_events e
      WHERE e.user_id = p_user_id
        AND e.product_id IS NOT NULL
        AND split_part(e.product_id, ':', 1)
          <> split_part(p_product_id, ':', 1)
      ORDER BY split_part(e.product_id, ':', 1),
        e.event_timestamp_ms DESC, e.id DESC
    ) latest
    WHERE latest.event_type NOT IN ('EXPIRATION', 'REVOCATION')
      AND latest.expires_at > now();

    IF v_other_expires_at IS NOT NULL THEN
      IF v_status = 'none' THEN
        v_status := v_other_status;
        v_expires_at := v_other_expires_at;
      ELSIF v_expires_at IS NOT NULL AND v_other_expires_at > v_expires_at THEN
        v_expires_at := v_other_expires_at;
      END IF;
    END IF;
  END IF;

  UPDATE public.users
  SET subscription_status = v_status,
      subscription_expires_at = v_expires_at,
      last_billing_event_ts = p_event_timestamp_ms
  WHERE id = p_user_id;

  IF p_event_type IN (
    'INITIAL_PURCHASE','RENEWAL','PRODUCT_CHANGE','CANCELLATION',
    'EXPIRATION','REFUND','BILLING_ISSUE'
  ) THEN
    INSERT INTO public.transactional_email_outbox(
      dedupe_key, user_id, email_type, event_type, event_timestamp_ms, payload
    ) VALUES (
      v_dedupe_key, p_user_id, 'subscription', p_event_type,
      p_event_timestamp_ms,
      jsonb_strip_nulls(jsonb_build_object(
        'provider_event_id', p_provider_event_id,
        'product_id', p_product_id,
        'currency', p_currency,
        'price', p_price,
        'expires_at', p_event_expires_at
      ))
    ) ON CONFLICT (dedupe_key) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'applied', true, 'reason', 'applied',
    'email_dedupe_key', v_dedupe_key
  );
END;
$function$;
