-- 334: no limit on buying minute packs after Google Play refunds.
--
-- Silarah never refunds packs itself (only its own mistakes, by the Refund
-- Policy). Google Play may refund a pack on its own; the webhook then takes
-- that pack's minutes off the balance, which can go below zero and blocks
-- calling until a top-up (325). That already stops anyone gaining minutes
-- from refunds: refunded minutes that were used are paid back by the next
-- pack before the member can call again.
--
-- The old rule (no packs after max_pack_refunds refunds) added nothing to that
-- and created a dead end: a member whose second refund left the balance below
-- zero could neither buy a pack nor call, even with Premium's included
-- minutes. So a Premium member can always buy packs. pack_refund_count stays
-- on the wallet for records, the data export and safety review.

-- Overview (326 version; only can_buy_packs changes).
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
    -- 334: any Premium member can top up, refunds or not.
    'can_buy_packs', v_state.premium,
    'month_talk_seconds', v_talk,
    'unseen_missed', private.call_unseen_missed(v_me),
    'settling', EXISTS (
      SELECT 1 FROM private.call_sessions s
      WHERE (s.caller_id = v_me OR s.callee_id = v_me) AND s.status IN ('ending', 'ended')
    ),
    'plans', private.call_plans_for(v_me, true, 20)
  ) || private.call_wallet_terms(v_me);
END;
$function$;

-- Wallet (325 version; only can_buy_packs changes).
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
    -- 334: any Premium member can top up, refunds or not.
    'can_buy_packs', v_state.premium,
    'packs', coalesce((
      SELECT jsonb_agg(jsonb_build_object('product_id', pp.product_id, 'minutes', pp.minutes)
                       ORDER BY pp.sort_order)
      FROM private.call_pack_products pp WHERE pp.active
    ), '[]'::jsonb)
  ) || private.call_wallet_terms(v_me);
END;
$function$;

-- Rules (324 version without max_pack_refunds).
CREATE OR REPLACE FUNCTION public.get_calling_rules()
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

ALTER TABLE private.call_settings DROP COLUMN max_pack_refunds;
