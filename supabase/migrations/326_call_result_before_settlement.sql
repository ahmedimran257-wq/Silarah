-- A call's result as soon as it ends (docs/voice_calling_spec.md 12.5,
-- added 23 Nov 2026 after the two-phone test of build 48103). Builds on 324
-- and 325.
--
-- A call is settled (talk time, minutes) a few seconds after it ends. Until
-- then the Calls tab, the chat inbox and the chat showed a call the two
-- members had talked on as "No answer" / "Not connected", and the minutes
-- card still showed the call's hold as spent. Now:
--   * a call counts as answered once both members were in it
--     (call_sessions.both_joined_at), settled or not; its talk time and
--     minutes appear at settlement;
--   * get_my_call_overview says `settling` while one of the member's calls
--     has ended and is not settled yet, so the app checks again until the
--     numbers are final.

-- Who sees what for one call; p_both_joined: the two were connected.
CREATE FUNCTION private.call_outcome_for(
  p_viewer uuid, p_caller uuid, p_status text, p_connected_seconds integer,
  p_session_status text, p_both_joined boolean
)
RETURNS text
LANGUAGE sql IMMUTABLE
AS $function$
  SELECT CASE
    WHEN p_status = 'ringing' THEN 'ringing'
    WHEN p_status = 'accepted' AND p_session_status IN ('creating', 'active') THEN 'live'
    WHEN p_status = 'accepted'
      AND (coalesce(p_connected_seconds, 0) > 0
           OR (coalesce(p_both_joined, false) AND p_session_status IS DISTINCT FROM 'settled'))
      THEN 'answered'
    WHEN p_caller = p_viewer THEN 'no_answer'
    WHEN p_status = 'declined' THEN 'declined'
    WHEN p_status = 'accepted' THEN 'not_connected'
    ELSE 'missed'
  END;
$function$;

-- 326: connected calls are answered before settlement.
CREATE OR REPLACE FUNCTION public.get_my_call_log(
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
    private.call_outcome_for(v_me, page.caller_id, page.status, s.connected_seconds, s.status,
                             s.both_joined_at IS NOT NULL),
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

-- 326: connected calls are answered before settlement.
CREATE OR REPLACE FUNCTION public.get_chat_inbox(p_limit integer DEFAULT 50, p_before timestamp with time zone DEFAULT NULL::timestamp with time zone)
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
                                      cs.connected_seconds, cs.status,
                                      cs.both_joined_at IS NOT NULL) AS outcome
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

-- 326: connected calls are answered before settlement.
CREATE OR REPLACE FUNCTION private.call_events_for(p_match_id uuid, p_viewer uuid, p_limit integer)
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
        WHEN r.status = 'accepted' AND (coalesce(s.connected_seconds, 0) > 0
          OR (s.both_joined_at IS NOT NULL AND s.status <> 'settled')) THEN 'answered'
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

-- 326: `settling` while a call of the member's is being settled.
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
    -- 326: a call of theirs ended and is being settled: check again.
    'settling', EXISTS (
      SELECT 1 FROM private.call_sessions s
      WHERE (s.caller_id = v_me OR s.callee_id = v_me) AND s.status IN ('ending', 'ended')
    ),
    'plans', private.call_plans_for(v_me, true, 20)
  ) || private.call_wallet_terms(v_me);
END;
$function$;

DROP FUNCTION private.call_outcome_for(uuid, uuid, text, integer, text);

REVOKE ALL ON FUNCTION private.call_outcome_for(uuid, uuid, text, integer, text, boolean)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.call_events_for(uuid, uuid, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_call_log(text, text, timestamptz, uuid, integer, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_call_overview() TO authenticated;
