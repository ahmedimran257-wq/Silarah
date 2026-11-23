// EDGE FUNCTION: stream-webhook
//
// Receives Stream Video webhooks (docs/voice_calling_spec.md 5).
//  * X-Signature = HMAC-SHA256 (hex) of the uncompressed raw body with the
//    API secret; gzip bodies are decompressed first (10 MiB limit).
//  * X-Api-Key must be our key. Duplicate deliveries (same X-Webhook-Id) are
//    counted once in the database.
//  * Replies within Stream's 6-second budget; follow-up work (ending a call
//    when a member left, settlement) runs after the reply.
// Deployed with --no-verify-jwt: Stream signs, it does not hold a JWT.
import { adminClient, endIfMemberGone, rpc, settleCall } from "../_shared/call_ops.ts";
import {
  CALL_TYPE,
  constantTimeEqual,
  MAX_WEBHOOK_BYTES,
  setMaxDuration,
  streamConfigFromEnv,
  verifyWebhook,
} from "../_shared/stream_video.ts";

const HANDLED = new Set([
  "call.session_participant_joined",
  "call.session_participant_left",
  "call.session_started",
  "call.session_ended",
  "call.ended",
]);

declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void } | undefined;

function later(task: () => Promise<void>): void {
  const promise = task().catch((error) =>
    console.error("[stream-webhook] follow-up failed:", (error as Error).message)
  );
  if (typeof EdgeRuntime !== "undefined" && EdgeRuntime?.waitUntil) {
    EdgeRuntime.waitUntil(promise);
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  const config = streamConfigFromEnv();
  if (!config) return new Response("Service Unavailable", { status: 503 });

  // The HMAC signature (below) is what proves Stream sent this. The API key
  // header only says which app it is for: a different key is refused, a
  // missing one is not a reason to drop a correctly signed event.
  const apiKey = req.headers.get("X-Api-Key");
  if (apiKey != null && !constantTimeEqual(apiKey, config.apiKey)) {
    return new Response("Unauthorized", { status: 401 });
  }
  const length = Number(req.headers.get("Content-Length") ?? "0");
  if (length > MAX_WEBHOOK_BYTES) return new Response("Payload Too Large", { status: 413 });
  const raw = new Uint8Array(await req.arrayBuffer());
  const verified = await verifyWebhook(raw, req.headers.get("X-Signature"), config.apiSecret);
  if (!verified.ok) {
    console.warn(`[stream-webhook] rejected: ${verified.reason}`);
    return new Response("Unauthorized", { status: 401 });
  }

  let event: Record<string, unknown>;
  try {
    event = JSON.parse(new TextDecoder().decode(verified.body));
  } catch {
    return new Response("Bad Request", { status: 400 });
  }
  const type = String(event.type ?? "");
  const callCid = String(event.call_cid ?? "");
  if (!HANDLED.has(type) || !callCid.startsWith(`${CALL_TYPE}:`)) {
    return new Response("OK", { status: 200 });
  }
  const webhookId = req.headers.get("X-Webhook-Id") ?? req.headers.get("X-Webhook-ID") ??
    `${type}:${callCid}:${String(event.created_at ?? "")}`;
  const participant = (event.participant ?? {}) as Record<string, unknown>;
  const user = (participant.user ?? {}) as Record<string, unknown>;
  const occurredAt = type === "call.session_participant_joined"
    ? String(participant.joined_at ?? event.created_at ?? "")
    : String(event.created_at ?? "");

  const supabase = adminClient();
  let result: Record<string, unknown>;
  try {
    result = await rpc(supabase, "call_service_record_stream_event", {
      p_webhook_id: webhookId,
      p_event_type: type,
      p_stream_call_id: callCid.slice(CALL_TYPE.length + 1),
      p_stream_session_id: typeof event.session_id === "string" ? event.session_id : null,
      p_user_id: typeof user.id === "string" ? user.id : null,
      p_user_session_id: typeof participant.user_session_id === "string"
        ? participant.user_session_id
        : null,
      p_occurred_at: occurredAt && !Number.isNaN(Date.parse(occurredAt)) ? occurredAt : null,
      p_duration_seconds: Number.isFinite(Number(event.duration_seconds))
        ? Math.round(Number(event.duration_seconds))
        : null,
    });
  } catch (error) {
    console.error("[stream-webhook] record failed:", (error as Error).message);
    return new Response("Retry", { status: 500 });
  }

  const requestId = typeof result.request_id === "string" ? result.request_id : null;
  if (requestId && result.action === "check_left") {
    later(() => endIfMemberGone(supabase, config, requestId));
  } else if (
    requestId && result.action === "set_limit" && typeof result.stream_call_id === "string" &&
    Number.isFinite(Number(result.max_duration_seconds))
  ) {
    // Both members are in: Stream's limit becomes the hold plus the real
    // connect time, so paid talk time is never longer than the hold. If
    // this fails the full allowance stays (bounded) and the caller's phone
    // still ends the call at 0.
    const streamCallId = result.stream_call_id;
    const limit = Number(result.max_duration_seconds);
    later(async () => {
      try {
        await setMaxDuration(config, streamCallId, limit);
      } catch (error) {
        console.warn("[stream-webhook] time limit not tightened:", (error as Error).message);
      }
    });
  } else if (requestId && result.action === "settle") {
    later(async () => {
      // Give Stream a moment to close the participant sessions.
      await new Promise((resolve) => setTimeout(resolve, 3000));
      const outcome = await settleCall(supabase, config, requestId, 1);
      if (!outcome.done) console.log(`[stream-webhook] settle later: ${outcome.error}`);
    });
  }
  return new Response("OK", { status: 200 });
});
