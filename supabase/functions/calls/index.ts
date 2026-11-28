// EDGE FUNCTION: calls
//
// The app's only door into voice calling (docs/voice_calling_spec.md 4).
// POST { action, ... } with the member's Supabase access token, except
// `decline_token`, which the incoming-call notification's Decline button
// sends without a session (it proves itself with a single-use token that
// reached only the callee's own devices), and `ring_delivered`, the ring's
// receipt from the callee's phone, proven with the same token.
//
//   start         { match_id }                -> ring the other member
//   status        { request_id }              -> ringing / connecting / active / ended
//   accept        { request_id, device_id }   -> hold minutes, create Stream call, token
//   join          { request_id }              -> token for an answered call
//   end           { request_id, reason }      -> cancel / decline / hang up
//   extend        { request_id }              -> add minutes to a live call (caller)
//   decline_token { request_id, token }       -> Decline from the notification
//   ring_delivered { request_id, token }      -> the callee's phone shows the ring
//
// Deployed with --no-verify-jwt; every action except decline_token and
// ring_delivered checks the access token itself through Supabase Auth.
import { createClient } from "@supabase/supabase-js";
import { corsHeaders } from "../_shared/cors.ts";
import { consumeDistributedRateLimit } from "../_shared/distributed_rate_limit.ts";
import { ringPhotoUrl } from "../_shared/call_photo.ts";
import {
  adminClient,
  endOnStream,
  pushToUser,
  rpc,
} from "../_shared/call_ops.ts";
import {
  CALL_TYPE,
  createCall,
  setMaxDuration,
  streamConfigFromEnv,
  upsertUsers,
  userToken,
} from "../_shared/stream_video.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function reply(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function authenticatedUserId(req: Request): Promise<string | null> {
  const header = req.headers.get("Authorization") ?? "";
  if (!header.startsWith("Bearer ")) return null;
  const client = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: { headers: { Authorization: header } },
      auth: { autoRefreshToken: false, persistSession: false },
    },
  );
  const { data, error } = await client.auth.getUser(header.slice(7));
  if (error || !data.user) return null;
  return data.user.id;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return reply({ error: "method_not_allowed" }, 405);

  let body: Record<string, unknown>;
  try {
    const text = await req.text();
    if (text.length > 4096) return reply({ error: "too_large" }, 413);
    body = JSON.parse(text);
  } catch {
    return reply({ error: "bad_request" }, 400);
  }
  const action = String(body.action ?? "");
  const requestId = typeof body.request_id === "string" ? body.request_id : "";
  const supabase = adminClient();
  const config = streamConfigFromEnv();
  if (!config) {
    console.error("[calls] Stream secrets are not configured.");
    return reply({ error: "calls_unavailable" }, 503);
  }

  try {
    if (action === "decline_token") {
      const token = typeof body.token === "string" ? body.token : "";
      if (!UUID.test(requestId) || !/^[0-9a-f]{48}$/.test(token)) {
        return reply({ outcome: "not_found" });
      }
      const limit = await consumeDistributedRateLimit(supabase, {
        scope: "call_decline_token",
        subject: requestId,
        maxRequests: 10,
        windowSeconds: 600,
      });
      if (!limit.allowed) return reply({ outcome: "not_found" });
      const result = await rpc<Record<string, unknown>>(supabase, "call_service_decline_with_token", {
        p_request_id: requestId,
        p_token: token,
      });
      if (result.outcome === "declined") {
        await signalDeclined(supabase, requestId, String(result.callee_id));
      }
      return reply({ outcome: result.outcome });
    }

    // 332: the ring reached the callee's phone. The caller's screen turns
    // "Calling…" into "Ringing…", and only a ring that arrived counts towards
    // the unanswered-call limit. Sent with Silarah closed too, so no session.
    if (action === "ring_delivered") {
      const token = typeof body.token === "string" ? body.token : "";
      if (!UUID.test(requestId) || !/^[0-9a-f]{48}$/.test(token)) {
        return reply({ outcome: "not_found" });
      }
      const limit = await consumeDistributedRateLimit(supabase, {
        scope: "call_ring_delivered",
        subject: requestId,
        maxRequests: 10,
        windowSeconds: 600,
      });
      if (!limit.allowed) return reply({ outcome: "not_found" });
      const result = await rpc<Record<string, unknown>>(supabase, "call_service_ring_delivered", {
        p_request_id: requestId,
        p_token: token,
      });
      return reply({ outcome: result.outcome });
    }

    const userId = await authenticatedUserId(req);
    if (!userId) return reply({ error: "unauthorized" }, 401);

    switch (action) {
      case "start":
        return await start(supabase, userId, String(body.match_id ?? ""));
      case "status":
      case "join":
        if (!UUID.test(requestId)) return reply({ outcome: "not_found" });
        return await join(supabase, config, userId, requestId, action === "join");
      case "accept":
        if (!UUID.test(requestId)) return reply({ outcome: "not_found" });
        return await accept(
          supabase,
          config,
          userId,
          requestId,
          typeof body.device_id === "string" ? body.device_id.slice(0, 200) : null,
        );
      case "end":
        if (!UUID.test(requestId)) return reply({ outcome: "not_found" });
        return await end(supabase, config, userId, requestId, String(body.reason ?? "hangup"));
      case "extend":
        if (!UUID.test(requestId)) return reply({ outcome: "not_found" });
        return await extend(supabase, config, userId, requestId);
      default:
        return reply({ error: "unknown_action" }, 400);
    }
  } catch (error) {
    console.error(`[calls] ${action} failed:`, (error as Error).message);
    return reply({ error: "temporarily_unavailable" }, 503);
  }
});

