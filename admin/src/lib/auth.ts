import "server-only";

import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { canAccess, type AdminRole, type Area, type QueueCounts } from "@/lib/access";

export type { AdminRole } from "@/lib/access";

export type CurrentAdmin = {
  id: string;
  email: string;
  role: AdminRole;
  mfaRequired: boolean;
  aal: string;
  hasVerifiedTotp: boolean;
  counts: QueueCounts;
};

type ConsoleContext =
  | { allowed: false; reason?: "session" | "not_staff" }
  | {
      allowed: true;
      adminId: string;
      email: string | null;
      role: AdminRole;
      mfaRequired: boolean;
      aal: string;
      hasVerifiedTotp: boolean;
      counts?: QueueCounts;
    };

// One database round trip per request answers the session boundary,
// membership, MFA state and navigation counts. The cookie's access token is
// only used to read its session_id; PostgREST verifies the token itself, so
// the identity and claims returned here come from a verified JWT. cache()
// shares the result between the layout, the page and any nested reads.
const loadStaffContext = cache(async () => {
  const supabase = await createClient();
  const { data: { session } } = await supabase.auth.getSession();
  const sessionId = session?.access_token
    ? decodeJwtPayload(session.access_token)?.session_id
    : undefined;
  if (!sessionId) return { supabase, signedIn: Boolean(session), context: null };

  const { data, error } = await supabase.rpc("admin_console_context", {
    p_session_id: sessionId,
  });
  if (error) throw new Error("Staff session could not be verified.");
  return { supabase, signedIn: true, context: data as ConsoleContext };
});

export async function requireStaffSession(): Promise<CurrentAdmin> {
  const { supabase, signedIn, context } = await loadStaffContext();
  if (!signedIn) redirect("/login");

  if (!context?.allowed) {
    // Local scope: end only this browser's admin session. The default
    // (global) also revoked the same account's sessions in the Silarah app,
    // which left the owner's phone with a dead session and no photos.
    await supabase.auth.signOut({ scope: "local" });
    if (context?.reason === "not_staff") redirect("/unauthorized");
    redirect("/login?error=Session+expired.+Please+sign+in+again.");
  }

  return {
    id: context.adminId,
    email: context.email ?? "Staff account",
    role: context.role,
    mfaRequired: context.mfaRequired,
    aal: context.aal,
    hasVerifiedTotp: context.hasVerifiedTotp,
    counts: context.counts ?? {},
  };
}

function decodeJwtPayload(token: string): { session_id?: string } | undefined {
  try {
    const payload = token.split(".")[1];
    if (!payload) return undefined;
    return JSON.parse(
      Buffer.from(payload.replace(/-/g, "+").replace(/_/g, "/"), "base64")
        .toString("utf8"),
    ) as { session_id?: string };
  } catch {
    return undefined;
  }
}

// Every privileged RPC requires AAL2 (is_active_admin), so a session without
// it can only reach the MFA step, whatever mfa_required says.
export const requireAdmin = cache(async (): Promise<CurrentAdmin> => {
  const admin = await requireStaffSession();
  if (!admin.hasVerifiedTotp || admin.aal !== "aal2") redirect("/mfa");
  return admin;
});

// allowed is false when the role cannot use this area, so the page can render
// a calm "not available" state inside the console instead of an error.
export async function requireArea(area: Area) {
  const admin = await requireAdmin();
  return { admin, allowed: canAccess(admin.role, area) };
}
