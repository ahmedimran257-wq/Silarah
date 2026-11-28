-- A member with a pending interest could not delete their account.
--
-- request_my_account_deletion() sets users.deleted_at as the member. The
-- AFTER UPDATE trigger cascade_soft_delete() then expires every pending
-- interest the member sent or received. That UPDATE runs with auth.uid() still
-- the member, and trg_guard_interest_actor_standing (migration 232) rejects any
-- interest write by an actor who is deleted or banned, so the whole deletion
-- rolled back with 'account_restricted'. The same happened to a member who
-- received an interest. Found on production on 28 Nov 2026.
--
-- Migration 232 meant to block relationship writes (sending, accepting) by
-- restricted accounts while lifecycle updates stay possible ("expiry workers
-- have no auth.uid()"). Expiring a pending interest is such a lifecycle update:
-- it only ends contact. So the guard now lets exactly that transition through
-- (pending -> expired, nothing else on the row changed), whoever the actor is.
-- Every other write by a deleted or banned actor is still rejected.

CREATE OR REPLACE FUNCTION private.guard_interest_actor_standing()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_actor uuid := auth.uid();
BEGIN
  IF v_actor IS NULL THEN
    RETURN NEW;
  END IF;

  -- Lifecycle: a pending interest may always expire (account deletion,
  -- blocking, expiry). Nothing else on the row may change with it.
  IF TG_OP = 'UPDATE'
     AND OLD.status = 'pending'
     AND NEW.status = 'expired'
     AND (to_jsonb(NEW) - 'status' - 'responded_at') = (to_jsonb(OLD) - 'status' - 'responded_at') THEN
    RETURN NEW;
  END IF;

  PERFORM private.assert_active_member(
    v_actor,
    TG_OP = 'INSERT' AND v_actor = NEW.sender_id
  );
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.guard_interest_actor_standing()
  FROM PUBLIC, anon, authenticated;