type Admin = ReturnType<typeof adminClient>;
type Config = NonNullable<ReturnType<typeof streamConfigFromEnv>>;

async function start(supabase: Admin, userId: string, matchId: string): Promise<Response> {
  if (!UUID.test(matchId)) return reply({ outcome: "not_allowed" });
  const limit = await consumeDistributedRateLimit(supabase, {
    scope: "call_start",
    subject: userId,
    maxRequests: 30,
    windowSeconds: 3600,
  });
  if (!limit.allowed) return reply({ outcome: "rate_limited" });

  const result = await rpc<Record<string, unknown>>(supabase, "call_service_request", {
    p_caller: userId,
    p_match_id: matchId,
  });
  if (result.outcome !== "ringing") {
    // Never pass internal reasons to the caller (spec 4.1), except quiet
    // hours (333): the caller is told, with when calls ring again. What may
    // be told is decided in one place, call_service_unrung_notice.
    const notice = result.outcome === "unavailable" && typeof result.request_id === "string"
      ? await rpc<Record<string, unknown>>(supabase, "call_service_unrung_notice", {
        p_caller: userId,
        p_request_id: result.request_id,
      })
      : {};
    return reply({
      outcome: result.outcome,
      request_id: result.request_id ?? null,
      retry_after: result.retry_after ?? null,
      ...(notice.reason === "quiet_hours" ? { reason: "quiet_hours", quiet_until: notice.quiet_until } : {}),
    });
  }

  const requestIdValue = String(result.request_id);
  const calleeId = String(result.callee_id);
  const expiresAt = String(result.ring_expires_at);
  // Phones time the ring from "seconds left", not from this server's
  // clock: a phone whose clock is wrong must still ring for the full time.
  // The native ring screen shows the caller's photo, as the callee may see it.
  const callerPhoto = await ringPhotoUrl(supabase, calleeId, userId);
  const ringSeconds = Math.max(5, Math.round((Date.parse(expiresAt) - Date.now()) / 1000));
  const sent = await pushToUser(supabase, calleeId, {
    type: "call_incoming",
    request_id: requestIdValue,
    match_id: String(result.match_id),
    caller_id: userId,
    caller_name: String(result.caller_name),
    decline_token: String(result.decline_token),
    expires_at: expiresAt,
    ring_seconds: String(ringSeconds),
    ...(callerPhoto ? { caller_photo: callerPhoto } : {}),
  }, ringSeconds, { ringOnly: true });
  if (sent === 0) {
    await rpc(supabase, "call_service_mark_unreachable", { p_request_id: requestIdValue });
    return reply({ outcome: "unavailable", request_id: requestIdValue });
  }
  return reply({
    outcome: "ringing",
    request_id: requestIdValue,
    ring_expires_at: expiresAt,
    ring_seconds: ringSeconds,
  });
}

async function tokenPayload(config: Config, userId: string, info: Record<string, unknown>) {
  const { token, expiresAt } = await userToken(config, userId);
  return {
    api_key: config.apiKey,
    token,
    token_expires_at: expiresAt,
    call_type: CALL_TYPE,
    call_id: info.stream_call_id,
    user_id: userId,
  };
}

async function join(
  supabase: Admin,
  config: Config,
  userId: string,
  requestId: string,
  withToken: boolean,
): Promise<Response> {
  const info = await rpc<Record<string, unknown>>(supabase, "call_service_join", {
    p_user: userId,
    p_request_id: requestId,
  });
  if (info.outcome !== "active" || !withToken) {
    return reply({
      outcome: info.outcome,
      // 332: whether the ring reached the callee's phone (caller's screen).
      delivered: info.delivered ?? null,
      max_duration_seconds: info.max_duration_seconds ?? null,
      hold_minutes: info.hold_minutes ?? null,
      accepted_at: info.accepted_at ?? null,
      ring_expires_at: info.ring_expires_at ?? null,
      other_name: info.other_name ?? null,
      role: info.role ?? null,
    });
  }
  return reply({
    outcome: "active",
    role: info.role,
    my_name: info.my_name,
    other_name: info.other_name,
    match_id: info.match_id,
    // Needed to report the other member from the call screen.
    other_user_id: info.role === "caller" ? info.callee_id : info.caller_id,
    hold_minutes: info.hold_minutes,
    max_duration_seconds: info.max_duration_seconds,
    accepted_at: info.accepted_at,
    stream: await tokenPayload(config, userId, info),
  });
}

