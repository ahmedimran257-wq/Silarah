-- In-app plan switch (21 Nov 2026 device test).
--
-- On Google Play, RevenueCat sends PRODUCT_CHANGE when a switch is MADE,
-- not when it takes effect, and the event looks the same either way:
-- product_id = old plan, new_product_id = new plan, price 0, and
-- expiration_at_ms = the moment of the change. The new plan then starts with
-- its own INITIAL_PURCHASE: seconds later for an immediate upgrade, at the
-- old plan's period end for a deferred downgrade.
--
-- Migration 314 applied PRODUCT_CHANGE as access: it stored the change time
-- as the expiry and retired the old plan at once. Booking a downgrade from
-- 3 months to monthly therefore ended server Premium ten minutes later, while
-- the paid 3-month period still had weeks to run (seen live on 21 Nov: the
-- expiry fell from 13:09:48 to 12:59:09 on booking).
--
-- Now PRODUCT_CHANGE is only noted in the ledger (no access change, no
-- message: the new plan's purchase sends those). The old plan is retired
-- when the new plan's INITIAL_PURCHASE arrives, so 314's guarantee still
-- holds: after the switch only the plan in force can grant Premium, and a
-- refund of the new plan is not covered by the old one.

DROP FUNCTION IF EXISTS public.apply_revenuecat_subscription_event(
  uuid, text, text, bigint, text, timestamptz, text, text, numeric,
  timestamptz, text
);

CREATE FUNCTION public.apply_revenuecat_subscription_event(
  p_user_id uuid,
  p_provider_event_id text,
  p_event_type text,
  p_event_timestamp_ms bigint,
  p_subscription_status text,
  p_subscription_expires_at timestamp with time zone,
  p_product_id text DEFAULT NULL::text,
  p_currency text DEFAULT NULL::text,
  p_price numeric DEFAULT NULL::numeric,
  p_event_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_replaced_product_id text DEFAULT NULL::text
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
  v_from_product text;
  v_started_ms bigint;
BEGIN
  IF auth.role() <> 'service_role'
    OR p_subscription_status NOT IN ('none', 'active', 'grace')
    -- 312: paid states must carry an authoritative expiry.
    OR (p_subscription_status IN ('active', 'grace')
        AND p_subscription_expires_at IS NULL)
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

  -- A plan change is a note, not access. It is filed under the new plan with
  -- no expiry, and the plan it came from is kept beside it.
  IF p_event_type = 'PRODUCT_CHANGE' THEN
    INSERT INTO public.subscription_events(
      user_id, provider_event_id, event_type, event_timestamp_ms, product_id,
      currency, price, expires_at
    ) VALUES (
      p_user_id, p_provider_event_id, 'PRODUCT_CHANGE', p_event_timestamp_ms,
      p_product_id, p_currency, p_price, NULL
    )
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_event_id;
    IF v_event_id IS NULL THEN
      RETURN jsonb_build_object(
        'applied', false, 'reason', 'duplicate_event',
        'email_dedupe_key', v_dedupe_key
      );
    END IF;

    IF p_replaced_product_id IS NOT NULL
      AND p_product_id IS NOT NULL
      AND split_part(p_replaced_product_id, ':', 1)
        <> split_part(p_product_id, ':', 1) THEN
      INSERT INTO public.subscription_events(
        user_id, provider_event_id, event_type, event_timestamp_ms,
        product_id, currency, price, expires_at
      ) VALUES (
        p_user_id, p_provider_event_id || ':from', 'PRODUCT_CHANGE_FROM',
        p_event_timestamp_ms, p_replaced_product_id, NULL, NULL, NULL
      )
      ON CONFLICT DO NOTHING;

      -- Delivered after the new plan's purchase: retire the old plan now.
      SELECT min(e.event_timestamp_ms) INTO v_started_ms
      FROM public.subscription_events e
      WHERE e.user_id = p_user_id
        AND e.event_type = 'INITIAL_PURCHASE'
        AND split_part(e.product_id, ':', 1) = split_part(p_product_id, ':', 1)
        AND e.event_timestamp_ms >= p_event_timestamp_ms;
      IF v_started_ms IS NOT NULL THEN
        INSERT INTO public.subscription_events(
          user_id, provider_event_id, event_type, event_timestamp_ms,
          product_id, currency, price, expires_at
        ) VALUES (
          p_user_id, p_provider_event_id || ':replaced', 'PRODUCT_REPLACED',
          v_started_ms, p_replaced_product_id, NULL, NULL, NULL
        )
        ON CONFLICT DO NOTHING;
      END IF;
    END IF;

    RETURN jsonb_build_object(
      'applied', false, 'reason', 'plan_change_recorded',
      'email_dedupe_key', v_dedupe_key
    );
  END IF;

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

  -- The new plan has started: the plan a noted change came from can no
  -- longer grant Premium on its own. Only a change made since this plan's
  -- previous purchase counts.
  IF p_event_type = 'INITIAL_PURCHASE' AND p_product_id IS NOT NULL THEN
    SELECT f.product_id INTO v_from_product
    FROM public.subscription_events c
    JOIN public.subscription_events f
      ON f.user_id = c.user_id
     AND f.provider_event_id = c.provider_event_id || ':from'
    WHERE c.user_id = p_user_id
      AND c.event_type = 'PRODUCT_CHANGE'
      AND split_part(c.product_id, ':', 1) = split_part(p_product_id, ':', 1)
      AND c.event_timestamp_ms <= p_event_timestamp_ms
      AND NOT EXISTS (
        SELECT 1 FROM public.subscription_events p
        WHERE p.user_id = p_user_id
          AND p.event_type = 'INITIAL_PURCHASE'
          AND split_part(p.product_id, ':', 1)
            = split_part(p_product_id, ':', 1)
          AND p.event_timestamp_ms >= c.event_timestamp_ms
          AND p.event_timestamp_ms < p_event_timestamp_ms
      )
    ORDER BY c.event_timestamp_ms DESC, c.id DESC
    LIMIT 1;
    IF v_from_product IS NOT NULL THEN
      INSERT INTO public.subscription_events(
        user_id, provider_event_id, event_type, event_timestamp_ms,
        product_id, currency, price, expires_at
      ) VALUES (
        p_user_id, p_provider_event_id || ':replaced', 'PRODUCT_REPLACED',
        p_event_timestamp_ms, v_from_product, NULL, NULL, NULL
      )
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  IF p_event_timestamp_ms <= coalesce(v_last_ts, 0) THEN IF p_event_type = 'REFUND' THEN INSERT INTO public.transactional_email_outbox(dedupe_key, user_id, email_type, event_type, event_timestamp_ms, payload) VALUES (v_dedupe_key, p_user_id, 'subscription', p_event_type, p_event_timestamp_ms, jsonb_strip_nulls(jsonb_build_object('provider_event_id', p_provider_event_id, 'product_id', p_product_id, 'currency', p_currency, 'price', p_price, 'expires_at', p_event_expires_at))) ON CONFLICT (dedupe_key) DO NOTHING; END IF;
    RETURN jsonb_build_object(
      'applied', false, 'reason', 'stale_event',
      'email_dedupe_key', v_dedupe_key
    );
  END IF;

  -- Play reports products as "subscriptionId:basePlanId"; the subscription
  -- ID identifies the plan. Another plan keeps access only while its own
  -- latest event is still live: not expired, revoked or replaced. Plan-change
  -- notes are not events of a plan.
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
        AND e.event_type NOT IN ('PRODUCT_CHANGE', 'PRODUCT_CHANGE_FROM')
        AND split_part(e.product_id, ':', 1)
          <> split_part(p_product_id, ':', 1)
      ORDER BY split_part(e.product_id, ':', 1),
        e.event_timestamp_ms DESC, e.id DESC
    ) latest
    WHERE latest.event_type NOT IN ('EXPIRATION', 'REVOCATION', 'PRODUCT_REPLACED')
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
      subscription_expires_at = CASE WHEN v_status = 'active'
        THEN v_expires_at + interval '10 minutes' ELSE v_expires_at END,
      last_billing_event_ts = p_event_timestamp_ms
  WHERE id = p_user_id;

  IF p_event_type IN (
    'INITIAL_PURCHASE','RENEWAL','CANCELLATION',
    'EXPIRATION','REFUND','BILLING_ISSUE'
  ) AND NOT (p_event_type = 'EXPIRATION' AND v_status <> 'none') THEN
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
    'email_dedupe_key', v_dedupe_key,
    'access_kept', p_subscription_status = 'none' AND v_status <> 'none'
  );
END;
$function$;

-- Billing state is written by the webhook (service role) only.
REVOKE ALL ON FUNCTION public.apply_revenuecat_subscription_event(
  uuid, text, text, bigint, text, timestamptz, text, text, numeric,
  timestamptz, text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.apply_revenuecat_subscription_event(
  uuid, text, text, bigint, text, timestamptz, text, text, numeric,
  timestamptz, text
) TO service_role;
