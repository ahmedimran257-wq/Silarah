-- Premium gating gaps found by the women/men paywall audit (19 Nov 2026).
--
-- 1. Guardian mirror read path ignored the ward's entitlement. Women message
--    free; men need Premium to read. A guardian (wali) could still read every
--    message of a free man's match through the messages RLS policy,
--    get_guardian_match_messages and the dashboard preview, so a man could
--    invite his own second email as guardian and read his chats free.
--    Guardians now read exactly what their ward may read. Sending was already
--    checked against the ward.
-- 2. A locked inbox (a free man) still showed the other member's closing
--    message through closure_reason.
-- 3. The closed-test Premium job re-granted Premium every hour to testers an
--    admin had revoked it from. It now skips them.

CREATE OR REPLACE FUNCTION public.can_read_guardian_mirror(p_match_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.guardian_chat_mirrors gcm
    JOIN public.users ward ON ward.id = gcm.ward_id
    WHERE gcm.match_id = p_match_id
      AND gcm.guardian_id = auth.uid()
      AND public.is_current_guardian_for_ward(gcm.ward_id, gcm.mode)
      AND ward.deleted_at IS NULL
      AND coalesce(ward.is_banned, false) = false
      AND (lower(trim(coalesce(ward.gender, ''))) = 'female'
           OR public.has_active_premium(ward.id))
  );
$function$;

REVOKE ALL ON FUNCTION public.can_read_guardian_mirror(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_read_guardian_mirror(uuid) TO authenticated;

-- Same member rule as before; the guardian branch now uses the helper,
-- which keeps the old guardian checks and adds the ward's entitlement.
DROP POLICY IF EXISTS messages_select ON public.messages;
CREATE POLICY messages_select ON public.messages
  FOR SELECT TO authenticated
  USING (
    (
      (sender_id = (SELECT auth.uid()) OR receiver_id = (SELECT auth.uid()))
      AND (SELECT public.can_read_my_chat_content())
    )
    OR public.can_read_guardian_mirror(match_id)
  );

DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  -- Guardian transcript: same entitlement as the ward.
  v_def := pg_get_functiondef(
    'public.get_guardian_match_messages(uuid, timestamp with time zone, uuid, integer)'::regprocedure);
  v_old := E'    RAISE EXCEPTION \'guardian_not_authorized\' USING ERRCODE = \'P0001\';\n  END IF;\n';
  v_new := v_old
        || E'  IF NOT public.can_read_guardian_mirror(p_match_id) THEN\n'
        || E'    RAISE EXCEPTION \'subscription_required\' USING ERRCODE = \'P0001\';\n'
        || E'  END IF;\n';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION 'get_guardian_match_messages: guard not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);

  -- Guardian dashboard: no last-message preview the ward could not read.
  v_def := pg_get_functiondef('public.get_guardian_dashboard_v2(uuid)'::regprocedure);
  v_old := E'SELECT left(msg.content, 120)';
  v_new := E'SELECT CASE WHEN public.can_read_guardian_mirror(gcm.match_id) THEN left(msg.content, 120) END';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION 'get_guardian_dashboard_v2: preview not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);

  -- Inbox: a locked inbox hides the closing message too.
  v_def := pg_get_functiondef('public.get_chat_inbox(integer, timestamp with time zone)'::regprocedure);
  v_old := E'CASE WHEN inbox.member_unavailable THEN NULL ELSE inbox.closure_reason END';
  v_new := E'CASE WHEN inbox.member_unavailable OR v_content_locked THEN NULL ELSE inbox.closure_reason END';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION 'get_chat_inbox: closure reason not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);

  -- Closed-test Premium: respect an admin's revocation.
  v_def := pg_get_functiondef('private.grant_closed_test_premium()'::regprocedure);
  v_old := E'                        AND g.expires_at > now() + interval \'30 hours\')\n  LOOP';
  v_new := E'                        AND g.expires_at > now() + interval \'30 hours\')\n'
        || E'      AND NOT EXISTS (SELECT 1 FROM public.admin_audit_log l\n'
        || E'                      WHERE l.target_user_id = u.id\n'
        || E'                        AND l.action_type = \'test_premium_revoked\')\n'
        || E'  LOOP';
  IF (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 THEN
    RAISE EXCEPTION 'grant_closed_test_premium: loop filter not found exactly once';
  END IF;
  EXECUTE replace(v_def, v_old, v_new);
END
$migration$;
