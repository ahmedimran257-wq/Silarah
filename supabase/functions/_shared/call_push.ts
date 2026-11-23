// Data of the call pushes call-worker sends (docs/voice_calling_spec.md 12.3,
// 13). Data-only: the phone renders the text in its own language and shows
// one missed-call notification per caller.

export const MISSED_PUSH_TTL_SECONDS = 24 * 3600;
export const SEEN_PUSH_TTL_SECONDS = 3600;

/** Data of a missed-call push (call_service_missed_push decided to send). */
export function missedCallPush(info: Record<string, unknown>): Record<string, string> {
  return {
    type: "call_missed",
    request_id: String(info.request_id ?? ""),
    match_id: String(info.match_id ?? ""),
    caller_id: String(info.caller_id ?? ""),
    caller_name: String(info.caller_name ?? ""),
    count: String(Math.max(1, Number(info.count ?? 1))),
    variant: info.variant === "premium" || info.variant === "consent" ? String(info.variant) : "missed",
    silent: info.silent === true ? "1" : "0",
  };
}

/** A planned-call reminder lives until the plan's window closes. */
export function planReminderPush(
  row: Record<string, unknown>,
  now = Date.now(),
): { data: Record<string, string>; ttlSeconds: number } {
  const plannedFor = Date.parse(String(row.planned_for ?? ""));
  const windowEnd = Number.isFinite(plannedFor) ? plannedFor + 30 * 60_000 : now + 35 * 60_000;
  return {
    data: {
      type: "call_plan_reminder",
      plan_id: String(row.plan_id ?? ""),
      match_id: String(row.match_id ?? ""),
      other_name: String(row.other_name ?? ""),
      planned_for: String(row.planned_for ?? ""),
      // Quiet hours or Silent: shown without sound.
      silent: row.silent === true ? "1" : "0",
    },
    ttlSeconds: Math.max(60, Math.round((windowEnd - now) / 1000)),
  };
}
