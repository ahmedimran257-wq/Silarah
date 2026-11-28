// Stream Video server-side REST client (no SDK).
//
// Verified against Stream's OpenAPI (GetStream/protocol serverside-api.json,
// 22 Nov 2026): base https://video.stream-io-api.com/api/v2, `api_key` query
// parameter, server JWT {server: true} (HS256 with the API secret) in the
// Authorization header with `stream-auth-type: jwt`.
//
// The API key and secret live only in Supabase secrets STREAM_API_KEY and
// STREAM_API_SECRET and are never returned to a client.

export const CALL_TYPE = "silarah_voice";
const BASE_URL = "https://video.stream-io-api.com/api/v2";
const TIMEOUT_MS = 8_000;

export interface StreamConfig {
  apiKey: string;
  apiSecret: string;
}

export function streamConfigFromEnv(): StreamConfig | null {
  const apiKey = Deno.env.get("STREAM_API_KEY")?.trim() ?? "";
  const apiSecret = Deno.env.get("STREAM_API_SECRET")?.trim() ?? "";
  if (apiKey.length < 6 || apiSecret.length < 16) return null;
  return { apiKey, apiSecret };
}

function base64url(bytes: Uint8Array<ArrayBuffer>): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function hmacKey(secret: string, usage: KeyUsage[]): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    usage,
  );
}

export async function signJwt(
  payload: Record<string, unknown>,
  secret: string,
): Promise<string> {
  const header = base64url(
    new TextEncoder().encode(JSON.stringify({ alg: "HS256", typ: "JWT" })),
  );
  const body = base64url(new TextEncoder().encode(JSON.stringify(payload)));
  const input = `${header}.${body}`;
  const signature = await crypto.subtle.sign(
    "HMAC",
    await hmacKey(secret, ["sign"]),
    new TextEncoder().encode(input),
  );
  return `${input}.${base64url(new Uint8Array(signature))}`;
}

/** Member token for one hour (spec 4). */
export async function userToken(
  config: StreamConfig,
  userId: string,
  ttlSeconds = 3600,
): Promise<{ token: string; expiresAt: number }> {
  const iat = Math.floor(Date.now() / 1000) - 5;
  const exp = iat + ttlSeconds;
  return {
    token: await signJwt({ user_id: userId, iat, exp }, config.apiSecret),
    expiresAt: exp,
  };
}

async function serverToken(config: StreamConfig): Promise<string> {
  const iat = Math.floor(Date.now() / 1000) - 5;
  return await signJwt(
    { server: true, iat, exp: iat + 300 },
    config.apiSecret,
  );
}

export class StreamError extends Error {
  constructor(
    readonly status: number,
    readonly code: number | null,
    message: string,
  ) {
    super(message);
  }
}

export async function streamRequest<T = Record<string, unknown>>(
  config: StreamConfig,
  method: "GET" | "POST" | "PUT" | "PATCH" | "DELETE",
  path: string,
  body?: unknown,
  query: Record<string, string> = {},
): Promise<T> {
  return await streamRequestAs<T>(config, await serverToken(config), method, path, body, query);
}

/**
 * Same request with a chosen identity: a member's token, or null for an
 * anonymous request carrying only the public API key (used by the staging
 * gate probe to prove what members and strangers cannot do).
 */
export async function streamRequestAs<T = Record<string, unknown>>(
  config: StreamConfig,
  authToken: string | null,
  method: "GET" | "POST" | "PUT" | "PATCH" | "DELETE",
  path: string,
  body?: unknown,
  query: Record<string, string> = {},
): Promise<T> {
  const url = new URL(BASE_URL + path);
  url.searchParams.set("api_key", config.apiKey);
  for (const [key, value] of Object.entries(query)) {
    url.searchParams.set(key, value);
  }
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const response = await fetch(url, {
      method,
      headers: authToken
        ? {
          "Authorization": authToken,
          "stream-auth-type": "jwt",
          "Content-Type": "application/json",
        }
        : { "stream-auth-type": "anonymous", "Content-Type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: controller.signal,
    });
    const text = await response.text();
    let parsed: Record<string, unknown> = {};
    try {
      parsed = text ? JSON.parse(text) : {};
    } catch {
      parsed = {};
    }
    if (!response.ok) {
      // Stream error bodies carry a numeric `code` and a `message`; never
      // echo request headers or secrets.
      throw new StreamError(
        response.status,
        typeof parsed.code === "number" ? parsed.code : null,
        String(parsed.message ?? `stream_http_${response.status}`).slice(0, 300),
      );
    }
    return parsed as T;
  } finally {
    clearTimeout(timer);
  }
}

