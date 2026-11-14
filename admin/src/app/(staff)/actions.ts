"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z, ZodError } from "zod";
import { requireAdmin, type CurrentAdmin } from "@/lib/auth";
import { can, type AdminAction } from "@/lib/access";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

const uuidSchema = z.string().uuid();
const reasonSchema = z.string().trim().max(500).optional().default("");
const accountActionSchema = z.object({
  userId: uuidSchema,
  action: z.enum(["suspend", "restore", "ban", "shadowban"]),
  reason: reasonSchema,
}).superRefine((value, ctx) => {
  if (["ban", "shadowban"].includes(value.action) && value.reason.length < 6) {
    ctx.addIssue({ code: "custom", message: "Bans and shadowbans need a short reason for the audit log." });
  }
});
const bulkAccountActionSchema = z.object({
  userIds: z.array(uuidSchema).min(1, "Select at least one member.").max(50),
  action: z.enum(["suspend", "restore", "ban", "shadowban"]),
  reason: z.string().trim().min(6, "Bulk actions require a reason.").max(500),
});
const photoVerificationReviewSchema = z.object({
  submissionId: uuidSchema,
  decision: z.enum(["approve", "reject", "resubmit"]),
  reason: reasonSchema,
  samePerson: z.boolean(),
  clearCapture: z.boolean(),
  currentPhotoMatch: z.boolean(),
}).superRefine((value, ctx) => {
  if (value.decision === "approve" && ![
    value.samePerson,
    value.clearCapture,
    value.currentPhotoMatch,
  ].every(Boolean)) {
    ctx.addIssue({ code: "custom", message: "Complete all three photo checks before approval." });
  }
  if (value.decision !== "approve" && value.reason.trim().length < 6) {
    ctx.addIssue({ code: "custom", message: "Choose a clear resubmission or rejection reason." });
  }
});
const reportSchema = z.object({
  reportId: uuidSchema,
  action: z.enum(["actioned", "dismissed"]),
});
const messageReportSchema = z.object({
  reportId: uuidSchema,
  action: z.enum(["reviewed", "actioned", "dismissed"]),
});
const photoReviewSchema = z.object({
  photoId: uuidSchema,
  decision: z.enum(["approve", "reject"]),
  reason: reasonSchema,
}).superRefine((value, ctx) => {
  if (value.decision === "reject" && value.reason.length < 6) {
    ctx.addIssue({ code: "custom", message: "Tell the member why the photo was rejected." });
  }
});
const campaignSchema = z.object({
  title: z.string().trim().min(3).max(80),
  body: z.string().trim().min(3).max(220),
  deepLink: z.string().trim().max(300).optional().default("")
    .refine((value) => value === "" || /^silarah:\/\/[a-z0-9/_-]*$/i.test(value), "Deep links must start with silarah://"),
  audience: z.enum(["all", "active_7d", "subscribers", "country"]).default("all"),
  countryCode: z.string().trim().toUpperCase().max(2).optional().default(""),
  scheduledAt: z.string().trim().datetime({ offset: true, message: "Choose when the campaign should go out." }),
}).superRefine((value, ctx) => {
  if (value.audience === "country" && !/^[A-Z]{2}$/.test(value.countryCode)) {
    ctx.addIssue({ code: "custom", message: "Country campaigns need a two-letter country code." });
  }
  if (Date.parse(value.scheduledAt) < Date.now() - 60_000) {
    ctx.addIssue({ code: "custom", message: "The schedule is in the past. Choose a future time." });
  }
});
const contentSchema = z.object({
  slug: z.string().trim().regex(/^[a-z0-9][a-z0-9-]{1,80}$/, "Use lowercase letters, numbers and dashes for the slug."),
  locale: z.string().trim().regex(/^[a-z]{2}(-[a-z]{2})?$/, "Use a locale like en or hi-in.").default("en"),
  title: z.string().trim().min(3).max(120),
  body: z.string().trim().min(20, "The page body needs at least 20 characters."),
});
const contentStatusSchema = z.object({
  pageId: uuidSchema,
  status: z.enum(["draft", "published", "archived"]),
});
const successStorySchema = z.object({
  coupleName: z.string().trim().min(2).max(120),
  countryCode: z.string().trim().toUpperCase().max(2).optional().default(""),
  story: z.string().trim().min(20),
  photoPath: z.string().trim().max(500).optional().default(""),
});
const successStoryReviewSchema = z.object({
  storyId: uuidSchema,
  status: z.enum(["published", "rejected", "archived"]),
});
const staffSchema = z.object({
  email: z.string().trim().email(),
  role: z.enum(["support", "moderator", "super_admin"]),
});
const staffUpdateSchema = z.object({
  userId: uuidSchema,
  role: z.enum(["support", "moderator", "super_admin"]),
  status: z.enum(["active", "revoked"]),
  mfaRequired: z.boolean(),
});
const revealSchema = z.object({
  userId: uuidSchema,
  reason: z.enum([
    "Member support request",
    "Safety investigation",
    "Legal or privacy request",
    "Account recovery",
  ]),
});

