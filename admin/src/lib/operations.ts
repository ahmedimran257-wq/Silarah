import "server-only";

import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";

export type DashboardMetrics = Record<string, number>;

export type Cursor = { at: string; id: string };
export type KeysetPage<T> = { rows: T[]; next: Cursor | null };

async function rpc<T>(name: string, args?: Record<string, unknown>): Promise<T> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc(name, args);
  if (error) throw new Error(`Silarah data request ${name} failed.`);
  return data as T;
}

// Cursors travel in the URL as "<iso timestamp>~<uuid>".
export function parseCursor(raw?: string | null): Cursor | null {
  if (!raw) return null;
  const [at, id] = raw.split("~");
  if (!at || !id || !/^\d{4}-\d{2}-\d{2}[T ][\d:.]+(Z|[+-]\d{2}(:?\d{2})?)$/.test(at)) return null;
  if (!/^[0-9a-f-]{36}$/i.test(id)) return null;
  return { at, id };
}

export function encodeCursor(cursor: Cursor) {
  return `${cursor.at}~${cursor.id}`;
}

// Ask for one extra row so "is there a next page" costs nothing extra.
async function keyset<T>(
  name: string,
  args: Record<string, unknown>,
  limit: number,
  cursorOf: (row: T) => Cursor,
): Promise<KeysetPage<T>> {
  const rows = await rpc<T[]>(name, { ...args, p_limit: limit + 1 });
  const page = rows.slice(0, limit);
  const last = page.at(-1);
  return { rows: page, next: rows.length > limit && last ? cursorOf(last) : null };
}

export type DashboardOverview = {
  metrics: DashboardMetrics | null;
  live: LiveOperationsSnapshot | null;
  onlineUsers: OnlineUserRow[];
};

export const getDashboardOverview = () =>
  rpc<DashboardOverview>("admin_dashboard_overview", { p_online_limit: 12 });

export const userPageSize = 50;
export function getUsers(query: string, cursor: Cursor | null) {
  return keyset<UserRow>(
    "admin_user_directory_keyset",
    {
      p_query: query,
      p_cursor_joined_at: cursor?.at ?? null,
      p_cursor_id: cursor?.id ?? null,
    },
    userPageSize,
    (row) => ({ at: row.joined_at, id: row.user_id }),
  );
}

export async function getRevealedUserPii(userId: string, reason: string) {
  const rows = await rpc<RevealedUserPii[]>("admin_reveal_user_pii", {
    p_user_id: userId,
    p_reason: reason,
  });
  return rows[0] ?? null;
}

const signedUrlSeconds = 60 * 5;

export async function getPhotoVerificationQueue(): Promise<PhotoVerificationRow[]> {
  const rows = await rpc<PhotoVerificationRow[]>("admin_photo_verification_queue", { p_limit: 25 });
  if (rows.length === 0) return rows;

  const adminClient = createAdminClient();
  const [profileResult, captureResult] = await Promise.all([
    adminClient.storage.from("profile-photos").createSignedUrls(
      rows.map((row) => row.primary_photo_path),
      signedUrlSeconds,
    ),
    adminClient.storage.from("photo-verification-captures").createSignedUrls(
      rows.flatMap((row) => [row.neutral_path, row.smile_path, row.blink_path]),
      signedUrlSeconds,
    ),
  ]);
  const profileSignedByPath = new Map(
    (profileResult.data ?? []).map((entry) => [entry.path, entry.signedUrl ?? null]),
  );
  const captureSignedByPath = new Map(
    (captureResult.data ?? []).map((entry) => [entry.path, entry.signedUrl ?? null]),
  );
  const previewError = profileResult.error || captureResult.error
    ? "Private photo previews are temporarily unavailable."
    : null;
  return rows.map((row) => ({
    ...row,
    primary_photo_url: profileSignedByPath.get(row.primary_photo_path) ?? null,
    neutral_url: captureSignedByPath.get(row.neutral_path) ?? null,
    smile_url: captureSignedByPath.get(row.smile_path) ?? null,
    blink_url: captureSignedByPath.get(row.blink_path) ?? null,
    preview_error: previewError,
  }));
}

