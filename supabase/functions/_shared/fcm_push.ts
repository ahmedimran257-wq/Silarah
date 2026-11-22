// Data-only FCM messages for calling (ring, cancel, answered).
//
// Same Firebase service account and OAuth flow as dispatch-notifications.
// Call pushes carry NO `notification` block: the app's background handler
// draws the incoming-call notification itself (Answer / Decline) and checks
// that the push is for the account signed in on that phone.

const FIREBASE_SERVICE_ACCOUNT_B64 = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_B64");
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const TIMEOUT_MS = 8_000;

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

let cachedToken: string | null = null;
let cachedUntil = 0;

function readServiceAccount(): ServiceAccount {
  const encoded = FIREBASE_SERVICE_ACCOUNT_B64?.trim();
  const serialized = encoded
    ? new TextDecoder().decode(Uint8Array.from(atob(encoded), (c) => c.charCodeAt(0)))
    : FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!serialized) throw new Error("fcm_not_configured");
  const parsed = JSON.parse(serialized) as Partial<ServiceAccount>;
  if (
    !parsed.client_email || !parsed.private_key ||
    parsed.project_id !== FIREBASE_PROJECT_ID
  ) throw new Error("fcm_service_account_invalid");
  return parsed as ServiceAccount;
}

function b64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function accessToken(): Promise<string> {
  const now = Date.now();
  if (cachedToken && now < cachedUntil) return cachedToken;
  const account = readServiceAccount();
  const iat = Math.floor(now / 1000);
  const enc = new TextEncoder();
  const input = `${b64url(enc.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })))}.${
    b64url(enc.encode(JSON.stringify({
      iss: account.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat,
      exp: iat + 3600,
    })))
  }`;
  const der = Uint8Array.from(
    atob(account.private_key.replace(/-----[A-Z ]+-----/g, "").replace(/\s+/g, "")),
    (c) => c.charCodeAt(0),
  );
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, enc.encode(input));
  const response = await fetchWithTimeout("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${input}.${
      b64url(new Uint8Array(signature))
    }`,
  });
  if (!response.ok) throw new Error(`google_oauth_${response.status}`);
  const data = await response.json();
  cachedToken = data.access_token;
  cachedUntil = now + (Number(data.expires_in ?? 3600) - 60) * 1000;
  return cachedToken!;
}

async function fetchWithTimeout(url: string, init: RequestInit): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

export type PushResult = "sent" | "invalid_token" | "failed";

/** Sends one data-only, high-priority message. Values must be strings. */
export async function sendDataPush(
  token: string,
  data: Record<string, string>,
  ttlSeconds: number,
): Promise<PushResult> {
  try {
    const response = await fetchWithTimeout(
      `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${await accessToken()}`,
        },
        body: JSON.stringify({
          message: {
            token,
            data,
            android: { priority: "high", ttl: `${Math.max(1, ttlSeconds)}s` },
          },
        }),
      },
    );
    if (response.ok) return "sent";
    const text = (await response.text()).slice(0, 2000);
    if (response.status === 404 || text.includes("UNREGISTERED")) return "invalid_token";
    return "failed";
  } catch {
    return "failed";
  }
}