// Mirrors the role list each RPC enforces in the database, so staff get a
// clear message instead of a database refusal.
function assertCan(admin: CurrentAdmin, action: AdminAction) {
  if (!can(admin.role, action)) {
    throw new Error("UNAUTHORIZED: Your staff role cannot perform this action.");
  }
}

function assertAccountActionRole(admin: CurrentAdmin, action: string) {
  assertCan(admin, ["ban", "shadowban"].includes(action) ? "banAccounts" : "moderateAccounts");
}

function formString(formData: FormData, key: string) {
  return String(formData.get(key) ?? "");
}

async function run(name: string, values: Record<string, unknown>) {
  const supabase = await createClient();
  const { error } = await supabase.rpc(name, values);
  if (error) throw new Error(error.message);
}

async function claimWorkItem(itemType: "report" | "photo" | "message_report", itemId: string) {
  await run("admin_claim_work_item", {
    p_item_type: itemType,
    p_item_id: itemId,
  });
}

class UserFacingError extends Error {}

function actionMessage(error: unknown) {
  if (error instanceof UserFacingError) return error.message;
  if (error instanceof ZodError) {
    return error.issues[0]?.message ?? "Check the form and try again.";
  }
  if (error instanceof Error && error.message.startsWith("UNAUTHORIZED:")) {
    return "Your staff role cannot perform this action.";
  }
  if (error instanceof Error && error.message.includes("already being reviewed")) {
    return "Another moderator is reviewing this item. Try again in a few minutes.";
  }
  return "The action could not be completed. Refresh and try again.";
}

function isNextRedirect(error: unknown) {
  return (
    typeof error === "object" &&
    error !== null &&
    "digest" in error &&
    String((error as { digest?: unknown }).digest).startsWith("NEXT_REDIRECT")
  );
}

// Keep the operator's search, tab and page after a decision. Only same-page
// relative targets are accepted.
function returnTarget(path: string, formData?: FormData) {
  const raw = formData ? formString(formData, "returnTo") : "";
  if (!raw.startsWith(path) || raw.startsWith("//") || /[\r\n\\]/.test(raw)) return { path, query: new URLSearchParams() };
  const url = new URL(raw, "https://admin.invalid");
  // Same page or one of its sub-pages (e.g. /users/<id> after a decision).
  if (url.pathname !== path && !url.pathname.startsWith(`${path}/`)) return { path, query: new URLSearchParams() };
  url.searchParams.delete("admin_error");
  url.searchParams.delete("admin_success");
  return { path: url.pathname, query: url.searchParams };
}

function withNotice(
  target: { path: string; query: URLSearchParams },
  key: "admin_error" | "admin_success",
  message: string,
): never {
  const query = new URLSearchParams(target.query);
  query.set(key, message);
  redirect(`${target.path}?${query.toString()}`);
}