export function isNotFound(error: unknown): boolean {
  return error instanceof StreamError &&
    (error.status === 404 || error.code === 16 ||
      /not.?found|does not exist|doesn't exist/i.test(error.message));
}

export interface StreamMember {
  id: string;
  name: string;
}

/** Stream user = Silarah user ID + first name and initial only (spec 7). */
export async function upsertUsers(
  config: StreamConfig,
  members: StreamMember[],
): Promise<void> {
  const users: Record<string, unknown> = {};
  for (const member of members) {
    users[member.id] = { id: member.id, name: member.name, role: "user" };
  }
  await streamRequest(config, "POST", "/users", { users });
}

export async function createCall(
  config: StreamConfig,
  callId: string,
  createdBy: string,
  memberIds: string[],
  maxDurationSeconds: number,
): Promise<void> {
  await streamRequest(config, "POST", `/video/call/${CALL_TYPE}/${callId}`, {
    ring: false,
    notify: false,
    video: false,
    data: {
      created_by_id: createdBy,
      members: memberIds.map((userId) => ({ user_id: userId, role: "call_member" })),
      settings_override: {
        limits: {
          max_duration_seconds: maxDurationSeconds,
          max_participants: 2,
        },
      },
    },
  });
}

export async function setMaxDuration(
  config: StreamConfig,
  callId: string,
  maxDurationSeconds: number,
): Promise<void> {
  await streamRequest(config, "PATCH", `/video/call/${CALL_TYPE}/${callId}`, {
    settings_override: { limits: { max_duration_seconds: maxDurationSeconds } },
  });
}

export async function markEnded(config: StreamConfig, callId: string): Promise<void> {
  await streamRequest(config, "POST", `/video/call/${CALL_TYPE}/${callId}/mark_ended`, {});
}

export interface StreamCallSnapshot {
  sessionId: string | null;
  startedAt: string | null;
  endedAt: string | null;
  callEndedAt: string | null;
  liveUserIds: string[];
}

export async function getCall(
  config: StreamConfig,
  callId: string,
): Promise<StreamCallSnapshot> {
  const response = await streamRequest<{
    call?: {
      ended_at?: string | number | null;
      current_session_id?: string | null;
      session?: {
        id?: string;
        started_at?: string | number | null;
        ended_at?: string | number | null;
        participants?: { user?: { id?: string } }[];
      } | null;
    };
  }>(config, "GET", `/video/call/${CALL_TYPE}/${callId}`);
  const session = response.call?.session ?? null;
  // After a call ends Stream drops the live `session` block; the session ID
  // stays on the call as current_session_id (seen on staging, 22 Nov).
  const sessionId = (session?.id || response.call?.current_session_id) ?? null;
  return {
    sessionId: sessionId || null,
    startedAt: toIso(session?.started_at),
    endedAt: toIso(session?.ended_at),
    callEndedAt: toIso(response.call?.ended_at),
    liveUserIds: (session?.participants ?? [])
      .map((participant) => participant.user?.id)
      .filter((id): id is string => typeof id === "string"),
  };
}

export interface ParticipantSession {
  user_id: string;
  // Stream's server API returns these as nanoseconds since 1970 (numbers);
  // other endpoints and webhooks use RFC 3339 strings. Both are accepted.
  joined_at?: string | number | null;
  left_at?: string | number | null;
  duration_in_seconds?: number | null;
}

/**
 * Milliseconds since 1970 from a Stream time: an RFC 3339 string, or a
 * number (or numeric string) in seconds, ms, microseconds or nanoseconds.
 */
export function streamTimeMs(value: unknown): number {
  if (value == null || value === "") return NaN;
  const numeric = typeof value === "number"
    ? value
    : /^\d+(\.\d+)?$/.test(String(value))
    ? Number(value)
    : NaN;
  if (Number.isFinite(numeric)) {
    if (numeric > 1e17) return numeric / 1e6; // nanoseconds
    if (numeric > 1e14) return numeric / 1e3; // microseconds
    if (numeric > 1e11) return numeric; // milliseconds
    return numeric * 1000; // seconds
  }
  return Date.parse(String(value));
}

function toIso(value: unknown): string | null {
  const ms = streamTimeMs(value);
  return Number.isFinite(ms) ? new Date(ms).toISOString() : null;
}

/** Every join/leave of a finished session (QueryCallParticipantSessions). */
export async function participantSessions(
  config: StreamConfig,
  callId: string,
  sessionId: string,
): Promise<ParticipantSession[]> {
  const result: ParticipantSession[] = [];
  let next: string | undefined;
  for (let page = 0; page < 10; page++) {
    const query: Record<string, string> = { limit: "100" };
    if (next) query.next = next;
    const response = await streamRequest<{
      participants_sessions?: ParticipantSession[];
      next?: string;
    }>(
      config,
      "GET",
      `/video/call/${CALL_TYPE}/${callId}/session/${encodeURIComponent(sessionId)}/participant_sessions`,
      undefined,
      query,
    );
    result.push(...(response.participants_sessions ?? []));
    if (!response.next) break;
    next = response.next;
  }
  return result;
}

export async function deleteUser(config: StreamConfig, userId: string): Promise<void> {
  await streamRequest(config, "POST", "/users/delete", {
    user_ids: [userId],
    user: "hard",
    messages: "hard",
    conversations: "hard",
    calls: "hard",
  });
}

// ---------------------------------------------------------------------------
// Call type lockdown (spec 7)
// ---------------------------------------------------------------------------

// Exactly the spec 7 grants. (read-call is added only if Stream proves the
// app cannot join without it; see the staging gate log.)
export const CALL_MEMBER_GRANTS = ["join-call", "send-audio", "end-call"];

/** Capabilities nobody may hold on silarah_voice. */
export const FORBIDDEN_CAPABILITIES = [
  "create-call",
  "send-video",
  "screenshare",
  "change-max-duration",
  "update-call",
  "update-call-settings",
  "update-call-permissions",
  "update-call-member",
  "join-ended-call",
  "join-backstage",
  "start-record-call",
  "start-individual-record-call",
  "start-raw-record-call",
  "start-frame-record-call",
  "start-transcription-call",
  "start-closed-captions-call",
  "start-broadcast-call",
  "remove-call-member",
  "block-users",
  "kick-user",
  "mute-users",
  "pin-for-everyone",
  "send-closed-captions-call",
];

/**
 * Settings the Flutter client (stream_video 1.6.0) must find set to one of
 * these values in every join reply, or it cannot read the call and the
 * join fails. Checked against the live call type by the staging probe.
 */
export const CLIENT_REQUIRED_CHOICES: Record<string, string[]> = {
  "audio.default_device": ["speaker", "earpiece"],
  "audio.noise_cancellation.mode": ["available", "disabled", "auto-on"],
  "encryption.mode": ["available", "disabled", "auto-on"],
  "frame_recording.mode": ["disabled", "auto-on"],
  "individual_recording.mode": ["available", "disabled", "auto-on"],
  "raw_recording.mode": ["available", "disabled", "auto-on"],
  "transcription.mode": ["disabled", "auto-on"],
  "transcription.closed_caption_mode": ["auto", "disabled", "auto-on"],
  "video.camera_facing": ["front", "back", "external"],
};

/** Paths in [settings] that the Flutter client could not read. */
export function unreadableClientSettings(settings: Record<string, unknown>): string[] {
  const bad: string[] = [];
  for (const [path, allowed] of Object.entries(CLIENT_REQUIRED_CHOICES)) {
    let value: unknown = settings;
    for (const key of path.split(".")) {
      value = value && typeof value === "object" ? (value as Record<string, unknown>)[key] : undefined;
    }
    if (typeof value !== "string" || !allowed.includes(value)) bad.push(`${path}=${JSON.stringify(value)}`);
  }
  return bad;
}

export function voiceCallTypeBody() {
  return {
    grants: {
      // Signed-in members may do nothing on their own: no create, no join.
      user: [] as string[],
      call_member: CALL_MEMBER_GRANTS,
      // Stream ships `guest` with join-call / send-audio / send-video, and a
      // guest can be created with the public API key alone. Nothing for it.
      guest: [] as string[],
    },
    settings: {
      audio: {
        default_device: "earpiece",
        mic_default_on: true,
        speaker_default_on: false,
        access_request_enabled: false,
        opus_dtx_enabled: true,
        redundant_coding_enabled: true,
      },
      // Stream requires a resolution even with video off; use its minimum.
      video: {
        enabled: false,
        camera_default_on: false,
        access_request_enabled: false,
        target_resolution: { width: 240, height: 240 },
        // The Flutter client refuses a join whose settings leave this empty
        // (seen on device 22 Nov), even with video off.
        camera_facing: "front",
      },
      screensharing: {
        enabled: false,
        access_request_enabled: false,
        target_resolution: { width: 240, height: 240 },
      },
      // No recording, ever (spec 8): every recording kind and RTMP/WHIP
      // ingress are off, not merely "available".
      recording: { mode: "disabled", audio_only: true },
      frame_recording: { mode: "disabled", capture_interval_in_seconds: 3 },
      individual_recording: { mode: "disabled" },
      raw_recording: { mode: "disabled" },
      ingress: { enabled: false },
      // An ended call can never be joined again.
      lifecycle: { mode: "single_use" },
      transcription: { mode: "disabled", closed_caption_mode: "disabled" },
      backstage: { enabled: false },
      broadcasting: { enabled: false },
      session: { inactivity_timeout_seconds: 30 },
      // Each call overrides this with hold + 30 s; the type default is the
      // longest single hold (60 min + 30 s) so no call can run unbounded.
      limits: { max_participants: 2, max_duration_seconds: 3630 },
    },
    notification_settings: {
      enabled: false,
      call_notification: { enabled: false },
      call_ring: { enabled: false },
      call_live_started: { enabled: false },
      call_missed: { enabled: false },
      session_started: { enabled: false },
    },
  };
}

// ---------------------------------------------------------------------------
// Webhook verification (spec 5)
// ---------------------------------------------------------------------------

export const MAX_WEBHOOK_BYTES = 10 * 1024 * 1024;

export function isGzip(bytes: Uint8Array<ArrayBuffer>): boolean {
  return bytes.length >= 2 && bytes[0] === 0x1f && bytes[1] === 0x8b;
}

export async function gunzip(bytes: Uint8Array<ArrayBuffer>, limit = MAX_WEBHOOK_BYTES): Promise<Uint8Array<ArrayBuffer>> {
  const stream = new Blob([bytes]).stream().pipeThrough(
    new DecompressionStream("gzip"),
  );
  const reader = stream.getReader();
  const chunks: Uint8Array<ArrayBuffer>[] = [];
  let total = 0;
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > limit) {
      await reader.cancel();
      throw new Error("webhook_body_too_large");
    }
    chunks.push(value);
  }
  const out = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    out.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return out;
}

