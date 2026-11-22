// EDGE FUNCTION: call-worker
//
// Woken by the 10-second database watchdog (private.call_watchdog) only when
// calling has work: end calls on Stream, check that both members joined,
// settle ended calls from Stream's record, stop ringing, delete the Stream
// user of a deleted account. Also `{ "action": "setup" }` creates/updates
// the locked-down silarah_voice call type and our webhook on the Stream app.
// Authorized by the private cron secret (x-cron-secret), like other workers.
import { isAuthorizedCronRequest } from "../_shared/cron_auth.ts";
import {
  adminClient,
  endOnStream,
  json,
  pushToUser,
  rpc,
  settleCall,
} from "../_shared/call_ops.ts";
import {
  CALL_TYPE,
  deleteUser,
  getCall,
  isNotFound,
  streamConfigFromEnv,
  streamRequest,
  type StreamConfig,
  voiceCallTypeBody,
} from "../_shared/stream_video.ts";

const WEBHOOK_EVENTS = [
  "call.session_participant_joined",
  "call.session_participant_left",
  "call.session_started",
  "call.session_ended",
  "call.ended",
];

interface Job {
  id: number;
  kind: string;
  request_id: string | null;
  user_id: string | null;
  attempts: number;
  lease_token: string;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  if (!(await isAuthorizedCronRequest(req))) {
    return new Response("Unauthorized", { status: 401 });
  }
  const config = streamConfigFromEnv();
  if (!config) return json({ error: "stream_not_configured" }, 503);
  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }
  const supabase = adminClient();

  if (body.action === "setup") return json(await setup(config));
  if (body.action === "inspect") return json(await inspect(config, String(body.call_id ?? "")));

  const started = Date.now();
  let processed = 0;
  const failures: string[] = [];
  while (Date.now() - started < 40_000) {
    const jobs = await rpc<Job[]>(supabase, "call_service_checkout_jobs", { p_limit: 10 });
    if (!jobs || jobs.length === 0) break;
    await Promise.all(jobs.map(async (job) => {
      let success = false;
      let error: string | null = null;
      let retry: number | null = null;
      try {
        const outcome = await runJob(supabase, config, job);
        success = outcome.success;
        retry = outcome.retrySeconds ?? null;
        error = outcome.error ?? null;
      } catch (caught) {
        error = (caught as Error).message;
      }
      if (!success) failures.push(`${job.kind}:${error}`);
      await rpc(supabase, "call_service_finish_job", {
        p_job_id: job.id,
        p_lease_token: job.lease_token,
        p_success: success,
        p_error: error,
        p_retry_seconds: retry,
      });
      processed++;
    }));
  }
  await supabase.rpc("record_edge_function_result", {
    p_function_name: "call-worker",
    p_success: failures.length === 0,
    p_error: failures.length ? failures.slice(0, 3).join("; ").slice(0, 300) : null,
    p_details: { processed },
  });
  return json({ processed, failed: failures.length });
});

type Admin = ReturnType<typeof adminClient>;

async function runJob(
  supabase: Admin,
  config: StreamConfig,
  job: Job,
): Promise<{ success: boolean; retrySeconds?: number; error?: string }> {
  switch (job.kind) {
    case "end_stream_call": {
      const info = await rpc<Record<string, unknown> | null>(supabase, "call_service_session_info", {
        p_request_id: job.request_id,
      });
      if (!info) return { success: true };
      await endOnStream(supabase, config, job.request_id!, String(info.stream_call_id));
      return { success: true };
    }
    case "join_check": {
      const info = await rpc<Record<string, unknown> | null>(supabase, "call_service_session_info", {
        p_request_id: job.request_id,
      });
      if (!info || info.status !== "active" || info.both_joined_at) return { success: true };
      let both = false;
      try {
        const snapshot = await getCall(config, String(info.stream_call_id));
        both = snapshot.liveUserIds.includes(String(info.caller_id)) &&
          snapshot.liveUserIds.includes(String(info.callee_id));
      } catch (error) {
        if (!isNotFound(error)) throw error;
      }
      if (both) {
        await rpc(supabase, "call_service_mark_both_joined", { p_request_id: job.request_id });
        return { success: true };
      }
      const ended = await rpc<Record<string, unknown>>(supabase, "call_service_system_end", {
        p_request_id: job.request_id,
        p_reason: "join_timeout",
      });
      if (typeof ended.stream_call_id === "string") {
        await endOnStream(supabase, config, job.request_id!, ended.stream_call_id);
      }
      return { success: true };
    }
    case "settle": {
      const outcome = await settleCall(supabase, config, job.request_id!, job.attempts);
      return outcome.done
        ? { success: true }
        : { success: false, retrySeconds: outcome.retrySeconds, error: outcome.error };
    }
    case "cancel_ring": {
      if (job.user_id) {
        await pushToUser(supabase, job.user_id, {
          type: "call_cancel",
          request_id: job.request_id ?? "",
        }, 30);
      }
      return { success: true };
    }
    case "delete_stream_user": {
      try {
        await deleteUser(config, job.user_id!);
      } catch (error) {
        if (!isNotFound(error)) throw error;
      }
      return { success: true };
    }
    default:
      return { success: true };
  }
}