async function guardedAction(
  path: string,
  work: () => Promise<void>,
  successMessage = "Action completed.",
  formData?: FormData,
) {
  const target = returnTarget(path, formData);
  try {
    await work();
  } catch (error) {
    if (isNextRedirect(error)) throw error;
    withNotice(target, "admin_error", actionMessage(error));
  }
  // The layout re-renders with the action response, so the sidebar counts
  // update together with the page.
  revalidatePath(path);
  withNotice(target, "admin_success", successMessage);
}

export async function accountAction(formData: FormData) {
  await guardedAction("/users", async () => {
    const admin = await requireAdmin();
    const parsed = accountActionSchema.parse({
      userId: formData.get("userId"),
      action: formData.get("action"),
      reason: formString(formData, "reason"),
    });
    assertAccountActionRole(admin, parsed.action);
    await run("admin_account_action", { p_user_id: parsed.userId, p_action: parsed.action, p_reason: parsed.reason });
  }, "Member updated.", formData);
}
export async function bulkAccountAction(formData: FormData) {
  await guardedAction("/users", async () => {
    const admin = await requireAdmin();
    const parsed = bulkAccountActionSchema.parse({
      userIds: formData.getAll("userIds"),
      action: formData.get("action"),
      reason: formString(formData, "reason"),
    });
    assertAccountActionRole(admin, parsed.action);
    await run("admin_bulk_account_action", {
      p_user_ids: parsed.userIds,
      p_action: parsed.action,
      p_reason: parsed.reason,
    });
  }, "Bulk action completed.", formData);
}

export type RevealState =
  | { status: "idle" }
  | { status: "revealed"; userId: string; name: string; email: string | null }
  | { status: "error"; message: string };

// A POST, not a GET link: the audited read happens once per deliberate click
// and never on refresh, back-navigation or link prefetch.
export async function revealUserPii(_previous: RevealState, formData: FormData): Promise<RevealState> {
  try {
    const admin = await requireAdmin();
    assertCan(admin, "revealPii");
    const parsed = revealSchema.parse({
      userId: formData.get("userId"),
      reason: formData.get("reason"),
    });
    const supabase = await createClient();
    const { data, error } = await supabase.rpc("admin_reveal_user_pii", {
      p_user_id: parsed.userId,
      p_reason: parsed.reason,
    });
    if (error) throw new Error(error.message);
    const row = (data as { user_id: string; name: string; email: string | null }[])[0];
    if (!row) return { status: "error", message: "No member was found for this ID." };
    return { status: "revealed", userId: row.user_id, name: row.name, email: row.email };
  } catch (error) {
    if (isNextRedirect(error)) throw error;
    return { status: "error", message: actionMessage(error) };
  }
}

