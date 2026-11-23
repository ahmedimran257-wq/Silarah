import { assertEquals } from "@std/assert";
import { missedCallPush, planReminderPush } from "./call_push.ts";

Deno.test("missed-call push carries the first name, count and variant as strings", () => {
  const push = missedCallPush({
    send: true,
    request_id: "r1",
    match_id: "m1",
    caller_id: "u1",
    caller_name: "Abdul",
    count: 3,
    variant: "premium",
    silent: true,
  });
  assertEquals(push, {
    type: "call_missed",
    request_id: "r1",
    match_id: "m1",
    caller_id: "u1",
    caller_name: "Abdul",
    count: "3",
    variant: "premium",
    silent: "1",
  });
});

Deno.test("missed-call push never sends an unknown variant or a zero count", () => {
  const push = missedCallPush({ caller_name: "Abdul", count: 0, variant: "anything" });
  assertEquals(push.variant, "missed");
  assertEquals(push.count, "1");
  assertEquals(push.silent, "0");
});

Deno.test("plan reminder lives until 30 minutes after the planned time", () => {
  const now = Date.parse("2026-11-22T14:55:00Z");
  const push = planReminderPush({
    user_id: "u1",
    plan_id: "p1",
    match_id: "m1",
    other_name: "Aisha",
    planned_for: "2026-11-22T15:00:00Z",
  }, now);
  assertEquals(push.ttlSeconds, 35 * 60);
  assertEquals(push.data.type, "call_plan_reminder");
  assertEquals(push.data.other_name, "Aisha");
  assertEquals(push.data.silent, "0");
  assertEquals(planReminderPush({ planned_for: "2026-11-22T15:00:00Z", silent: true }, now).data.silent, "1");
});

Deno.test("plan reminder TTL is never below a minute", () => {
  const now = Date.parse("2026-11-22T16:00:00Z");
  const push = planReminderPush({ planned_for: "2026-11-22T15:00:00Z" }, now);
  assertEquals(push.ttlSeconds, 60);
});
