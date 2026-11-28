"use server";

import { createHash } from "node:crypto";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { z } from "zod";
import { requireStaffSession } from "@/lib/auth";
import { adminSiteUrl, allowPasswordSetup, clearPasswordSetup, passwordSetupFor } from "@/lib/staff-access";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

// ---------------------------------------------------------------------------
// Opening an emailed invite or reset link (migration 342). The GET page only
// shows a button; the token is used here, once, on a deliberate click.
// ---------------------------------------------------------------------------

export async function acceptStaffLink(formData: FormData) {
  const token = String(formData.get("token") ?? "");
  if (!/^[0-9a-f]{64}$/.test(token)) redirect("/auth/accept?state=invalid");

  const service = createAdminClient();
  const { data, error } = await service.rpc("consume_staff_access_token", { p_token: token });
  const row = (data as { user_id: string; email: string; kind: "invite" | "reset" }[] | null)?.[0];
  if (error || !row?.email) redirect("/auth/accept?state=invalid");

  // Sign this person in: a one-time sign-in link made and used here, never
  // emailed. Any other admin session in this browser is replaced.
  const { data: link, error: linkError } = await service.auth.admin.generateLink({
    type: "magiclink",
    email: row.email,
  });
  const tokenHash = link?.properties?.hashed_token;
  if (linkError || !tokenHash) redirect("/auth/accept?state=unavailable");

  const supabase = await createClient();
  await supabase.auth.signOut({ scope: "local" }).catch(() => undefined);
  const { data: verified, error: verifyError } = await supabase.auth.verifyOtp({ type: "email", token_hash: tokenHash });
  if (verifyError || verified.user?.id !== row.user_id) redirect("/auth/accept?state=unavailable");

  await allowPasswordSetup(row.user_id, row.kind);
  redirect("/auth/set-password");
}

const passwordSchema = z.object({
  password: z.string()
    .min(12, "Use at least 12 characters.")
    .max(72, "Use at most 72 characters.")
    .refine((value) => /[a-z]/i.test(value) && /\d/.test(value), "Use letters and at least one number."),
  confirm: z.string(),
}).refine((value) => value.password === value.confirm, { message: "The two passwords do not match.", path: ["confirm"] });

export async function setStaffPassword(formData: FormData) {
  const admin = await requireStaffSession();
  const kind = await passwordSetupFor(admin.id);
  if (!kind) redirect("/auth/accept?state=invalid");

  const parsed = passwordSchema.safeParse({
    password: String(formData.get("password") ?? ""),
    confirm: String(formData.get("confirm") ?? ""),
  });
  if (!parsed.success) {
    redirect(`/auth/set-password?error=${encodeURIComponent(parsed.error.issues[0]?.message ?? "Check the password.")}`);
  }

  const service = createAdminClient();
  const { error } = await service.auth.admin.updateUserById(admin.id, { password: parsed.data.password });
  if (error) {
    const weak = /weak|pwned|leaked|characters/i.test(error.message);
    redirect(`/auth/set-password?error=${encodeURIComponent(weak
      ? "That password is too easy to guess. Choose a longer one."
      : "The password could not be saved. Please try again.")}`);
  }
  await clearPasswordSetup();
  // Next: set up or confirm the authenticator.
  redirect("/mfa");
}

// ---------------------------------------------------------------------------
// "Forgot password" on the sign-in page. Same throttle as sign-in; the answer
// never says whether the address belongs to staff.
// ---------------------------------------------------------------------------

function hashValue(value: string) {
  const salt = process.env.ADMIN_LOGIN_HASH_SALT ?? process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!salt) throw new Error("Admin login hash salt is not configured.");
  return createHash("sha256").update(`${salt}:${value.toLowerCase().trim()}`).digest("hex");
}

export async function requestStaffPasswordReset(formData: FormData) {
  const email = z.string().trim().toLowerCase().email().max(320).safeParse(formData.get("email"));
  if (!email.success) redirect("/forgot-password?error=email");

  const service = createAdminClient();
  try {
    const headerStore = await headers();
    const { data: attempt, error: attemptError } = await service.rpc("begin_admin_login_attempt", {
      p_email_hash: hashValue(email.data),
      p_ip_hash: hashValue(headerStore.get("cf-connecting-ip") ?? "unavailable"),
    });
    if (attemptError || typeof attempt !== "string") redirect("/forgot-password?error=busy");
    await service.rpc("request_staff_password_reset", { p_email: email.data, p_base_url: adminSiteUrl() });
    await service.rpc("finish_admin_login_attempt", { p_attempt_id: attempt, p_success: true, p_reason: "password_reset_requested" });
  } catch (error) {
    if (error instanceof Error && error.message === "NEXT_REDIRECT") throw error;
    if (typeof error === "object" && error && "digest" in error) throw error;
    redirect("/forgot-password?error=busy");
  }
  redirect("/forgot-password?sent=1");
}