export async function reviewPhotoVerification(formData: FormData) {
  await guardedAction("/photo-verification", async () => {
    const admin = await requireAdmin();
    assertCan(admin, "reviewPhotos");
    const parsed = photoVerificationReviewSchema.parse({
      submissionId: formData.get("submissionId"),
      decision: formData.get("decision"),
      reason: formString(formData, "reason"),
      samePerson: formData.get("samePerson") === "on",
      clearCapture: formData.get("clearCapture") === "on",
      currentPhotoMatch: formData.get("currentPhotoMatch") === "on",
    });
    await run("admin_review_photo_verification", {
      p_submission_id: parsed.submissionId,
      p_decision: parsed.decision,
      p_reason: parsed.reason,
      p_same_person: parsed.samePerson,
      p_clear_capture: parsed.clearCapture,
      p_current_photo_match: parsed.currentPhotoMatch,
    });
    // Delete captures immediately after the decision. The five-minute worker
    // remains an idempotent fallback for storage or network failures.
    const service = createAdminClient();
    const { data: claimed } = await service.rpc(
      "checkout_photo_verification_purges",
      { p_limit: 25 },
    );
    const current = (claimed ?? []).find(
      (row: { submission_id?: string }) => row.submission_id === parsed.submissionId,
    );
    if (current) {
      const paths = [current.neutral_path, current.smile_path, current.blink_path]
        .filter((path): path is string => typeof path === "string" && path.length > 0);
      const { error: removeError } = paths.length === 0
        ? { error: null }
        : await service.storage.from("photo-verification-captures").remove(paths);
      await service.rpc("finish_photo_verification_purge", {
        p_submission_id: parsed.submissionId,
        p_success: !removeError,
        p_error: removeError?.message ?? null,
      });
    }
  }, "Photo check saved. Capture deletion has started.", formData);
}
export async function resolveReport(formData: FormData) {
  await guardedAction("/moderation", async () => {
    const admin = await requireAdmin();
    assertCan(admin, "resolveReports");
    const parsed = reportSchema.parse({
      reportId: formData.get("reportId"),
      action: formData.get("action"),
    });
    await claimWorkItem("report", parsed.reportId);
    await run("admin_resolve_report", { p_report_id: parsed.reportId, p_action: parsed.action });
  }, "Report decision saved.", formData);
}
export async function resolveMessageReport(formData: FormData) {
  await guardedAction("/moderation", async () => {
    const admin = await requireAdmin();
    assertCan(admin, "resolveReports");
    const parsed = messageReportSchema.parse({
      reportId: formData.get("reportId"),
      action: formData.get("action"),
    });
    await claimWorkItem("message_report", parsed.reportId);
    await run("admin_resolve_message_report", {
      p_report_id: parsed.reportId,
      p_action: parsed.action,
    });
  }, "Message report decision saved.", formData);
}
export async function reviewPhoto(formData: FormData) {
  await guardedAction("/moderation", async () => {
    const admin = await requireAdmin();
    assertCan(admin, "reviewPhotos");
    const parsed = photoReviewSchema.parse({
      photoId: formData.get("photoId"),
      decision: formData.get("decision"),
      reason: formString(formData, "reason") || (formData.get("decision") === "approve" ? "Manual profile photo review approved." : ""),
    });
    await claimWorkItem("photo", parsed.photoId);
    await run("admin_review_photo", { p_photo_id: parsed.photoId, p_decision: parsed.decision, p_reason: parsed.reason });
  }, "Photo decision saved.", formData);
}
export async function createCampaign(formData: FormData) {
  await guardedAction("/campaigns", async () => {
    const admin = await requireAdmin();
    assertCan(admin, "manageCampaigns");
    const parsed = campaignSchema.parse({
      title: formData.get("title"),
      body: formData.get("body"),
      deepLink: formData.get("deepLink") ?? "",
      audience: formData.get("audience") || "all",
      countryCode: formData.get("countryCode") ?? "",
      scheduledAt: formData.get("scheduledAt"),
    });
    await run("admin_create_push_campaign", {
      p_title: parsed.title,
      p_body: parsed.body,
      p_deep_link: parsed.deepLink,
      p_audience: parsed.audience,
      p_country_code: parsed.audience === "country" ? parsed.countryCode : "",
      p_scheduled_at: parsed.scheduledAt,
    });
  }, "Campaign draft created. Queue it when you are ready.", formData);
}
export async function queueCampaign(formData: FormData) {
  await guardedAction("/campaigns", async () => {
    const admin = await requireAdmin();
    assertCan(admin, "manageCampaigns");
    await run("admin_queue_push_campaign", { p_campaign_id: uuidSchema.parse(formData.get("campaignId")) });
  }, "Campaign queued for delivery.", formData);
}
export async function upsertContentPage(formData: FormData) {
  await guardedAction("/content", async () => {
    const admin = await requireAdmin();
    assertCan(admin, "publishContent");
    const parsed = contentSchema.parse({
      slug: formData.get("slug"),
      locale: formData.get("locale") || "en",
      title: formData.get("title"),
      body: formData.get("body"),
    });
    await run("admin_upsert_content_page", {
      p_slug: parsed.slug,
      p_locale: parsed.locale,
      p_title: parsed.title,
      p_body: parsed.body,
    });
  }, "Page saved.", formData);
}
export async function setContentStatus(formData: FormData) {
  await guardedAction("/content", async () => {
    const admin = await requireAdmin();
    assertCan(admin, "publishContent");
    const parsed = contentStatusSchema.parse({
      pageId: formData.get("pageId"),
      status: formData.get("status"),
    });
    await run("admin_set_content_status", { p_page_id: parsed.pageId, p_status: parsed.status });
  }, "Page status updated.", formData);
}
export async function addSuccessStory(formData: FormData) {
  await guardedAction("/stories", async () => {
    const admin = await requireAdmin();
    assertCan(admin, "manageStories");
    const parsed = successStorySchema.parse({
      coupleName: formData.get("coupleName"),
      countryCode: formData.get("countryCode") ?? "",
      story: formData.get("story"),
      photoPath: formData.get("photoPath") ?? "",
    });
    await run("admin_add_success_story", {
      p_couple_name: parsed.coupleName,
      p_country_code: parsed.countryCode,
      p_story: parsed.story,
      p_photo_path: parsed.photoPath,
    });
  }, "Story added.", formData);
}
export async function reviewSuccessStory(formData: FormData) {
  await guardedAction("/stories", async () => {
    const admin = await requireAdmin();
    assertCan(admin, "manageStories");
    const parsed = successStoryReviewSchema.parse({
      storyId: formData.get("storyId"),
      status: formData.get("status"),
    });
    await run("admin_review_success_story", { p_story_id: parsed.storyId, p_status: parsed.status });
  }, "Story updated.", formData);
}

