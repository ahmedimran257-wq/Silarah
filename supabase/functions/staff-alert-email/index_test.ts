import { assertEquals, assertStringIncludes } from "@std/assert";
import { alertTarget } from "./index.ts";

Deno.test("limit alerts keep their subject and System health link", () => {
  const target = alertTarget("database_usage_85");
  assertEquals(target.subject, "Silarah: free-plan limit at 85%");
  assertStringIncludes(target.url, "/system");
});

Deno.test("privacy alerts link to Member rights", () => {
  assertEquals(alertTarget("privacy_request_received").subject, "Silarah: new privacy request");
  assertStringIncludes(alertTarget("privacy_request_overdue").subject, "OVERDUE");
  assertStringIncludes(alertTarget("privacy_request_due_soon").url, "/privacy");
});

Deno.test("deadline and failure alerts link to the page that fixes them", () => {
  assertStringIncludes(alertTarget("photo_checks_due").url, "/photo-verification");
  assertStringIncludes(alertTarget("reports_waiting_24h").url, "/moderation");
  assertStringIncludes(alertTarget("account_purge_overdue").url, "/deletions");
  assertStringIncludes(alertTarget("voice_call_worker_dead_job").url, "/calls");
  assertEquals(alertTarget("scheduled_jobs_failing").subject, "Silarah: system alert");
});