function hex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function constantTimeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index++) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

/** HMAC-SHA256 (hex) of the UNCOMPRESSED raw body, keyed with the API secret. */
export async function webhookSignature(body: Uint8Array<ArrayBuffer>, secret: string): Promise<string> {
  return hex(
    await crypto.subtle.sign("HMAC", await hmacKey(secret, ["sign"]), body),
  );
}

export async function verifyWebhook(
  rawBody: Uint8Array<ArrayBuffer>,
  signatureHeader: string | null,
  secret: string,
): Promise<{ ok: true; body: Uint8Array<ArrayBuffer> } | { ok: false; reason: string }> {
  if (!signatureHeader) return { ok: false, reason: "missing_signature" };
  if (rawBody.byteLength > MAX_WEBHOOK_BYTES) return { ok: false, reason: "too_large" };
  let body = rawBody;
  if (isGzip(rawBody)) {
    try {
      body = await gunzip(rawBody);
    } catch {
      return { ok: false, reason: "bad_gzip" };
    }
  }
  const expected = await webhookSignature(body, secret);
  if (!constantTimeEqual(expected, signatureHeader.trim().toLowerCase())) {
    return { ok: false, reason: "bad_signature" };
  }
  return { ok: true, body };
}

// ---------------------------------------------------------------------------
// Talk time: seconds BOTH members were connected (spec 5)
// ---------------------------------------------------------------------------

