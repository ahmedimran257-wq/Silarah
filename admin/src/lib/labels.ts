// Staff-facing names for database codes. Unknown codes fall back to the code
// with spaces, so a reason added later still shows, just less polished.

import type { CallSettingKey } from "@/lib/operations";

function fallback(code: string) {
  return code.replaceAll("_", " ");
}

/** Profile report reasons (public.reports.reason; harassing_calls from migration 323). */
export const reportReasonLabels: Record<string, string> = {
  fake_profile: "Fake profile",
  inappropriate_photos: "Inappropriate photos",
  harassment: "Harassment",
  harassing_calls: "Harassing calls",
  scam: "Scam",
  underage: "Underage",
  already_married: "Already married",
  offensive_bio: "Offensive bio",
  intimate_image: "Intimate image",
  other: "Other",
};

/** Reasons in the order staff filter by them: safety first. */
export const reportReasonOrder = [
  "harassing_calls", "harassment", "intimate_image", "underage", "scam",
  "fake_profile", "inappropriate_photos", "already_married", "offensive_bio", "other",
];

export function reportReason(code: string) {
  return reportReasonLabels[code] ?? fallback(code);
}

/** Chat "Report message" reasons (public.message_reports.reason). */
const messageReasonLabels: Record<string, string> = {
  harassment: "Harassment or pressure",
  contact_sharing: "Phone, social or link sharing",
  scam: "Scam or suspicious request",
  inappropriate: "Inappropriate message",
  other: "Other safety concern",
};

export function messageReason(code: string) {
  return messageReasonLabels[code] ?? reportReason(code);
}

const callStatusLabels: Record<string, string> = {
  ringing: "Ringing",
  accepted: "Answered",
  declined: "Declined",
  cancelled: "Cancelled by caller",
  missed: "Missed",
  unavailable: "Unavailable",
  failed: "Failed",
};

export function callResult(status: string, reason?: string | null) {
  const label = callStatusLabels[status] ?? fallback(status);
  return reason && reason !== status ? `${label} · ${fallback(reason)}` : label;
}

export const ledgerKindLabels: Record<string, string> = {
  pack_purchase: "Pack bought",
  pack_refund: "Pack refunded",
  pack_refund_reversal: "Refund reversed",
  included_forfeit: "Included minutes forfeited",
  charge: "Call charged",
  admin_adjust: "Staff adjustment",
  hold: "Held for a call",
  release: "Hold released",
};

export function ledgerKind(code: string) {
  return ledgerKindLabels[code] ?? fallback(code);
}

export function talkTime(seconds: number | null | undefined) {
  if (!seconds) return "—";
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${String(s).padStart(2, "0")}`;
}

/** What each tunable call setting does, for the /calls editor. */
export const callSettingInfo: Record<CallSettingKey, { label: string; unit: string; help: string; group: "money" | "safety" | "ringing" | "plans" }> = {
  monthly_cap_minutes: {
    label: "Monthly brake floor", unit: "minutes", group: "money",
    help: "Used when the hourly auto cap is older than 3 hours. The brake in force is the higher of this and the auto cap.",
  },
  included_minutes: {
    label: "Premium included minutes", unit: "minutes per period", group: "money",
    help: "Applies from each member's next period; current periods keep their grant. The Play listing and terms name this number.",
  },
  max_hold_minutes: {
    label: "Longest call", unit: "minutes", group: "money",
    help: "Minutes held when a call is answered; Stream ends the call after this plus the connecting allowance. New calls only.",
  },
  unanswered_call_limit: {
    label: "Unanswered calls before a pause", unit: "calls", group: "safety",
    help: "Calls in a row the other member does not pick up before the caller must wait. Shown to members.",
  },
  ring_timeout_seconds: {
    label: "Ring time", unit: "seconds", group: "ringing",
    help: "How long a call rings before it counts as missed. Shown to members.",
  },
  join_timeout_seconds: {
    label: "Join time after answering", unit: "seconds", group: "ringing",
    help: "If both phones have not joined the audio this long after answering, the call is ended.",
  },
  connect_allowance_seconds: {
    label: "Connecting allowance", unit: "seconds", group: "ringing",
    help: "Extra seconds Stream allows on top of the held minutes, so connecting time never cuts a call short.",
  },
  plan_min_lead_minutes: {
    label: "Shortest planning notice", unit: "minutes", group: "plans",
    help: "A planned call must be at least this far ahead. Not shorter than the reminder.",
  },
  plan_max_days_ahead: {
    label: "Furthest planned call", unit: "days ahead", group: "plans",
    help: "How far ahead members can plan a call.",
  },
  plan_window_minutes: {
    label: "Planned call window", unit: "minutes", group: "plans",
    help: "How long after the planned time Call now stays available.",
  },
  plan_reminder_minutes: {
    label: "Reminder before a planned call", unit: "minutes", group: "plans",
    help: "When both members are reminded.",
  },
  plan_max_open: {
    label: "Open plans per member", unit: "plans", group: "plans",
    help: "Planned calls a member can have waiting at once.",
  },
  plan_max_per_chat_day: {
    label: "Plans per chat per day", unit: "plans", group: "plans",
    help: "Stops repeated proposals in one chat.",
  },
};

export const callSettingGroups: { id: "money" | "safety" | "ringing" | "plans"; label: string }[] = [
  { id: "money", label: "Minutes and cost" },
  { id: "safety", label: "Safety" },
  { id: "ringing", label: "Ringing" },
  { id: "plans", label: "Planned calls" },
];

export function callSettingLabel(key: string) {
  return (callSettingInfo as Record<string, { label: string }>)[key]?.label ?? fallback(key);
}

/** Admin inbox item types (admin_notifications.type) and the page that handles each. */
const inboxTypes: Record<string, { label: string; href: (userId: string | null) => string | null }> = {
  member_report_received: { label: "Member report", href: () => "/moderation?tab=reports" },
  message_report_received: { label: "Reported message", href: () => "/moderation?tab=messages" },
  harassing_calls_report: { label: "Harassing-calls report", href: () => "/moderation?tab=reports&reason=harassing_calls" },
  privacy_request_received: { label: "New privacy request", href: () => "/privacy" },
  privacy_request_due_soon: { label: "Privacy request due in 2 days", href: () => "/privacy" },
  privacy_request_overdue: { label: "Privacy request overdue", href: () => "/privacy" },
  account_deletion_requested: { label: "Member asked to delete their account", href: () => "/deletions" },
  subscription_refunded: { label: "Premium refunded", href: () => "/subscriptions" },
  subscription_lapsed_without_store_update: { label: "Premium ended without a store update", href: (id) => (id ? `/users/${id}` : "/subscriptions") },
  call_pack_refunded: { label: "Minute pack refunded", href: (id) => (id ? `/calls?tab=member&member=${id}` : "/calls") },
  call_pack_unclaimed: { label: "Paid pack waiting for a member", href: () => "/calls?tab=packs" },
  system_health_alert: { label: "System alert", href: () => "/system" },
};

export function inboxType(type: string, userId: string | null) {
  const known = inboxTypes[type];
  return { label: known?.label ?? fallback(type), href: known?.href(userId) ?? null };
}
