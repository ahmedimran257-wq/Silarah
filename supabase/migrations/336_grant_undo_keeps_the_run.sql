-- 336: undoing a grant revoke continues the same Premium run.
--
-- Found on the phones (25 Nov 2026): staff revoked a member's test Premium
-- grant and restored it a minute later; the server started a new run and gave
-- a fresh 30 included minutes (16 left became 30). Paid Premium already
-- continues the same run after a renewal or recovered billing (325); grants
-- now do the same when the grant that covered the last run is in force again.
-- A genuinely new grant (starting after the last run began) still starts a
-- new run with its own included minutes.

CREATE OR REPLACE FUNCTION private.call_premium_run_target(
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
      ELSIF v_last_anchor IS NOT NULL AND EXISTS (
        -- 336: a grant that already covered the last run is in force again
        -- (staff undid a revoke): the same run carries on, like a recovered
        -- subscription, so an undo never hands out fresh included minutes.
        SELECT 1 FROM public.promotional_premium_grants g
        WHERE g.user_id = p_user AND g.starts_at <= v_last_anchor
          AND g.starts_at <= now() AND g.expires_at > now()
        UNION ALL
        SELECT 1 FROM private.test_premium_grants t
        WHERE t.user_id = p_user AND t.revoked_at IS NULL AND t.starts_at <= v_last_anchor
          AND t.starts_at <= now() AND t.expires_at > now()
      ) THEN
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