type Interval = [number, number];

function union(intervals: Interval[]): Interval[] {
  const sorted = intervals
    .filter(([start, end]) => Number.isFinite(start) && Number.isFinite(end) && end > start)
    .sort((a, b) => a[0] - b[0]);
  const out: Interval[] = [];
  for (const [start, end] of sorted) {
    const last = out[out.length - 1];
    if (last && start <= last[1]) last[1] = Math.max(last[1], end);
    else out.push([start, end]);
  }
  return out;
}

export function overlapSeconds(a: Interval[], b: Interval[]): number {
  const left = union(a);
  const right = union(b);
  let i = 0;
  let j = 0;
  let totalMs = 0;
  while (i < left.length && j < right.length) {
    const start = Math.max(left[i][0], right[j][0]);
    const end = Math.min(left[i][1], right[j][1]);
    if (end > start) totalMs += end - start;
    if (left[i][1] < right[j][1]) i++;
    else j++;
  }
  return Math.ceil(totalMs / 1000);
}

/**
 * Talk time from Stream's participant sessions. Returns null while a member
 * is still connected (no left_at) so the caller retries later.
 */
export function connectedSecondsFromSessions(
  sessions: ParticipantSession[],
  callerId: string,
  calleeId: string,
): number | null {
  const byUser = new Map<string, Interval[]>();
  for (const session of sessions) {
    if (session.user_id !== callerId && session.user_id !== calleeId) continue;
    const joined = streamTimeMs(session.joined_at);
    if (!Number.isFinite(joined)) continue;
    if (session.left_at == null || session.left_at === "") return null;
    const left = streamTimeMs(session.left_at);
    if (!Number.isFinite(left)) return null;
    const list = byUser.get(session.user_id) ?? [];
    list.push([joined, left]);
    byUser.set(session.user_id, list);
  }
  return overlapSeconds(byUser.get(callerId) ?? [], byUser.get(calleeId) ?? []);
}

