// Settlement decisions with a fake Supabase and a fake Stream: nothing is
// contacted. The rule under test: a call is charged from a real record,
// and 0 only when nobody ever joined.
import { assertEquals } from "@std/assert";

Deno.env.set("SUPABASE_URL", "https://calls-fixture.example.invalid");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "fixture-only-service-key");
const { adminClient, settleCall } = await import("./call_ops.ts");

const CONFIG = { apiKey: "fixture-key", apiSecret: "fixture-only-secret-0123456789abcdef" };
const CALLER = "11111111-1111-4111-8111-111111111111";
const CALLEE = "22222222-2222-4222-8222-222222222222";

interface Fixture {
  events?: { user_id: string; kind: "joined" | "left"; at: string; duration_seconds: number | null }[];
  bothJoinedAt?: string | null;
  streamSessionId?: string | null;
  streamStatus?: number;
  participantSessions?: unknown[];
}

async function settle(fixture: Fixture, attempt = 1) {
  let settled: Record<string, unknown> | null = null;
  const original = globalThis.fetch;
  globalThis.fetch = async (input, init) => {
    const request = new Request(input, init);
    const url = new URL(request.url);
    const json = (body: unknown, status = 200) =>
      new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
    if (url.pathname.endsWith("/rpc/call_service_session_info")) {
      return json({
        request_id: "r",
        stream_call_id: "c".repeat(32),
        caller_id: CALLER,
        callee_id: CALLEE,
        status: "ended",
        ended_at: "2026-11-22T10:05:00Z",
        both_joined_at: fixture.bothJoinedAt ?? null,
        stream_session_id: null,
        events: fixture.events ?? [],
      });
    }
    if (url.pathname.endsWith("/rpc/call_service_settle")) {
      settled = await request.json();
      return json({ outcome: "settled", charged_minutes: 0 });
    }
    if (url.hostname === "video.stream-io-api.com") {
      if (url.pathname.endsWith("/participant_sessions")) {
        return json({ participants_sessions: fixture.participantSessions ?? [] });
      }
      if (fixture.streamStatus && fixture.streamStatus !== 200) {
        return json({ code: 16, message: "fixture" }, fixture.streamStatus);
      }
      return json({ call: { session: fixture.streamSessionId ? { id: fixture.streamSessionId } : null } });
    }
    throw new Error(`unexpected ${url}`);
  };
  try {
    const outcome = await settleCall(adminClient(), CONFIG, "r", attempt);
    return { outcome, settled: settled as Record<string, unknown> | null };
  } finally {
    globalThis.fetch = original;
  }
}

const joined = (user: string, at: string) => ({ user_id: user, kind: "joined" as const, at, duration_seconds: null });
const left = (user: string, at: string, seconds: number) => ({ user_id: user, kind: "left" as const, at, duration_seconds: seconds });

Deno.test("nobody joined and Stream has no session: charged 0", async () => {
  const { outcome, settled } = await settle({});
  assertEquals(outcome.done, true);
  assertEquals(settled?.p_connected_seconds, 0);
});

Deno.test("someone joined but Stream shows no session: never settled as free", async () => {
  const fixture = {
    events: [
      joined(CALLER, "2026-11-22T10:00:00Z"),
      joined(CALLEE, "2026-11-22T10:00:05Z"),
      left(CALLEE, "2026-11-22T10:02:05Z", 120),
      left(CALLER, "2026-11-22T10:02:10Z", 130),
    ],
  };
  const early = await settle(fixture, 1);
  assertEquals(early.outcome.done, false);
  assertEquals(early.settled, null);
  // Stream's record stays unreadable: our signed webhook log decides.
  const late = await settle(fixture, 12);
  assertEquals(late.outcome.done, true);
  assertEquals(late.settled?.p_connected_seconds, 120);
  assertEquals(late.settled?.p_source, "webhook_log");
});

Deno.test("Stream call missing after joins is not free either", async () => {
  const result = await settle({ bothJoinedAt: "2026-11-22T10:00:05Z", streamStatus: 404 }, 1);
  assertEquals(result.outcome.done, false);
  assertEquals(result.settled, null);
});

Deno.test("talk time comes from Stream's participant sessions", async () => {
  const { settled } = await settle({
    streamSessionId: "s1",
    participantSessions: [
      { user_id: CALLER, joined_at: "2026-11-22T10:00:00Z", left_at: "2026-11-22T10:02:05Z" },
      { user_id: CALLEE, joined_at: "2026-11-22T10:00:10Z", left_at: "2026-11-22T10:02:00Z" },
    ],
  });
  assertEquals(settled?.p_connected_seconds, 110);
  assertEquals(settled?.p_source, "stream_participant_sessions");
});

Deno.test("a member still connected: wait, do not settle", async () => {
  const result = await settle({
    streamSessionId: "s1",
    participantSessions: [
      { user_id: CALLER, joined_at: "2026-11-22T10:00:00Z", left_at: null },
    ],
  });
  assertEquals(result.outcome.done, false);
  assertEquals(result.settled, null);
});

Deno.test("Stream lists no shared time but our log shows both talked: charge the log", async () => {
  const { settled } = await settle({
    streamSessionId: "s1",
    participantSessions: [],
    events: [
      joined(CALLER, "2026-11-22T10:00:00Z"),
      joined(CALLEE, "2026-11-22T10:00:00Z"),
      left(CALLER, "2026-11-22T10:01:00Z", 60),
      left(CALLEE, "2026-11-22T10:01:00Z", 60),
    ],
  });
  assertEquals(settled?.p_connected_seconds, 60);
  assertEquals(settled?.p_source, "webhook_log");
});
