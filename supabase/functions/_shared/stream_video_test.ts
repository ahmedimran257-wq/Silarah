import { assert, assertEquals } from "@std/assert";
import {
  CALL_MEMBER_GRANTS,
  connectedSecondsFromEvents,
  connectedSecondsFromSessions,
  FORBIDDEN_CAPABILITIES,
  overlapSeconds,
  signJwt,
  verifyWebhook,
  voiceCallTypeBody,
  webhookSignature,
} from "./stream_video.ts";

const SECRET = "fixture-only-stream-secret-0123456789abcdef";

async function gzip(bytes: Uint8Array<ArrayBuffer>): Promise<Uint8Array<ArrayBuffer>> {
  const stream = new Blob([bytes]).stream().pipeThrough(new CompressionStream("gzip"));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

Deno.test("webhook signature: plain body verifies, tampered body fails", async () => {
  const body = new TextEncoder().encode('{"type":"call.ended","call_cid":"silarah_voice:x"}');
  const signature = await webhookSignature(body, SECRET);
  assertEquals((await verifyWebhook(body, signature, SECRET)).ok, true);
  const tampered = new TextEncoder().encode('{"type":"call.ended","call_cid":"silarah_voice:y"}');
  assertEquals((await verifyWebhook(tampered, signature, SECRET)).ok, false);
  assertEquals((await verifyWebhook(body, null, SECRET)).ok, false);
  assertEquals((await verifyWebhook(body, signature, SECRET + "x")).ok, false);
});

Deno.test("webhook signature: gzip body is checked over the uncompressed bytes", async () => {
  const body = new TextEncoder().encode(JSON.stringify({ type: "call.session_ended", pad: "x".repeat(600) }));
  const signature = await webhookSignature(body, SECRET);
  const compressed = await gzip(body);
  assert(compressed[0] === 0x1f && compressed[1] === 0x8b);
  const result = await verifyWebhook(compressed, signature, SECRET);
  assertEquals(result.ok, true);
  if (result.ok) assertEquals(new TextDecoder().decode(result.body), new TextDecoder().decode(body));
  // A signature over the compressed bytes is not accepted.
  const wrong = await webhookSignature(compressed, SECRET);
  assertEquals((await verifyWebhook(compressed, wrong, SECRET)).ok, false);
  // Corrupt gzip is rejected, not thrown.
  const broken = compressed.slice(0, 12);
  assertEquals((await verifyWebhook(broken, signature, SECRET)).ok, false);
});

Deno.test("server JWT is HS256 and verifiable with the secret", async () => {
  const token = await signJwt({ server: true, iat: 1 }, SECRET);
  const [header, payload, signature] = token.split(".");
  assertEquals(JSON.parse(atob(header)), { alg: "HS256", typ: "JWT" });
  assertEquals(JSON.parse(atob(payload)), { server: true, iat: 1 });
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const raw = Uint8Array.from(
    atob(signature.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - signature.length % 4) % 4)),
    (c) => c.charCodeAt(0),
  );
  assert(await crypto.subtle.verify("HMAC", key, raw, new TextEncoder().encode(`${header}.${payload}`)));
});

Deno.test("talk time is only the time BOTH were connected", () => {
  const t = (s: number) => s * 1000;
  // Caller 0-100 s, callee 30-130 s -> 70 s together.
  assertEquals(overlapSeconds([[t(0), t(100)]], [[t(30), t(130)]]), 70);
  // Callee dropped and came back: 30-50 and 60-130 -> 20 + 40.
  assertEquals(overlapSeconds([[t(0), t(100)]], [[t(30), t(50)], [t(60), t(130)]]), 60);
  // Never together.
  assertEquals(overlapSeconds([[t(0), t(10)]], [[t(20), t(30)]]), 0);
  // Overlapping sessions of the same member are not double counted.
  assertEquals(overlapSeconds([[t(0), t(100)], [t(50), t(100)]], [[t(0), t(100)]]), 100);
  // Partial seconds round up (charging rounds minutes up later anyway).
  assertEquals(overlapSeconds([[0, 1500]], [[0, 1500]]), 2);
});

Deno.test("Stream participant sessions: still connected means not final", () => {
  const sessions = [
    { user_id: "a", joined_at: "2026-11-22T10:00:00Z", left_at: "2026-11-22T10:02:05Z" },
    { user_id: "b", joined_at: "2026-11-22T10:00:10Z", left_at: "2026-11-22T10:02:00Z" },
    { user_id: "stranger", joined_at: "2026-11-22T09:00:00Z", left_at: "2026-11-22T11:00:00Z" },
  ];
  assertEquals(connectedSecondsFromSessions(sessions, "a", "b"), 110);
  assertEquals(
    connectedSecondsFromSessions([...sessions, { user_id: "b", joined_at: "2026-11-22T10:03:00Z", left_at: null }], "a", "b"),
    null,
  );
  assertEquals(connectedSecondsFromSessions([], "a", "b"), 0);
});

Deno.test("webhook-log backup uses left events with durations", () => {
  const seconds = connectedSecondsFromEvents([
    { user_id: "a", kind: "joined", at: "2026-11-22T10:00:00Z", duration_seconds: null },
    { user_id: "b", kind: "left", at: "2026-11-22T10:01:30Z", duration_seconds: 60 },
    { user_id: "a", kind: "left", at: "2026-11-22T10:02:00Z", duration_seconds: 120 },
  ], "a", "b", "2026-11-22T10:02:00Z");
  assertEquals(seconds, 60);
  assertEquals(connectedSecondsFromEvents([], "a", "b", null), 0);
});

Deno.test("call type lockdown matches spec 7", () => {
  const body = voiceCallTypeBody();
  assertEquals(body.grants.user, []);
  assertEquals(body.grants.guest, []);
  assertEquals(new Set(body.grants.call_member), new Set(["join-call", "send-audio", "end-call"]));
  for (const capability of FORBIDDEN_CAPABILITIES) {
    assert(!CALL_MEMBER_GRANTS.includes(capability), capability);
  }
  for (const required of [
    "create-call", "send-video", "screenshare", "change-max-duration", "update-call",
    "update-call-settings", "join-ended-call", "start-record-call", "start-transcription-call",
  ]) assert(FORBIDDEN_CAPABILITIES.includes(required), required);
  assertEquals(body.settings.video.enabled, false);
  assertEquals(body.settings.screensharing.enabled, false);
  assertEquals(body.settings.recording.mode, "disabled");
  assertEquals(body.settings.transcription.mode, "disabled");
  assertEquals(body.settings.backstage.enabled, false);
  assertEquals(body.settings.broadcasting.enabled, false);
  assertEquals(body.settings.session.inactivity_timeout_seconds, 30);
  assertEquals(body.settings.frame_recording.mode, "disabled");
  assertEquals(body.settings.individual_recording.mode, "disabled");
  assertEquals(body.settings.raw_recording.mode, "disabled");
  assertEquals(body.settings.ingress.enabled, false);
  assertEquals(body.settings.lifecycle.mode, "single_use");
  assertEquals(body.settings.limits.max_duration_seconds, 3630);
  assertEquals(body.notification_settings.enabled, false);
});