export interface RecordedEvent {
  user_id: string;
  kind: "joined" | "left";
  at: string;
  duration_seconds: number | null;
}

/** Backup when Stream's record cannot be read: our own webhook log. */
export function connectedSecondsFromEvents(
  events: RecordedEvent[],
  callerId: string,
  calleeId: string,
  endedAt: string | null,
): number | null {
  const intervals = new Map<string, Interval[]>();
  const open = new Map<string, number>();
  const end = streamTimeMs(endedAt);
  for (const event of events) {
    const at = streamTimeMs(event.at);
    if (!Number.isFinite(at)) continue;
    if (event.kind === "joined") {
      if (!open.has(event.user_id)) open.set(event.user_id, at);
    } else {
      const start = open.get(event.user_id) ??
        (event.duration_seconds != null ? at - event.duration_seconds * 1000 : NaN);
      open.delete(event.user_id);
      const list = intervals.get(event.user_id) ?? [];
      list.push([start, at]);
      intervals.set(event.user_id, list);
    }
  }
  for (const [userId, start] of open) {
    if (!Number.isFinite(end)) return null;
    const list = intervals.get(userId) ?? [];
    list.push([start, end]);
    intervals.set(userId, list);
  }
  if (!intervals.has(callerId) || !intervals.has(calleeId)) return 0;
  return overlapSeconds(intervals.get(callerId)!, intervals.get(calleeId)!);
}
