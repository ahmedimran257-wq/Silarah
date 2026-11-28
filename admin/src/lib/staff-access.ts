import "server-only";

import { createHmac, timingSafeEqual } from "node:crypto";
import { cookies } from "next/headers";

// The site the emailed links point at. Production is admin.silarah.com; the
// staging admin and local dev set NEXT_PUBLIC_ADMIN_SITE_URL to their own.
export function adminSiteUrl() {
  if (process.env.NEXT_PUBLIC_ADMIN_SITE_URL) {
    return process.env.NEXT_PUBLIC_ADMIN_SITE_URL.replace(/\/$/, "");
  }
  if (process.env.NODE_ENV !== "production") return "http://localhost:3001";
  throw new Error("NEXT_PUBLIC_ADMIN_SITE_URL is required before staff links can be sent.");
}

// After someone opens an invite or reset link, this signed cookie lets that
// one person choose a password for 30 minutes. Nothing else can reach the
// password page.
const passwordCookie = "silarah_admin_password_setup";
const passwordCookieSeconds = 30 * 60;

function secret() {
  const value = process.env.ADMIN_MFA_COOKIE_SECRET ?? process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!value) throw new Error("Staff link cookie secret is not configured.");
  return value;
}

function sign(payload: string) {
  return createHmac("sha256", secret()).update(`password-setup:${payload}`).digest("base64url");
}

export async function allowPasswordSetup(userId: string, kind: "invite" | "reset") {
  const payload = Buffer.from(JSON.stringify({ userId, kind, exp: Date.now() + passwordCookieSeconds * 1000 })).toString("base64url");
  const store = await cookies();
  store.set(passwordCookie, `${payload}.${sign(payload)}`, {
    httpOnly: true,
    maxAge: passwordCookieSeconds,
    path: "/auth",
    sameSite: "strict",
    secure: process.env.NODE_ENV === "production",
  });
}

export async function passwordSetupFor(userId: string): Promise<"invite" | "reset" | null> {
  const store = await cookies();
  const raw = store.get(passwordCookie)?.value;
  if (!raw) return null;
  const [payload, signature] = raw.split(".");
  if (!payload || !signature) return null;
  const expected = Buffer.from(sign(payload));
  const actual = Buffer.from(signature);
  if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) return null;
  try {
    const value = JSON.parse(Buffer.from(payload, "base64url").toString("utf8")) as { userId?: string; kind?: string; exp?: number };
    if (value.userId !== userId || typeof value.exp !== "number" || value.exp < Date.now()) return null;
    return value.kind === "invite" ? "invite" : "reset";
  } catch {
    return null;
  }
}

export async function clearPasswordSetup() {
  const store = await cookies();
  store.delete({ name: passwordCookie, path: "/auth" });
}