export async function inviteStaffMember(formData: FormData) {
  await guardedAction("/staff", async () => {
    const admin = await requireAdmin();
    assertCan(admin, "manageStaff");
    const parsed = staffSchema.parse({
      email: formData.get("email"),
      role: formData.get("role"),
    });

    const adminClient = createAdminClient();
    const redirectBase = adminSiteUrl();

    const { error } = await adminClient.auth.admin.inviteUserByEmail(
      parsed.email,
      {
        data: { staff: true, role: parsed.role },
        redirectTo: `${redirectBase}/login`,
      },
    );

    const message = error?.message.toLowerCase() ?? "";
    if (error && !message.includes("already") && !message.includes("registered")) {
      throw new Error(error.message);
    }

    await run("admin_add_staff_member", {
      p_email: parsed.email,
      p_role: parsed.role,
    });
  }, "Staff invite sent.", formData);
}
export async function updateStaffMember(formData: FormData) {
  await guardedAction("/staff", async () => {
    const admin = await requireAdmin();
    assertCan(admin, "manageStaff");
    const parsed = staffUpdateSchema.parse({
      userId: formData.get("userId"),
      role: formData.get("role"),
      status: formData.get("status"),
      mfaRequired: formData.get("mfaRequired") === "on",
    });
    if (parsed.userId === admin.id && (parsed.status !== "active" || parsed.role !== "super_admin")) {
      throw new UserFacingError("You cannot demote or revoke your own access. Ask another super admin.");
    }
    await run("admin_update_staff_member", {
      p_user_id: parsed.userId,
      p_role: parsed.role,
      p_status: parsed.status,
      p_mfa_required: parsed.mfaRequired,
    });
  }, "Staff member updated.", formData);
}
export async function markAdminNotificationRead(formData: FormData) {
  await guardedAction("/inbox", async () => {
    await requireAdmin();
    await run("admin_mark_notification_read", {
      p_notification_id: uuidSchema.parse(formString(formData, "notificationId")),
    });
  }, "Marked as read.", formData);
}
export async function markAllAdminNotificationsRead(formData?: FormData) {
  await guardedAction("/inbox", async () => {
    await requireAdmin();
    await run("admin_mark_all_notifications_read", {});
  }, "All alerts marked as read.", formData);
}