export const getReports = () => rpc<ReportRow[]>("admin_reports_queue", { p_limit: 100 });
export const getMessageReports = () => rpc<MessageReportRow[]>("admin_message_reports_queue", { p_limit: 100 });
export const getDiscoveryEligibility = (query = "") =>
  rpc<DiscoveryEligibilityRow[]>("admin_discovery_eligibility", {
    p_search: query,
    p_limit: 25,
  });

export async function getPhotos(): Promise<PhotoRow[]> {
  const rows = await rpc<PhotoRow[]>("admin_photo_queue", { p_limit: 60 });
  if (rows.length === 0) return rows;

  const adminClient = createAdminClient();
  const { data, error } = await adminClient.storage
    .from("profile-photos")
    .createSignedUrls(rows.map((photo) => photo.storage_path), signedUrlSeconds);
  const signedByPath = new Map(
    (data ?? []).map((entry) => [entry.path, entry.signedUrl ?? null]),
  );
  return rows.map((photo) => ({
    ...photo,
    preview_url: signedByPath.get(photo.storage_path) ?? null,
    preview_error: error ? "Photo previews are temporarily unavailable." : null,
  }));
}

// One audited RPC, then one batched storage call to sign every photo.
export async function getMemberReview(userId: string, reportId: string | null): Promise<MemberReview | null> {
  const review = await rpc<MemberReview | null>("admin_member_review", {
    p_user_id: userId,
    p_report_id: reportId,
  });
  if (!review || review.photos.length === 0) return review;

  const adminClient = createAdminClient();
  const { data, error } = await adminClient.storage
    .from("profile-photos")
    .createSignedUrls(review.photos.map((photo) => photo.storagePath), signedUrlSeconds);
  const signedByPath = new Map(
    (data ?? []).map((entry) => [entry.path, entry.signedUrl ?? null]),
  );
  return {
    ...review,
    photos: review.photos.map((photo) => ({
      ...photo,
      previewUrl: signedByPath.get(photo.storagePath) ?? null,
    })),
    previewError: error ? "Photo previews are temporarily unavailable." : null,
  };
}

export const getCampaignCountries = () => rpc<CampaignCountry[]>("admin_campaign_countries");

export const getMatchMetrics = () => rpc<DashboardMetrics>("admin_match_metrics");
export const getMatches = () => rpc<MatchRow[]>("admin_active_matches", { p_limit: 100 });
export const getSubscribers = () => rpc<SubscriberRow[]>("admin_subscribers", { p_limit: 100 });
export const getSubscriptionSummary = () => rpc<SubscriptionSummary>("admin_subscription_summary");
export const getCampaigns = () => rpc<CampaignRow[]>("admin_push_campaigns", { p_limit: 100 });
export const getContentPages = () => rpc<ContentPageRow[]>("admin_content_pages", { p_limit: 100 });
export const getSuccessStories = () => rpc<SuccessStoryRow[]>("admin_success_stories", { p_limit: 100 });
export const getStaffMembers = () => rpc<StaffMemberRow[]>("admin_staff_members", { p_limit: 100 });
export const getSystemHealth = () => rpc<DashboardMetrics>("admin_system_health");
export const getLocalizationOverview = () => rpc<LocalizationRow[]>("admin_localization_overview");
export const getSecurityMetrics = () => rpc<DashboardMetrics>("admin_security_metrics");

export const auditPageSize = 50;
export function getAuditFeed(cursor: Cursor | null, action: string) {
  return keyset<AuditRow>(
    "admin_audit_feed_page",
    {
      p_cursor_created_at: cursor?.at ?? null,
      p_cursor_id: cursor?.id ?? null,
      p_action: action || null,
    },
    auditPageSize,
    (row) => ({ at: row.created_at, id: row.audit_id }),
  );
}

export const inboxPageSize = 40;
export function getAdminInbox(unreadOnly: boolean, cursor: Cursor | null) {
  return keyset<AdminNotificationRow>(
    "admin_inbox_page",
    {
      p_unread_only: unreadOnly,
      p_cursor_created_at: cursor?.at ?? null,
      p_cursor_id: cursor?.id ?? null,
    },
    inboxPageSize,
    (row) => ({ at: row.created_at, id: row.notification_id }),
  );
}