async function accept(
  supabase: Admin,
  config: Config,
  userId: string,
  requestId: string,
  deviceId: string | null,
): Promise<Response> {
  const info = await rpc<Record<string, unknown>>(supabase, "call_service_accept", {
    p_user: userId,
    p_request_id: requestId,
    p_device_id: deviceId,
  });
  if (info.outcome !== "accepted") {
    if (info.outcome === "failed") {
      await pushToUser(supabase, userId, { type: "call_cancel", request_id: requestId }, 30);
    }
    return reply({ outcome: info.outcome });
  }

  const callerId = String(info.caller_id);
  const calleeId = String(info.callee_id);
  const streamCallId = String(info.stream_call_id);
  try {
    await upsertUsers(config, [
      { id: callerId, name: String(info.caller_name) },
      { id: calleeId, name: String(info.callee_name) },
    ]);
    await createCall(config, streamCallId, callerId, [callerId, calleeId], Number(info.max_duration_seconds));
  } catch (error) {
    console.error("[calls] Stream call creation failed:", (error as Error).message);
    await rpc(supabase, "call_service_session_failed", {
      p_request_id: requestId,
      p_error: (error as Error).message,
    });
    await pushToUser(supabase, callerId, { type: "call_ended", request_id: requestId }, 30);
    return reply({ outcome: "failed" });
  }
  const started = await rpc<boolean>(supabase, "call_service_session_started", {
    p_request_id: requestId,
  });
  if (!started) {
    // Ended while Stream was creating it (block, switch off...).
    await endOnStream(supabase, config, requestId, streamCallId);
    return reply({ outcome: "ended" });
  }

  // Stop the ring on the callee's other phones; wake the caller's app.
  await Promise.all([
    pushToUser(supabase, calleeId, { type: "call_cancel", request_id: requestId }, 30, {
      excludeDeviceId: deviceId,
    }),
    pushToUser(supabase, callerId, { type: "call_answered", request_id: requestId }, 30),
  ]);

  return reply({
    outcome: "active",
    role: "callee",
    // Shown in the app (full name once matched); Stream keeps the short one.
    other_name: info.caller_shown_name,
    my_name: info.callee_name,
    match_id: info.match_id,
    other_user_id: callerId,
    hold_minutes: info.hold_minutes,
    max_duration_seconds: info.max_duration_seconds,
    stream: await tokenPayload(config, userId, info),
  });
}

/** Stops the ring on every phone of the callee once they declined. */
async function signalDeclined(supabase: Admin, requestId: string, calleeId: string): Promise<void> {
  await pushToUser(supabase, calleeId, { type: "call_cancel", request_id: requestId }, 30);
}

async function end(
  supabase: Admin,
  config: Config,
  userId: string,
  requestId: string,
  reason: string,
): Promise<Response> {
  const result = await rpc<Record<string, unknown>>(supabase, "call_service_end", {
    p_user: userId,
    p_request_id: requestId,
    p_reason: reason,
  });
  if (result.outcome === "cancelled" || result.outcome === "declined") {
    // The cancel_ring job also does this; sending now stops the ring at once.
    await pushToUser(supabase, String(result.callee_id), {
      type: "call_cancel",
      request_id: requestId,
    }, 30);
  }
  if (result.outcome === "ending" && typeof result.stream_call_id === "string") {
    try {
      await endOnStream(supabase, config, requestId, result.stream_call_id);
    } catch (error) {
      // The end_stream_call job retries; Stream's timer is the backstop.
      console.warn("[calls] mark_ended deferred:", (error as Error).message);
    }
  }
  return reply({ outcome: result.outcome });
}

async function extend(
  supabase: Admin,
  config: Config,
  userId: string,
  requestId: string,
): Promise<Response> {
  const result = await rpc<Record<string, unknown>>(supabase, "call_service_extend", {
    p_user: userId,
    p_request_id: requestId,
  });
  if (result.outcome !== "extended") return reply({ outcome: result.outcome });
  try {
    await setMaxDuration(config, String(result.stream_call_id), Number(result.max_duration_seconds));
  } catch (error) {
    // Minutes were held but Stream kept the old limit: the call simply ends
    // at the old time and settlement returns whatever was not used.
    console.error("[calls] Stream extend failed:", (error as Error).message);
    return reply({ outcome: "extend_failed" });
  }
  return reply({
    outcome: "extended",
    added_minutes: result.added_minutes,
    hold_minutes: result.hold_minutes,
    max_duration_seconds: result.max_duration_seconds,
  });
}

