import { assert, assertEquals, assertStringIncludes } from "@std/assert";
import { renderAccountEmail, renderPrivacyEmail } from "./index.ts";

const now = new Date("2026-11-14T06:00:00Z");

Deno.test("request email gives the deletion date and how to keep the account", () => {
  const email = renderAccountEmail({
    email_id: "1",
    email_event: "deletion_requested",
    recipient: "member@example.com",
    purge_after_at: "2026-12-14T06:00:00Z",
    first_name: "Ayesha",
  }, now);
  assertEquals(
    email.subject,
    "We received your request to delete your Silarah account",
  );
  assertStringIncludes(email.text, "permanently deleted on 14 December 2026");
  assertStringIncludes(
    email.text,
    "Sign in to Silarah before 14 December 2026",
  );
  assertStringIncludes(
    email.text,
    "does not cancel a Google Play subscription",
  );
  assertStringIncludes(email.html, "Assalamu alaikum Ayesha,");
});

Deno.test("an immediate staff deletion promises no date it cannot keep", () => {
  const email = renderAccountEmail({
    email_id: "2",
    email_event: "deletion_requested",
    recipient: "member@example.com",
    purge_after_at: "2026-11-14T05:00:00Z",
    first_name: null,
  }, now);
  assertStringIncludes(email.text, "within the next 24 hours");
  assert(!email.text.includes("Changed your mind"));
});

Deno.test("completion email confirms deletion and no further data collection", () => {
  const email = renderAccountEmail({
    email_id: "3",
    email_event: "deletion_completed",
    recipient: "member@example.com",
    purge_after_at: null,
    first_name: null,
  }, now);
  assertEquals(email.subject, "Your Silarah account has been deleted");
  assertStringIncludes(
    email.text,
    "we will not collect any more data about you",
  );
  assertStringIncludes(email.text, "minimum records the law requires");
  assertStringIncludes(email.text, "No further emails will be sent");
});

Deno.test("names are escaped in the email body", () => {
  const email = renderAccountEmail({
    email_id: "4",
    email_event: "deletion_cancelled",
    recipient: "member@example.com",
    purge_after_at: null,
    first_name: "<script>",
  }, now);
  assert(!email.html.includes("<script>"));
  assertStringIncludes(email.html, "&lt;script&gt;");
});

Deno.test("privacy confirmation gives the reference, type and response date", () => {
  const email = renderPrivacyEmail({
    email_id: "p1",
    email_event: "received",
    recipient: "member@example.com",
    first_name: "Ayesha",
    request_id: "6f1c2a9e-0000-4000-8000-000000000001",
    request_kind: "erasure",
    due_at: "2026-12-05T09:32:30Z",
  });
  assertEquals(email.subject, "We received your privacy request");
  assertStringIncludes(email.text, "we will respond by 5 December 2026");
  assertStringIncludes(email.text, "Reference: 6f1c2a9e-0000-4000-8000-000000000001");
  assertStringIncludes(email.text, "Type: Erasure of your data");
  assertStringIncludes(email.html, "Assalamu alaikum Ayesha,");
});

Deno.test("privacy answer email points to the app, not the response text", () => {
  const email = renderPrivacyEmail({
    email_id: "p2",
    email_event: "resolved",
    recipient: "member@example.com",
    first_name: null,
    request_id: "6f1c2a9e-0000-4000-8000-000000000002",
    request_kind: "access",
    due_at: "2026-12-05T09:32:30Z",
  });
  assertEquals(email.subject, "We have answered your privacy request");
  assertStringIncludes(email.text, "Settings > Privacy requests");
  assertStringIncludes(email.text, "Reference: 6f1c2a9e-0000-4000-8000-000000000002");
});

Deno.test("privacy email escapes the member's name", () => {
  const email = renderPrivacyEmail({
    email_id: "p3",
    email_event: "received",
    recipient: "member@example.com",
    first_name: "<b>x</b>",
    request_id: "r",
    request_kind: "unknown_kind",
    due_at: "2026-12-05T09:32:30Z",
  });
  assert(!email.html.includes("<b>x</b>"));
  assertStringIncludes(email.text, "Type: Privacy request");
});