function adminSiteUrl() {
  if (process.env.NEXT_PUBLIC_ADMIN_SITE_URL) {
    return process.env.NEXT_PUBLIC_ADMIN_SITE_URL.replace(/\/$/, "");
  }
  if (process.env.NODE_ENV !== "production") {
    return "http://localhost:3001";
  }
  throw new Error("NEXT_PUBLIC_ADMIN_SITE_URL is required before staff invites can be sent in production.");
}

const deletionSchema = z.object({
  userId: uuidSchema,
  reason: z.string().trim()
    .min(6, "Give a reason of at least 6 characters for the audit log.")
    .max(500),
  immediate: z.enum(["true", "false"]).default("false"),
});
const testPremiumSchema = z.object({
  userId: uuidSchema,
  days: z.coerce.number().int().min(1, "Choose 1 to 7 days.").max(7, "Choose 1 to 7 days."),
  note: z.string().trim().max(200).optional().default(""),
});

// Database messages that are safe and useful to show to staff as written.
const accountErrors = [
  "already scheduled or removed",
  "purge has already started",
  "Only an active, unbanned member",
  "1 to 7 days",
];

async function runAccountRpc<T>(name: string, values: Record<string, unknown>) {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc(name, values);
  if (error) {
    const known = accountErrors.find((fragment) => error.message.includes(fragment));
    if (known) throw new UserFacingError(error.message);
    throw new Error(error.message);
  }
  return data as T;
}

// Deletion controls appear on the queue and on a member's page; return to
// whichever one was used.
function deletionReturnPath(formData: FormData) {
  return formString(formData, "returnTo").startsWith("/users/") ? "/users" : "/deletions";
}

export async function scheduleAccountDeletion(formData: FormData) {
  const immediate = formString(formData, "immediate") === "true";
  await guardedAction(deletionReturnPath(formData), async () => {
    const admin = await requireAdmin();
    assertCan(admin, "manageDeletions");
    const parsed = deletionSchema.parse({
      userId: formData.get("userId"),
      reason: formData.get("reason"),
      immediate: immediate ? "true" : "false",
    });
    await runAccountRpc("admin_schedule_account_deletion", {
      p_user_id: parsed.userId,
      p_reason: parsed.reason,
      p_immediate: parsed.immediate === "true",
    });
  }, immediate
    ? "Deletion started. The account will be purged within minutes and the member emailed."
    : "Deletion scheduled for 30 days from now. The member has been emailed.", formData);
}

export async function cancelAccountDeletion(formData: FormData) {
  await guardedAction(deletionReturnPath(formData), async () => {
    const admin = await requireAdmin();
    assertCan(admin, "manageDeletions");
    const parsed = deletionSchema.parse({
      userId: formData.get("userId"),
      reason: formData.get("reason"),
    });
    const cancelled = await runAccountRpc<boolean>("admin_cancel_account_deletion", {
      p_user_id: parsed.userId,
      p_reason: parsed.reason,
    });
    if (!cancelled) throw new UserFacingError("This account is not waiting for deletion.");
  }, "Deletion cancelled. The member has been emailed.", formData);
}

export async function grantTestPremium(formData: FormData) {
  await guardedAction("/users", async () => {
    const admin = await requireAdmin();
    assertCan(admin, "grantTestPremium");
    const parsed = testPremiumSchema.parse({
      userId: formData.get("userId"),
      days: formData.get("days"),
      note: formData.get("note") ?? "",
    });
    await runAccountRpc("admin_grant_test_premium", {
      p_user_id: parsed.userId,
      p_days: parsed.days,
      p_note: parsed.note,
    });
  }, "Test Premium granted.", formData);
}

export async function revokeTestPremium(formData: FormData) {
  await guardedAction("/users", async () => {
    const admin = await requireAdmin();
    assertCan(admin, "grantTestPremium");
    const userId = uuidSchema.parse(formData.get("userId"));
    await runAccountRpc("admin_revoke_test_premium", { p_user_id: userId });
  }, "Test Premium removed.", formData);
}