/** Idempotent: creates or updates silarah_voice and our webhook hook. */
async function setup(config: StreamConfig): Promise<Record<string, unknown>> {
  const typeBody = voiceCallTypeBody();
  let created = false;
  try {
    await streamRequest(config, "GET", `/video/calltypes/${CALL_TYPE}`);
    await streamRequest(config, "PUT", `/video/calltypes/${CALL_TYPE}`, typeBody);
  } catch (error) {
    if (!isNotFound(error)) throw error;
    await streamRequest(config, "POST", "/video/calltypes", { name: CALL_TYPE, ...typeBody });
    created = true;
  }
  const callType = await streamRequest<Record<string, unknown>>(
    config,
    "GET",
    `/video/calltypes/${CALL_TYPE}`,
  );

  const webhookUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/stream-webhook`;
  const app = await streamRequest<{ app?: { event_hooks?: Record<string, unknown>[] } }>(
    config,
    "GET",
    "/app",
  );
  // Updating event_hooks replaces the whole list: keep everyone else's.
  const others = (app.app?.event_hooks ?? []).filter((hook) =>
    !(hook.hook_type === "webhook" && hook.webhook_url === webhookUrl)
  ).map((hook) => {
    const copy: Record<string, unknown> = {};
    for (const key of ["id", "enabled", "hook_type", "webhook_url", "event_types", "product",
      "timeout_ms", "should_send_custom_events", "callback"]) {
      if (key in hook) copy[key] = hook[key];
    }
    return copy;
  });
  await streamRequest(config, "PATCH", "/app", {
    enable_hook_payload_compression: true,
    // Only our server creates Stream users; no anonymous guests.
    guest_user_creation_disabled: true,
    event_hooks: [
      ...others,
      {
        enabled: true,
        hook_type: "webhook",
        webhook_url: webhookUrl,
        event_types: WEBHOOK_EVENTS,
        timeout_ms: 6000,
      },
    ],
  });
  const after = await streamRequest<{ app?: Record<string, unknown> }>(config, "GET", "/app");
  const hooks = ((after.app?.event_hooks ?? []) as Record<string, unknown>[]).map((hook) => ({
    hook_type: hook.hook_type,
    enabled: hook.enabled,
    webhook_url: hook.webhook_url,
    event_types: hook.event_types,
  }));
  return {
    created,
    call_type: {
      name: (callType as Record<string, unknown>).name,
      grants: (callType as Record<string, unknown>).grants,
      settings: (callType as Record<string, unknown>).settings,
      notification_settings: (callType as Record<string, unknown>).notification_settings,
    },
    event_hooks: hooks,
    compression: after.app?.enable_hook_payload_compression ?? null,
    guest_user_creation_disabled: after.app?.guest_user_creation_disabled ?? null,
  };
}

/** Read-only view of one call for the staging gates (no secrets). */
async function inspect(config: StreamConfig, callId: string): Promise<Record<string, unknown>> {
  if (!/^[a-z0-9]{32}$/.test(callId)) return { error: "bad_call_id" };
  const call = await streamRequest<Record<string, unknown>>(
    config,
    "GET",
    `/video/call/${CALL_TYPE}/${callId}`,
  );
  return call;
}

