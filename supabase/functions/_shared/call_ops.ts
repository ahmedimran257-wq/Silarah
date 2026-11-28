// Shared steps for the `calls`, `stream-webhook` and `call-worker` functions.
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { sendDataPush } from "./fcm_push.ts";
import {
  connectedSecondsFromEvents,
  connectedSecondsFromSessions,
  getCall,
  isNotFound,
  markEnded,
  participantSessions,
  type RecordedEvent,
  type StreamConfig,
} from "./stream_video.ts";

export function adminClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
}

export async function rpc<T = Record<string, unknown>>(
  supabase: SupabaseClient,
  name: string,
  args: Record<string, unknown>,
): Promise<T> {
  const { data, error } = await supabase.rpc(name, args);
  if (error) throw new Error(`${name}: ${error.message}`);
  return data as T;
}

/** Options for {@link pushToUser}. */
export interface PushOptions {
  /** Skip this device (the one that just answered). */
  excludeDeviceId?: string | null;
  /** Only phones that reported they can ring (incoming-call pushes). */
  ringOnly?: boolean;
}

/**
 * Pushes a call signal to the devices of p_user (at most 5). Returns how
 * many devices accepted it. Dead tokens are removed.
 */
export async function pushToUser(
  supabase: SupabaseClient,
  userId: string,
  data: Record<string, string>,
  ttlSeconds: number,
  options: PushOptions = {},
): Promise<number> {
  const tokens = await rpc<{ fcm_token: string; device_id: string; can_ring: boolean }[]>(
    supabase,
    "call_service_device_tokens",
    { p_user: userId },
  );
  let sent = 0;
  await Promise.all((tokens ?? []).map(async (row) => {
    if (options.excludeDeviceId && row.device_id === options.excludeDeviceId) return;
    if (options.ringOnly && row.can_ring !== true) return;
    const result = await sendDataPush(row.fcm_token, { ...data, for_user: userId }, ttlSeconds);
    if (result === "sent") sent++;
    if (result === "invalid_token") {
      await supabase.from("user_fcm_tokens").delete().eq("fcm_token", row.fcm_token);
    }
  }));
  return sent;
}

/** Stream mark_ended, then record it. A call Stream no longer has counts as ended. */
export async function endOnStream(
  supabase: SupabaseClient,
  config: StreamConfig,
  requestId: string,
  streamCallId: string,
): Promise<void> {
  try {
    await markEnded(config, streamCallId);
  } catch (error) {
    if (!isNotFound(error) && !/already.*ended|has ended/i.test(String((error as Error).message))) {
      throw error;
    }
  }
  await rpc(supabase, "call_service_stream_end_confirmed", { p_request_id: requestId });
}

interface SessionInfo {
  both_joined_at: string | null;
  request_id: string;
  stream_call_id: string;
  caller_id: string;
  callee_id: string;
  status: string;
  ended_at: string | null;
  stream_session_id: string | null;
  events: RecordedEvent[];
}

export type SettleOutcome =
  | { done: true; charged?: number; connected?: number }
  | { done: false; retrySeconds: number; error: string };

/**
 * Settles one ended call from Stream's own record of who was connected when.
 * Our webhook log is used only if Stream's record stays unreadable.
 */
export async function settleCall(
  supabase: SupabaseClient,
  config: StreamConfig,
  requestId: string,
  attempt: number,
): Promise<SettleOutcome> {
  const info = await rpc<SessionInfo | null>(supabase, "call_service_session_info", {
    p_request_id: requestId,
  });
  if (!info) return { done: true };
  if (info.status === "settled" || info.status === "failed") return { done: true };
  if (info.status !== "ended") {
    return { done: false, retrySeconds: 15, error: `not_ended:${info.status}` };
  }

  // Charging 0 is only ever right when nobody joined. Any sign that a
  // member joined (our webhook log or Stream's own join time) means the
  // call is charged from a real record, never waved through as free.
  const someoneJoined = info.events.some((event) => event.kind === "joined") ||
    info.both_joined_at != null;
  const fromWebhookLog = () =>
    connectedSecondsFromEvents(info.events, info.caller_id, info.callee_id, info.ended_at);

  let connected: number | null = null;
  let source = "stream_participant_sessions";
  let sessionId = info.stream_session_id;
  try {
    const snapshot = await getCall(config, info.stream_call_id);
    sessionId = snapshot.sessionId ?? sessionId;
    if (sessionId) {
      const sessions = await participantSessions(config, info.stream_call_id, sessionId);
      connected = connectedSecondsFromSessions(sessions, info.caller_id, info.callee_id);
      if (connected === null) {
        return { done: false, retrySeconds: 10, error: "participant_still_connected" };
      }
      // Stream's record and ours should agree; if Stream lists no shared
      // time while our log shows both joined, charge from the log.
      const logged = someoneJoined ? fromWebhookLog() : 0;
      if (connected === 0 && logged != null && logged > 0) {
        connected = logged;
        source = "webhook_log";
      }
    } else if (!someoneJoined) {
      // Stream never opened a session and no member ever joined.
      connected = 0;
      source = "stream_no_session";
    } else {
      throw new Error("stream_session_unknown");
    }
  } catch (error) {
    if (!someoneJoined && isNotFound(error)) {
      connected = 0;
      source = "stream_call_missing";
    } else if (attempt >= 12) {
      // Stream's record stays unreadable: use our own signed webhook log.
      // Held minutes stay held until it can settle (never under-charged).
      connected = someoneJoined ? fromWebhookLog() : 0;
      source = "webhook_log";
      if (connected === null) {
        return { done: false, retrySeconds: 120, error: String((error as Error).message) };
      }
    } else {
      return { done: false, retrySeconds: 15, error: String((error as Error).message) };
    }
  }

  const result = await rpc<{ outcome: string; charged_minutes?: number }>(
    supabase,
    "call_service_settle",
    {
      p_request_id: requestId,
      p_connected_seconds: connected,
      p_source: source,
      p_stream_session_id: sessionId,
    },
  );
  if (result.outcome === "not_ended") {
    return { done: false, retrySeconds: 15, error: "not_ended" };
  }
  return { done: true, charged: result.charged_minutes, connected: connected ?? 0 };
}

const REJOIN_GRACE_MS = 8_000;

/** A member left: end the call unless Stream shows them connected again. */
export async function endIfMemberGone(
  supabase: SupabaseClient,
  config: StreamConfig,
  requestId: string,
): Promise<void> {
  const info = await rpc<SessionInfo | null>(supabase, "call_service_session_info", {
    p_request_id: requestId,
  });
  if (!info || !["creating", "active"].includes(info.status)) return;
  // A phone that drops off Wi-Fi rejoins with a new Stream session within
  // seconds. Decide only after it has had the chance to come back.
  await new Promise((resolve) => setTimeout(resolve, REJOIN_GRACE_MS));
  let bothLive = false;
  try {
    const snapshot = await getCall(config, info.stream_call_id);
    bothLive = snapshot.liveUserIds.includes(info.caller_id) &&
      snapshot.liveUserIds.includes(info.callee_id);
  } catch (error) {
    if (!isNotFound(error)) throw error;
  }
  if (bothLive) return;
  const ended = await rpc<{ stream_call_id: string | null }>(
    supabase,
    "call_service_system_end",
    { p_request_id: requestId, p_reason: "member_left" },
  );
  if (ended.stream_call_id) {
    await endOnStream(supabase, config, requestId, ended.stream_call_id);
  }
}

export const jsonHeaders = { "Content-Type": "application/json" };

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}