export type UserRow = { user_id:string; profile_id:string; name:string; email:string|null; country_code:string; gender:string; joined_at:string; last_active_at:string|null; onboarding_step:number; completeness_score:number; visibility:string; is_banned:boolean; is_shadowbanned:boolean; subscription_status:string; verification_status:string; has_verification_badge:boolean; can_approve_profile:boolean; approval_block_reason:string|null };
export type RevealedUserPii = { user_id:string; name:string; email:string|null; revealed_at:string };
export type PhotoVerificationRow = {
  submission_id:string; user_id:string; profile_id:string; member_name:string;
  submitted_at:string; review_deadline:string; guidance_mode:string;
  primary_photo_path:string; neutral_path:string; smile_path:string; blink_path:string;
  primary_photo_url?:string|null; neutral_url?:string|null;
  smile_url?:string|null; blink_url?:string|null; preview_error?:string|null;
};
export type ReportRow = { report_id:string; reporter_id:string; reported_user_id:string; reason:string; description:string|null; created_at:string; report_count:number; reported_name:string };
export type MessageReportRow = { report_id:string; message_id:string; match_id:string; reporter_id:string; reported_user_id:string; reported_name:string; reason:string; description:string|null; message_content:string; created_at:string };
export type DiscoveryEligibilityRow = { profile_id:string; user_id:string; member_name:string; gender:string; created_at:string; eligible:boolean; exclusion_reasons:string[]; diagnostic_notes:string[]; approved_photo_count:number };
export type PhotoRow = { photo_id:string; user_id:string; name:string; storage_path:string; nsfw_score:number|null; nsfw_category:string|null; created_at:string; moderation_status:string; preview_url?:string|null; preview_error?:string|null };
export type MatchRow = { match_id:string; user_a_name:string; user_b_name:string; created_at:string; message_count:number; last_message_at:string|null };
export type SubscriberRow = { user_id:string; name:string; country_code:string; subscription_status:string; subscription_expires_at:string|null; product_id:string|null; total_paid:number };
export type SubscriptionSummary = { active:number; grace:number; refunds:number; revenue:{ currency:string; gross:number }[] };
export type CampaignRow = { campaign_id:string; title:string; body:string; deep_link:string|null; audience:string; country_code:string|null; scheduled_at:string; status:string; queued_count:number; created_at:string; queued_at:string|null };
export type ContentPageRow = { page_id:string; slug:string; locale:string; title:string; body:string; status:string; updated_at:string; published_at:string|null };
export type SuccessStoryRow = { story_id:string; couple_name:string; country_code:string|null; story:string; photo_path:string|null; status:string; created_at:string; published_at:string|null };
export type StaffMemberRow = { user_id:string; email:string; role:string; status:string; mfa_required:boolean; created_at:string; last_sign_in_at:string|null };
export type LocalizationRow = { locale:string; page_count:number; published_count:number; last_updated:string|null };
export type LiveBucket = Record<string, number>;
export type LiveOperationsSnapshot = { generatedAt:number; traffic:LiveBucket; engagement:LiveBucket; progress:LiveBucket; queues:LiveBucket; pipeline:LiveBucket };
export type OnlineUserRow = { user_id:string; profile_id:string|null; name:string; email:string|null; country_code:string|null; gender:string|null; last_seen_at:string; app_state:string; platform:string|null; visibility:string; verification_status:string; subscription_status:string };
export type AuditRow = { audit_id:string; admin_id:string; admin_email:string|null; actor_role:string|null; action_type:string; target_user_id:string|null; details:Record<string, unknown>|null; created_at:string };
export type AdminNotificationRow = { notification_id:string; type:string; message:string; related_user_id:string|null; is_read:boolean; created_at:string };
export type MemberReviewPhoto = { id:string; storagePath:string; orderIndex:number; status:string; adminApproved:boolean; nsfwCleared:boolean; nsfwScore:number|null; nsfwCategory:string|null; moderationStatus:string|null; moderationReason:string|null; createdAt:string; previewUrl?:string|null };
export type MemberReviewReport = { id:string; reason:string; description:string|null; status:string; created_at:string; reporterTrust:number|null };
export type MemberReview = {
  userId:string; profileId:string; displayName:string; age:number|null; gender:string|null; countryCode:string|null; city:string|null; region:string|null;
  bio:string|null; profession:string|null; employmentStatus:string|null; educationLevel:string|null; fieldOfStudy:string|null; sect:string|null; deenLevel:string|null;
  praysFiveDaily:boolean|null; heightCm:number|null; motherTongue:string|null; languages:string[]|null; interests:string[]|null; previouslyMarried:string|null;
  childrenCount:number|null; marriageTimeline:string|null; profileCreatedBy:string|null; guardianMode:string|null; visibility:string; suspendedReason:string|null;
  onboardingCompleted:boolean; completenessScore:number|null; approvedAt:string|null; hasVerificationBadge:boolean; photoVerifiedAt:string|null; lastActiveAt:string|null;
  joinedAt:string; email:string|null; isBanned:boolean; isShadowbanned:boolean; deletedAt:string|null; subscriptionStatus:string|null;
  photos:MemberReviewPhoto[]; reportsAgainst:MemberReviewReport[];
  reportCounts:{ total:number; pending:number; filedByMember:number; messageReports:number; messageReportsPending:number };
  previewError?:string|null;
};
export type CampaignCountry = { iso_code:string; name:string; members:number };

