// EDGE FUNCTION: call-gate-probe  (STAGING ONLY — never deploy to production)
//
// Proves spec 9 gates 1 and 2 against the real Stream app with real member
// tokens: a member token cannot create a call, cannot join a call it is not
// a member of, and a member of a call cannot turn on video, record,
// transcribe, broadcast, add people, raise its own permissions or extend the
// time limit. Uses throw-away Stream users and one throw-away call, cleaned
// up at the end. Authorized by the private cron secret and refuses to run
// on any project other than Silarah Staging.
import { isAuthorizedCronRequest } from "../_shared/cron_auth.ts";
import { json } from "../_shared/call_ops.ts";
import {
  CALL_TYPE,
  webhookSignature,
  createCall,
  deleteUser,
  markEnded,
  StreamError,
  streamConfigFromEnv,
  streamRequestAs,
  upsertUsers,
  userToken,
} from "../_shared/stream_video.ts";

const STAGING_REF = "ykmgkrveucslglxvcyss";

Deno.serve(async (req) => {
  if (!String(Deno.env.get("SUPABASE_URL")).includes(STAGING_REF)) {
    return new Response("Not Found", { status: 404 });
  }
  if (req.method !== "POST" || !(await isAuthorizedCronRequest(req))) {
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
  if (body.action === "webhook") return json(await webhookGate(config));

  const run = crypto.randomUUID().replace(/-/g, "").slice(0, 12);
  const a = crypto.randomUUID();
  const b = crypto.randomUUID();
  const stranger = crypto.randomUUID();
  const callId = crypto.randomUUID().replace(/-/g, "");
  const results: Record<string, unknown>[] = [];

  async function probe(
    name: string,
    expectAllowed: boolean,
    token: string | null,
    method: "GET" | "POST" | "PATCH",
    path: string,
    body?: unknown,
  ) {
    let status = 200;
    let message = "ok";
    let response: Record<string, unknown> | null = null;
    try {
      response = await streamRequestAs(config!, token, method, path, body);
    } catch (error) {
      status = error instanceof StreamError ? error.status : 0;
      message = (error as Error).message;
    }
    const allowed = status >= 200 && status < 300;
    results.push({
      name,
      expected: expectAllowed ? "allowed" : "refused",
      http_status: status,
      pass: allowed === expectAllowed,
      message: message.slice(0, 200),
    });
    return response;
  }

  try {
    await upsertUsers(config, [
      { id: a, name: `Gate A ${run}` },
      { id: b, name: `Gate B ${run}` },
      { id: stranger, name: `Gate C ${run}` },
    ]);
    await createCall(config, callId, a, [a, b], 90);
    const tokenA = (await userToken(config, a, 600)).token;
    const tokenC = (await userToken(config, stranger, 600)).token;
    const path = `/video/call/${CALL_TYPE}/${callId}`;
    const join = { create: false, location: "auto", video: false };

    // Gate 1
    await probe("member token cannot create a call", false, tokenA, "POST",
      `/video/call/${CALL_TYPE}/${crypto.randomUUID().replace(/-/g, "")}`,
      { data: { members: [{ user_id: a }, { user_id: stranger }] } });
    await probe("join with create=true cannot create a call", false, tokenA, "POST",
      `/video/call/${CALL_TYPE}/${crypto.randomUUID().replace(/-/g, "")}/join`,
      { create: true, location: "auto" });
    await probe("stranger cannot join someone else's call", false, tokenC, "POST", `${path}/join`, join);
    await probe("stranger cannot read someone else's call", false, tokenC, "GET", path);
    await probe("anyone with only the API key cannot become a guest", false, null, "POST",
      "/video/guest", { user: { id: `guest-${run}` } });
    const joined = await probe("call member can join their own call", true, tokenA, "POST", `${path}/join`, join);
    // The Flutter SDK always joins with create=true: that must work for an
    // existing call the member belongs to, without any create-call right.
    await probe("member joins own call the SDK way (create=true)", true,
      (await userToken(config, b, 600)).token, "POST", `${path}/join`,
      { create: true, location: "auto", video: false });
    await probe("stranger cannot join with create=true either", false, tokenC, "POST",
      `${path}/join`, { create: true, location: "auto" });
    const capabilities = (joined?.own_capabilities ?? []) as string[];
    results.push({
      name: "member's own capabilities are only join/send-audio/end-call",
      expected: "join-call, send-audio, end-call",
      own_capabilities: capabilities,
      pass: ["join-call", "send-audio", "end-call"].every((c) => capabilities.includes(c)) &&
        !capabilities.some((c) =>
          ["send-video", "screenshare", "change-max-duration", "update-call",
            "update-call-settings", "start-record-call", "start-transcription-call",
            "join-ended-call", "create-call", "update-call-member", "update-call-permissions",
            "start-broadcast-call", "start-closed-captions-call"].includes(c)
        ),
    });

    // Gate 2
    await probe("member cannot extend the time limit", false, tokenA, "PATCH", path,
      { settings_override: { limits: { max_duration_seconds: 99999 } } });
    await probe("member cannot remove the time limit", false, tokenA, "PATCH", path,
      { settings_override: { limits: { max_duration_seconds: 0 } } });
    await probe("member cannot turn video on", false, tokenA, "PATCH", path,
      { settings_override: { video: { enabled: true, target_resolution: { width: 640, height: 480 } } } });
    await probe("member cannot grant themselves send-video", false, tokenA, "POST",
      `${path}/user_permissions`, { user_id: a, grant_permissions: ["send-video", "screenshare"] });
    // Asking is accepted by Stream, but only an admin role can grant, and no
    // member has it: prove the ask changes nothing.
    await probe("member may ask for video (Stream accepts the ask)", true, tokenA, "POST",
      `${path}/request_permission`, { permissions: ["send-video", "screenshare"] });
    // Spec 7 grants no read-call, so capabilities are re-read through join.
    await probe("member cannot read call details (no read-call grant)", false, tokenA, "GET", path);
    const after = await probe("member re-joins to read capabilities", true, tokenA, "POST",
      `${path}/join`, join);
    const afterCaps = (after?.own_capabilities ?? []) as string[];
    results.push({
      name: "asking for video grants nothing",
      expected: "no send-video / screenshare",
      own_capabilities: afterCaps,
      pass: !afterCaps.includes("send-video") && !afterCaps.includes("screenshare"),
    });
    await probe("the other member cannot grant video either", false,
      (await userToken(config, b, 600)).token, "POST", `${path}/user_permissions`,
      { user_id: a, grant_permissions: ["send-video"] });
    await probe("member cannot start recording", false, tokenA, "POST",
      `${path}/recordings/composite/start`, {});
    await probe("member cannot start an individual recording", false, tokenA, "POST",
      `${path}/recordings/individual/start`, {});
    await probe("member cannot start frame recording", false, tokenA, "POST",
      `${path}/start_frame_recording`, {});
    await probe("member cannot start transcription", false, tokenA, "POST",
      `${path}/start_transcription`, {});
    await probe("member cannot start closed captions", false, tokenA, "POST",
      `${path}/start_closed_captions`, {});
    await probe("member cannot broadcast (HLS)", false, tokenA, "POST",
      `${path}/start_broadcasting`, {});
    await probe("member cannot go live", false, tokenA, "POST", `${path}/go_live`, {});
    await probe("member cannot add a third person", false, tokenA, "POST", `${path}/members`,
      { update_members: [{ user_id: stranger }] });
    await probe("member cannot make the call ring through Stream", false, tokenA, "POST",
      `${path}/ring`, { members_ids: [b] });
    await probe("member can end their own call", true, tokenA, "POST", `${path}/mark_ended`, {});
    await probe("nobody can join an ended call", false, tokenA, "POST", `${path}/join`, join);
  } finally {
    try {
      await markEnded(config, callId);
    } catch { /* already ended */ }
    for (const id of [a, b, stranger]) {
      try {
        await deleteUser(config, id);
      } catch { /* best effort */ }
    }
  }
  return json({
    run,
    all_pass: results.every((r) => r.pass === true),
    results,
  });
});

/**
 * Spec 9 gate 4 against the deployed stream-webhook: correct signatures are
 * accepted plain and gzipped, wrong ones refused, and a duplicate delivery
 * (same X-Webhook-Id) is answered but recorded once (checked in SQL).
 */
async function webhookGate(config: { apiKey: string; apiSecret: string }) {
  const url = `${Deno.env.get("SUPABASE_URL")}/functions/v1/stream-webhook`;
  const run = crypto.randomUUID().slice(0, 8);
  const event = (pad: number) =>
    new TextEncoder().encode(JSON.stringify({
      type: "call.session_ended",
      call_cid: `${CALL_TYPE}:${"0".repeat(24)}${run}`,
      session_id: `gate-${run}`,
      created_at: new Date().toISOString(),
      pad: "x".repeat(pad),
    }));
  const gzip = async (bytes: Uint8Array<ArrayBuffer>) =>
    new Uint8Array(
      await new Response(new Blob([bytes]).stream().pipeThrough(new CompressionStream("gzip")))
        .arrayBuffer(),
    );
  const send = async (raw: Uint8Array<ArrayBuffer>, signature: string, id: string, gz = false, key = config.apiKey) => {
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
      "X-Signature": signature,
      "X-Webhook-Id": id,
      "X-Api-Key": key,
    };
    if (gz) headers["Content-Encoding"] = "gzip";
    const response = await fetch(url, { method: "POST", headers, body: raw });
    await response.body?.cancel();
    return response.status;
  };
  const plain = event(10);
  const big = event(2000);
  const sigPlain = await webhookSignature(plain, config.apiSecret);
  const sigBig = await webhookSignature(big, config.apiSecret);
  const zipped = await gzip(big);
  const results = [
    { name: "signed plain body accepted", expect: 200, got: await send(plain, sigPlain, `gate-${run}-1`) },
    { name: "same delivery again answered (counted once in SQL)", expect: 200, got: await send(plain, sigPlain, `gate-${run}-1`) },
    { name: "signed gzip body accepted (signature over uncompressed)", expect: 200, got: await send(zipped, sigBig, `gate-${run}-2`, true) },
    { name: "gzip signed over the compressed bytes refused", expect: 401, got: await send(zipped, await webhookSignature(zipped, config.apiSecret), `gate-${run}-3`, true) },
    { name: "wrong signature refused", expect: 401, got: await send(plain, "0".repeat(64), `gate-${run}-4`) },
    { name: "missing signature refused", expect: 401, got: await send(plain, "", `gate-${run}-5`) },
    { name: "tampered body refused", expect: 401, got: await send(event(11), sigPlain, `gate-${run}-6`) },
    { name: "another app's key refused", expect: 401, got: await send(plain, sigPlain, `gate-${run}-7`, false, "someoneelse") },
  ].map((r) => ({ ...r, pass: r.expect === r.got }));
  return { run, all_pass: results.every((r) => r.pass), results };
}
