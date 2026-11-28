import { Phone, PhoneOff, Search } from "lucide-react";
import Link from "next/link";
import { SubmitButton } from "@/components/client-ui";
import { EmptyState, NoAccess, PageHeader, Stat, StatusPill, formatDateTime } from "@/components/ui";
import { can } from "@/lib/access";
import { requireArea } from "@/lib/auth";
import {
  getCallOverview,
  getMemberCallHistory,
  getUnclaimedCallPacks,
  type CallOverview,
  type MemberCallRow,
  type UnclaimedCallPack,
} from "@/lib/operations";
import { adjustCallMinutes, claimCallPack, setCallsEnabled } from "../actions";

// Voice calling for staff (docs/voice_calling_spec.md 12.8): the switch, this
// month's minutes against the brake and the Stream cost, one member's call
// history for an open case, and support corrections of pack minutes. Only
// metadata: audio is never recorded or stored.

export const metadata = { title: "Voice calls" };
export const dynamic = "force-dynamic";

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function duration(seconds: number | null) {
  if (!seconds) return "—";
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${String(s).padStart(2, "0")}`;
}

export default async function CallsPage({ searchParams }: { searchParams: Promise<{ member?: string }> }) {
  const { admin, allowed } = await requireArea("calls");
  if (!allowed) return <NoAccess area="Voice calls" />;
  const { member } = await searchParams;
  const memberId = member && uuid.test(member.trim()) ? member.trim() : null;

  let overview: CallOverview | null = null;
  try {
    overview = await getCallOverview();
  } catch {
    overview = null;
  }
  let history: MemberCallRow[] | null = null;
  if (memberId && can(admin.role, "viewCallHistory")) {
    try {
      history = await getMemberCallHistory(memberId);
    } catch {
      history = null;
    }
  }

  let unclaimed: UnclaimedCallPack[] | null = null;
  if (can(admin.role, "claimCallPacks")) {
    try {
      unclaimed = await getUnclaimedCallPacks();
    } catch {
      unclaimed = null;
    }
  }

  const used = overview?.month_charged_minutes ?? 0;
  const cap = overview?.effective_cap_minutes ?? 0;
  const percent = cap > 0 ? Math.round((used / cap) * 100) : 0;
  const returnTo = memberId ? `/calls?member=${memberId}` : "/calls";

  return (
    <div className="stack-lg">
      <PageHeader
        eyebrow="Members"
        title="Voice calls"
        lede="Calling between matches. Silarah keeps only when calls happened, their results and lengths — never audio. The monthly brake covers every member's included and pack minutes and stops only abnormal spend."
      />

      {overview === null ? (
        <section className="card"><p className="notice danger"><span>Calling data could not load.</span></p></section>
      ) : (
        <>
          <div className="row">
            <StatusPill status={overview.calls_enabled ? "active" : "suspended"} label={overview.calls_enabled ? "Calling on" : "Calling off"} />
            {overview.dead_jobs > 0 ? <span className="pill danger">{overview.dead_jobs} failed background jobs</span> : null}
          </div>
          <div className="stat-grid">
            <Stat label="Minutes this month" value={used.toLocaleString("en-IN")} hint={`${percent}% of the ${cap.toLocaleString("en-IN")}-minute brake`} />
            <Stat label="Estimated Stream cost" value={`$${Number(overview.estimated_stream_cost_usd ?? 0).toFixed(2)}`} hint="$0.30 per 1,000 participant minutes" />
            <Stat label="Live calls" value={overview.live_calls} />
            <Stat label="Calls · 24 h" value={overview.calls_today} />
            <Stat label="Minutes held now" value={overview.open_hold_minutes} />
          </div>

          {can(admin.role, "switchCalls") ? (
            <section className="card">
              <div className="card-head">
                <h2>{overview.calls_enabled ? <PhoneOff size={16} /> : <Phone size={16} />} Calling switch</h2>
              </div>
              <form action={setCallsEnabled} className="card-body stack">
                <input type="hidden" name="enabled" value={overview.calls_enabled ? "false" : "true"} />
                <input type="hidden" name="returnTo" value={returnTo} />
                <p className="muted">
                  {overview.calls_enabled
                    ? "Turning calling off ends live calls within seconds and hides calling everywhere in the app."
                    : "Turning calling on shows the Calls tab, call buttons and the Premium benefit to every member."}
                </p>
                <label className="field">Reason for the audit log
                  <input name="note" className="input" required minLength={6} maxLength={500} placeholder="e.g. All staging gates passed" />
                </label>
                <div className="form-actions">
                  <SubmitButton
                    className={overview.calls_enabled ? "btn btn-danger" : "btn btn-primary"}
                    confirm={overview.calls_enabled ? "Turn calling off for every member now?" : "Turn calling on for every member now?"}
                  >
                    {overview.calls_enabled ? "Turn calling off" : "Turn calling on"}
                  </SubmitButton>
                </div>
              </form>
            </section>
          ) : null}
        </>
      )}

      <section className="card">
        <div className="card-head"><h2><Search size={16} /> A member&apos;s calls</h2></div>
        <div className="card-body stack">
          <form method="get" className="action-row">
            <label className="field">Member ID
              <input name="member" className="input mono" defaultValue={memberId ?? ""} pattern="[0-9a-fA-F-]{36}" placeholder="00000000-0000-0000-0000-000000000000" />
            </label>
            <div className="form-actions"><button type="submit" className="btn">Show calls</button></div>
          </form>
          {memberId === null ? null : history === null ? (
            <p className="notice danger"><span>Calls could not load for this member.</span></p>
          ) : history.length === 0 ? (
            <EmptyState icon={Phone} title="No calls">This member has no call records in the retention period.</EmptyState>
          ) : (
            <div className="table-wrap">
              <table className="table">
                <thead>
                  <tr><th>When</th><th>Direction</th><th>Other member</th><th>Result</th><th>Talk time</th><th>Minutes</th></tr>
                </thead>
                <tbody>
                  {history.map((row) => (
                    <tr key={row.request_id}>
                      <td>{formatDateTime(row.created_at)}</td>
                      <td>{row.direction}</td>
                      <td><Link href={`/users/${row.other_user_id}`} prefetch={false} className="mono">{row.other_user_id.slice(0, 8)}</Link></td>
                      <td>{row.status}{row.reason ? ` · ${row.reason.replaceAll("_", " ")}` : ""}{row.hidden_by_member ? " · removed from their history" : ""}</td>
                      <td>{duration(row.connected_seconds)}</td>
                      <td>{row.charged_minutes ?? "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </section>

      {can(admin.role, "claimCallPacks") ? (
        <section className="card">
          <div className="card-head">
            <h2>Packs waiting for a member</h2>
            <span className="muted">Paid by a store account that matched no member · credited once, recorded in the audit log</span>
          </div>
          <div className="card-body stack">
            {unclaimed === null ? (
              <p className="notice danger"><span>Waiting packs could not load.</span></p>
            ) : unclaimed.length === 0 ? (
              <EmptyState icon={Phone} title="Nothing waiting">Every paid pack reached a member.</EmptyState>
            ) : (
              unclaimed.map((pack) => (
                <form key={pack.event_id} action={claimCallPack} className="stack">
                  <input type="hidden" name="eventId" value={pack.event_id} />
                  <input type="hidden" name="returnTo" value={returnTo} />
                  <p>
                    <strong>{pack.minutes ?? "?"} minutes</strong> ({pack.product_id}) · paid {formatDateTime(pack.event_at ?? pack.received_at)} · {pack.store ?? "store"}
                    {pack.environment && pack.environment !== "PRODUCTION" ? ` · ${pack.environment}` : ""}
                  </p>
                  <p className="muted mono">
                    Store ID {pack.app_user_id}
                    {pack.aliases.length > 0 ? ` · also ${pack.aliases.filter((a) => a !== pack.app_user_id).join(", ") || "none"}` : ""}
                    {pack.transaction_id ? ` · order ${pack.transaction_id}` : ""}
                  </p>
                  <label className="field">Member ID to credit
                    <input name="userId" className="input mono" required pattern="[0-9a-fA-F-]{36}" placeholder="Confirm the member from the Play order first" />
                  </label>
                  <label className="field">Reason
                    <input name="reason" className="input" required minLength={6} maxLength={500} placeholder="e.g. Play order matched to the member's email, ticket 1234" />
                  </label>
                  <div className="form-actions">
                    <SubmitButton className="btn" confirm="Credit this paid pack to that member? This cannot be undone here.">Credit pack</SubmitButton>
                  </div>
                </form>
              ))
            )}
          </div>
        </section>
      ) : null}

      {can(admin.role, "adjustCallMinutes") ? (
        <section className="card">
          <div className="card-head"><h2>Adjust pack minutes</h2><span className="muted">Support cases only · recorded in the ledger and audit log</span></div>
          <form action={adjustCallMinutes} className="card-body stack">
            {/* Found in gate 6 (25 Nov 2026): a Play Console refund without
                "Remove entitlement" never reaches Silarah, so the minutes stay. */}
            <p className="muted">
              Refunding a minute pack in Play Console (Order management)? Always tick <strong>Remove entitlement</strong>:
              Google then tells Silarah and the pack&apos;s minutes come off automatically within minutes. If a pack was
              refunded without it, remove its minutes here (for example −20 for a 20-minute pack) and note the order ID.
            </p>
            <input type="hidden" name="returnTo" value={returnTo} />
            <label className="field">Member ID
              <input name="userId" className="input mono" required defaultValue={memberId ?? ""} pattern="[0-9a-fA-F-]{36}" />
            </label>
            <label className="field">Minutes (negative to remove)
              <input name="minutes" type="number" className="input" required min={-1000} max={1000} step={1} />
            </label>
            <label className="field">Reason
              <input name="reason" className="input" required minLength={6} maxLength={500} placeholder="e.g. Call dropped on our side, ticket 1234" />
            </label>
            <div className="form-actions"><SubmitButton className="btn" confirm="Change this member's pack minutes?">Adjust minutes</SubmitButton></div>
          </form>
        </section>
      ) : null}
    </div>
  );
}