export type AccountDeletionRow = {
  userId: string;
  email: string | null;
  name: string | null;
  requestedAt: string | null;
  purgeAfter: string;
  reason: string | null;
  byStaff: boolean;
  source?: "email" | "staff" | "app";
  purgePhase: string | null;
  purgeStatus: string | null;
  purgeAttempts: number | null;
  purgeError: string | null;
};

export type AccountDeletionQueue = {
  pending: AccountDeletionRow[];
  stuck: {
    userId: string;
    phase: string;
    status: string;
    attempts: number;
    error: string | null;
    nextAttemptAt: string | null;
  }[];
  completedLast30Days: number;
  emailsWaiting: number;
  emailsFailed: number;
};

export async function getAccountDeletions(): Promise<AccountDeletionQueue> {
  return rpc<AccountDeletionQueue>("admin_account_deletions", { p_limit: 200 });
}

export type MemberAccountState = {
  deletionStatus: "active" | "pending_deletion" | "purged";
  requestedAt: string | null;
  purgeAfter: string | null;
  deletionReason: string | null;
  purgePhase: string | null;
  purgeStatus: string | null;
  canCancelDeletion: boolean;
  paidStatus: string | null;
  paidUntil: string | null;
  testPremiumUntil: string | null;
};

export async function getMemberAccountState(userId: string): Promise<MemberAccountState | null> {
  return rpc<MemberAccountState | null>("admin_member_account_state", { p_user_id: userId });
}

export type MemberNote = {
  id: string;
  body: string;
  createdAt: string;
  author: string | null;
  authorRole: string | null;
};

export async function getMemberNotes(userId: string): Promise<MemberNote[]> {
  return rpc<MemberNote[]>("admin_member_notes", { p_user_id: userId });
}

export type BlockedTerm = {
  term: string;
  severity: "block" | "flag";
  reason: string | null;
  created_at: string;
};

export async function getBlockedTerms(): Promise<BlockedTerm[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("chat_blocked_terms")
    .select("term,severity,reason,created_at")
    .order("term");
  if (error) throw new Error("Silarah data request chat_blocked_terms failed.");
  return (data ?? []) as BlockedTerm[];
}

export type ReferralGrant = {
  id: string;
  role: "referrer" | "referred";
  startsAt: string;
  expiresAt: string;
  active: boolean;
};

export type ReferralRow = {
  id: string;
  createdAt: string;
  referrerId: string;
  referrer: string | null;
  referredId: string;
  referred: string | null;
  rewarded: boolean;
  rewardType: string | null;
  grants: ReferralGrant[];
};

export type ReferralOverview = {
  totals: { referrals: number; rewarded: number; activeGrants: number };
  referrals: ReferralRow[];
};

export async function getReferralOverview(): Promise<ReferralOverview> {
  return rpc<ReferralOverview>("admin_referral_overview", { p_limit: 200 });
}
