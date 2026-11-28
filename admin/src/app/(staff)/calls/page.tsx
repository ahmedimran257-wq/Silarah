import { AlertTriangle, Phone, PhoneOff, RotateCcw, Search, SlidersHorizontal } from "lucide-react";
import Link from "next/link";
import { SubmitButton } from "@/components/client-ui";
import { MemberCallHistoryTable, MemberCallWalletCard } from "@/components/member-calls";
import { EmptyState, NoAccess, PageHeader, Stat, StatusPill, formatDateTime, relativeTime } from "@/components/ui";
import { can, type AdminRole } from "@/lib/access";
import { requireArea } from "@/lib/auth";
import { callSettingGroups, callSettingInfo, callSettingLabel } from "@/lib/labels";
import {
  getCallOperations,
  getCallOverview,
  getCallSettings,
  getMemberCallHistory,
  getMemberCallWallet,
  getUnclaimedCallPacks,
  type CallOperations,
  type CallOverview,
  type CallSettings,
  type MemberCallRow,
  type MemberCallWallet,
  type UnclaimedCallPack,
} from "@/lib/operations";
import { adjustCallMinutes, claimCallPack, retryCallJob, setCallsEnabled, updateCallSettings } from "../actions";

// Voice calling for staff (docs/voice_calling_spec.md 12.8, migration 339):
// the switch and what it costs, live calls and failed jobs, the tunable
// limits, one member's minutes and calls, and paid packs waiting for a
// member. Only metadata: audio is never recorded or stored.

export const metadata = { title: "Voice calls" };
export const dynamic = "force-dynamic";

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const tabs = ["overview", "settings", "member", "packs"] as const;
type Tab = (typeof tabs)[number];
const tabLabels: Record<Tab, string> = {
  overview: "Overview",
  settings: "Limits",
  member: "A member",
  packs: "Packs and corrections",
};

async function load<T>(work: () => Promise<T>): Promise<T | null> {
  try {
    return await work();
  } catch {
    return null;
  }
}

export default async function CallsPage({ searchParams }: { searchParams: Promise<{ member?: string; tab?: string }> }) {
  const { admin, allowed } = await requireArea("calls");
  if (!allowed) return <NoAccess area="Voice calls" />;
  const params = await searchParams;
  const memberId = params.member && uuid.test(params.member.trim()) ? params.member.trim() : null;
  const tab: Tab = tabs.find((key) => key === params.tab) ?? (memberId ? "member" : "overview");
  const returnTo = `/calls?tab=${tab}${memberId ? `&member=${memberId}` : ""}`;

  const overview = await load(getCallOverview);

  return (
    <div className="stack-lg">
      <PageHeader
        eyebrow="Members"
        title="Voice calls"
        lede="Calling between matches. Silarah keeps only when calls happened, their results and lengths — never audio. The monthly brake covers every member's included and pack minutes and stops only abnormal spend."
      />

      {overview ? (
        <div className="row">
          <StatusPill status={overview.calls_enabled ? "active" : "suspended"} label={overview.calls_enabled ? "Calling on" : "Calling off"} />
          {overview.dead_jobs > 0 ? <Link href="/calls?tab=overview#jobs" prefetch={false} className="pill danger">{overview.dead_jobs} failed {overview.dead_jobs === 1 ? "job" : "jobs"}</Link> : null}
          {(overview.retrying_jobs ?? 0) > 0 ? <span className="pill warn">{overview.retrying_jobs} retrying</span> : null}
          {(overview.unclaimed_packs ?? 0) > 0 ? <Link href="/calls?tab=packs" prefetch={false} className="pill warn">{overview.unclaimed_packs} paid {overview.unclaimed_packs === 1 ? "pack" : "packs"} waiting</Link> : null}
          {overview.calls_enabled && !overview.calling_consent_version ? <span className="pill plain">No calling-terms check yet</span> : null}
        </div>
      ) : null}

      <nav className="tabs" aria-label="Voice call areas">
        {tabs.map((key) => (
          <Link
            key={key}
            href={`/calls?tab=${key}${key === "member" && memberId ? `&member=${memberId}` : ""}`}
            prefetch={false}
            className={`tab${key === tab ? " is-active" : ""}`}
            aria-current={key === tab ? "page" : undefined}
          >
            {tabLabels[key]}
          </Link>
        ))}
      </nav>

      {tab === "overview" ? <OverviewTab overview={overview} role={admin.role} returnTo={returnTo} /> : null}
      {tab === "settings" ? <SettingsTab role={admin.role} returnTo={returnTo} /> : null}
      {tab === "member" ? <MemberTab memberId={memberId} role={admin.role} rawMember={params.member ?? ""} /> : null}
      {tab === "packs" ? <PacksTab memberId={memberId} role={admin.role} returnTo={returnTo} /> : null}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Overview: switch, usage against the brake, live calls, failed jobs
// ---------------------------------------------------------------------------

async function OverviewTab({ overview, role, returnTo }: { overview: CallOverview | null; role: AdminRole; returnTo: string }) {
  if (overview === null) {
    return <section className="card"><p className="notice danger"><span>Calling data could not load.</span></p></section>;
  }
  const ops = await load(getCallOperations);
  const used = overview.month_charged_minutes ?? 0;
  const cap = overview.effective_cap_minutes ?? 0;
  const percent = cap > 0 ? Math.round((used / cap) * 100) : 0;
  // The brake is the higher of the floor and an auto cap under 3 hours old.
  const floorApplies = cap === overview.monthly_cap_minutes;

  return (
    <>
      <div className="stat-grid">
        <Stat label="Minutes this month" value={used.toLocaleString("en-IN")} hint={`${percent}% of the ${cap.toLocaleString("en-IN")}-minute brake`} tone={percent >= 90 ? "alert" : undefined} />
        <Stat label="Estimated Stream cost" value={`$${Number(overview.estimated_stream_cost_usd ?? 0).toFixed(2)}`} hint="$0.30 per 1,000 participant minutes · free up to $100" />
        <Stat label="Live calls" value={overview.live_calls} hint={`${overview.ringing_now ?? 0} ringing now`} />
        <Stat label="Calls · 24 h" value={overview.calls_today} />
        <Stat label="Minutes held now" value={overview.open_hold_minutes} />
      </div>

      <section className="card">
        <div className="card-head"><h2>This month against the brake</h2><span className="muted">Months run on India time</span></div>
        <div className="card-body stack">
          <div className="meter-list">
            <div className={`meter-row${percent >= 70 ? " is-warning" : ""}`}>
              <div><span>Charged minutes</span><strong>{used.toLocaleString("en-IN")} / {cap.toLocaleString("en-IN")} ({percent}%)</strong></div>
              <progress className="meter" max={100} value={Math.min(100, percent)} aria-label={`Minutes used ${percent}% of the brake`} />
            </div>
          </div>
          <dl className="kv">
            <div><dt>Brake in force</dt><dd>{cap.toLocaleString("en-IN")} minutes · {floorApplies ? "the floor" : "the auto cap"}</dd></div>
            <div><dt>Auto cap (entitlement + 25%)</dt><dd>{overview.auto_cap_minutes === null ? "Not computed yet" : `${overview.auto_cap_minutes.toLocaleString("en-IN")} · updated ${formatDateTime(overview.auto_cap_at ?? null)}`}</dd></div>
            <div><dt>Floor (Limits tab)</dt><dd>{overview.monthly_cap_minutes.toLocaleString("en-IN")} minutes</dd></div>
          </dl>
          <p className="faint">
            Staff get an alert at 70% and 90%. At 100% new calls get &ldquo;Calling is paused right now&rdquo; until the auto cap rises or the month ends; calls already connected continue.
          </p>
          {ops && ops.months.length > 0 ? (
            <div className="table-wrap">
              <table className="table">
                <thead><tr><th>Month</th><th>Charged minutes</th><th>Estimated Stream cost</th></tr></thead>
                <tbody>
                  {ops.months.map((month) => (
                    <tr key={month.month_start}>
                      <td>{new Date(`${month.month_start}T00:00:00+05:30`).toLocaleDateString("en-IN", { month: "long", year: "numeric", timeZone: "Asia/Kolkata" })}</td>
                      <td>{month.charged_minutes.toLocaleString("en-IN")}</td>
                      <td>${(month.charged_minutes * 0.0006).toFixed(2)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : null}
        </div>
      </section>

      <div className="split">
        {can(role, "switchCalls") ? (
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

        <section className="card">
          <div className="card-head"><h2><AlertTriangle size={16} /> Emergency: switch calling off</h2></div>
          <div className="card-body stack">
            <ol className="steps">
              <li><strong>Super admin:</strong> use <em>Turn calling off</em> on this page. Ringing and live calls end within seconds; members see calling disappear on their next refresh.</li>
              <li><strong>Admin panel down:</strong> in the Supabase dashboard (production project) open the SQL editor and run <code className="mono">update private.call_settings set calls_enabled = false where id;</code> — it has the same effect and is recorded in the settings history.</li>
              <li><strong>Silarah server down:</strong> nothing to do for cost — Stream ends every call by itself at its maximum length (the longest-call limit plus the connecting allowance).</li>
              <li>Tell the team what happened. Turn calling back on only after the cause is fixed; the reason you type is kept in the audit trail.</li>
            </ol>
            {can(role, "switchCalls") ? null : <p className="faint">Only a super admin can use the switch. Ask one if calls must stop.</p>}
          </div>
        </section>
      </div>

      <section className="card">
        <div className="card-head"><h2><Phone size={16} /> Calls in progress</h2><span className="muted">Answered and not yet settled · {ops?.ringing ?? 0} ringing</span></div>
        <div className="card-body stack">
          {ops === null ? (
            <p className="notice danger"><span>Live calls could not load.</span></p>
          ) : ops.live.length === 0 ? (
            <EmptyState icon={Phone} title="No calls in progress">Answered calls show here until their minutes are settled.</EmptyState>
          ) : (
            <div className="table-wrap">
              <table className="table">
                <thead><tr><th>Answered</th><th>Caller</th><th>Callee</th><th>State</th><th>Held</th></tr></thead>
                <tbody>
                  {ops.live.map((call) => (
                    <tr key={call.request_id}>
                      <td>{formatDateTime(call.accepted_at)}<span className="cell-sub">{relativeTime(call.accepted_at)}</span></td>
                      <td><Link href={`/calls?tab=member&member=${call.caller_id}`} prefetch={false}>{call.caller_name || call.caller_id.slice(0, 8)}</Link></td>
                      <td><Link href={`/calls?tab=member&member=${call.callee_id}`} prefetch={false}>{call.callee_name || call.callee_id.slice(0, 8)}</Link></td>
                      <td>
                        {liveState(call.status, Boolean(call.both_joined_at))}
                        {call.end_reason ? <span className="cell-sub">{call.end_reason.replaceAll("_", " ")}</span> : null}
                        {call.last_error ? <span className="cell-sub">{call.last_error}</span> : null}
                      </td>
                      <td>{call.hold_minutes} min</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </section>

      <JobsCard ops={ops} role={role} returnTo={returnTo} />
    </>
  );
}

function liveState(status: string, bothJoined: boolean) {
  if (status === "creating") return "Connecting";
  if (status === "active") return bothJoined ? "Talking" : "Joining";
  if (status === "ending") return "Ending";
  if (status === "ended") return "Ended · waiting for Stream's record";
  return status;
}

const jobLabels: Record<string, string> = {
  settle: "Settle minutes",
  end_stream_call: "End call on Stream",
  join_check: "Check both joined",
  delete_stream_user: "Delete Stream user",
  cancel_ring: "Stop ringing push",
  missed_push: "Missed-call push",
  seen_push: "Seen-on-other-phone push",
  plan_reminder: "Planned-call reminder",
};

function JobsCard({ ops, role, returnTo }: { ops: CallOperations | null; role: AdminRole; returnTo: string }) {
  const canRetry = can(role, "retryCallJobs");
  return (
    <section className="card" id="jobs">
      <div className="card-head">
        <h2><RotateCcw size={16} /> Background jobs that failed</h2>
        <span className="muted">The call worker retries each job up to 30 times, then gives up and alerts staff · kept 30 days</span>
      </div>
      <div className="card-body stack">
        {ops === null ? (
          <p className="notice danger"><span>Jobs could not load.</span></p>
        ) : ops.dead_jobs.length === 0 && ops.retrying_jobs.length === 0 ? (
          <EmptyState icon={RotateCcw} title="No failed jobs">Every settlement, call end and notification went through.</EmptyState>
        ) : (
          <>
            {ops.dead_jobs.length > 0 ? (
              <div className="list">
                {ops.dead_jobs.map((job) => (
                  <article className="list-item" key={job.id}>
                    <div>
                      <h3>{jobLabels[job.kind] ?? job.kind} <span className="pill danger">gave up after {job.attempts}</span></h3>
                      <p className="quote mono">{job.last_error || "No error text was recorded."}</p>
                      <div className="meta">
                        <span>created {formatDateTime(job.created_at)}</span>
                        <span className="mono">job {job.id}</span>
                        {job.request_id ? <span className="mono">call {job.request_id.slice(0, 8)}</span> : null}
                        {job.user_id ? <Link href={`/calls?tab=member&member=${job.user_id}`} prefetch={false} className="mono">member {job.user_id.slice(0, 8)}</Link> : null}
                      </div>
                      {job.kind === "settle" ? (
                        <p className="faint">An unsettled call keeps the caller&apos;s held minutes. Retry once the cause (often a Stream outage) is over.</p>
                      ) : null}
                    </div>
                    <div className="aside">
                      {canRetry && job.can_retry ? (
                        <details className="disclosure">
                          <summary className="btn btn-sm">Retry…</summary>
                          <form action={retryCallJob} className="popover-form">
                            <input type="hidden" name="jobId" value={job.id} />
                            <input type="hidden" name="returnTo" value={returnTo} />
                            <label className="field">Reason for the audit log
                              <input name="reason" className="input" required minLength={6} maxLength={500} placeholder="e.g. Stream outage over" />
                            </label>
                            <SubmitButton className="btn btn-sm btn-primary">Queue again</SubmitButton>
                          </form>
                        </details>
                      ) : !job.can_retry ? (
                        <span className="faint">Notification: not retried</span>
                      ) : null}
                    </div>
                  </article>
                ))}
              </div>
            ) : null}
            {ops.retrying_jobs.length > 0 ? (
              <div className="table-wrap">
                <table className="table">
                  <thead><tr><th>Still retrying</th><th>Attempts</th><th>Next try</th><th>Last error</th></tr></thead>
                  <tbody>
                    {ops.retrying_jobs.map((job) => (
                      <tr key={job.id}>
                        <td>{jobLabels[job.kind] ?? job.kind}<span className="cell-sub mono">job {job.id}</span></td>
                        <td>{job.attempts}</td>
                        <td>{formatDateTime(job.next_attempt_at ?? null)}</td>
                        <td className="mono">{job.last_error ?? "—"}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : null}
          </>
        )}
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Limits: the tunable call settings
// ---------------------------------------------------------------------------

function changeValue(value: unknown) {
  if (value === null || value === undefined) return "—";
  return typeof value === "object" ? JSON.stringify(value) : String(value);
}

async function SettingsTab({ role, returnTo }: { role: AdminRole; returnTo: string }) {
  const settings: CallSettings | null = await load(getCallSettings);
  if (settings === null) {
    return <section className="card"><p className="notice danger"><span>Calling limits could not load.</span></p></section>;
  }
  const editable = can(role, "tuneCalls");
  const byKey = new Map(settings.values.map((row) => [row.key, row]));

  return (
    <>
      <section className="card">
        <div className="card-head"><h2><SlidersHorizontal size={16} /> Last change</h2></div>
        <div className="card-body stack">
          {settings.last_change ? (
            <>
              <p className="muted">
                {formatDateTime(settings.last_change.changed_at)} by {settings.last_change.changed_by_email ?? (settings.last_change.changed_by ? settings.last_change.changed_by.slice(0, 8) : "a migration or the SQL editor")}
              </p>
              <ul className="plain-list">
                {settings.last_change.changes.map((change) => (
                  <li key={change.key}>{callSettingLabel(change.key)}: {changeValue(change.from)} → <strong>{changeValue(change.to)}</strong></li>
                ))}
              </ul>
              <p className="faint">Every change and its reason is also in the <Link href="/audit?action=voice_call_settings_changed" prefetch={false} className="link">audit trail</Link>. The hourly auto-cap update is not shown here.</p>
            </>
          ) : <p className="faint">Nobody has changed these since calling was installed.</p>}
        </div>
      </section>

      <section className="card">
        <div className="card-head">
          <h2>Calling limits</h2>
          <span className="muted">{editable ? "Members see the new rules on their next refresh; calls already answered keep theirs" : "Read only · a super admin can change these"}</span>
        </div>
        <form action={updateCallSettings} className="card-body stack">
          <input type="hidden" name="returnTo" value={returnTo} />
          {callSettingGroups.map((group) => (
            <fieldset key={group.id} className="stack" disabled={!editable}>
              <legend className="eyebrow">{group.label}</legend>
              <div className="form-grid">
                {(Object.keys(callSettingInfo) as (keyof typeof callSettingInfo)[])
                  .filter((key) => callSettingInfo[key].group === group.id && byKey.has(key))
                  .map((key) => {
                    const row = byKey.get(key)!;
                    const info = callSettingInfo[key];
                    return (
                      <label className="field" key={key}>
                        {info.label} <span className="faint">({info.unit}, {row.min.toLocaleString("en-IN")}–{row.max.toLocaleString("en-IN")})</span>
                        <input type="hidden" name={`current_${key}`} value={row.value} />
                        <input name={key} type="number" className="input" required min={row.min} max={row.max} step={1} defaultValue={row.value} />
                        <span className="faint">{info.help}</span>
                      </label>
                    );
                  })}
              </div>
            </fieldset>
          ))}
          {editable ? (
            <>
              <label className="field">Reason for the audit log
                <input name="reason" className="input" required minLength={6} maxLength={500} placeholder="e.g. Raise the floor before the Diwali campaign" />
              </label>
              <div className="form-actions">
                <SubmitButton className="btn btn-primary" confirm="Save the changed calling limits for every member?">Save changes</SubmitButton>
              </div>
            </>
          ) : null}
        </form>
      </section>

      <section className="card">
        <div className="card-head"><h2>Fixed here</h2><span className="muted">Changed only with a migration</span></div>
        <div className="card-body stack">
          <dl className="kv">
            <div><dt>Included-minutes period</dt><dd>{settings.fixed.included_period_days} days</dd></div>
            <div><dt>Call records kept</dt><dd>{settings.fixed.log_retention_months} months</dd></div>
            <div><dt>Calling terms check</dt><dd>{settings.fixed.calling_consent_version ? `${settings.fixed.calling_consent_type.replaceAll("_", " ")} ${settings.fixed.calling_consent_version} or later` : "Not set: no check"}</dd></div>
          </dl>
          <p className="faint">
            The period length would move every member&apos;s current period; retention is promised in the privacy policy; the terms version goes live with the legal text. Ask the developer for a migration.
          </p>
        </div>
      </section>
    </>
  );
}

// ---------------------------------------------------------------------------
// One member
// ---------------------------------------------------------------------------

type WalletResult = { status: "ok"; wallet: MemberCallWallet } | { status: "missing" } | { status: "error" };

async function MemberTab({ memberId, role, rawMember }: { memberId: string | null; role: AdminRole; rawMember: string }) {
  const [walletResult, history]: [WalletResult | null, MemberCallRow[] | null] = memberId && can(role, "viewCallHistory")
    ? await Promise.all([
      getMemberCallWallet(memberId).then(
        (wallet): WalletResult => (wallet ? { status: "ok", wallet } : { status: "missing" }),
        (): WalletResult => ({ status: "error" }),
      ),
      load<MemberCallRow[]>(() => getMemberCallHistory(memberId)),
    ])
    : [null, null];

  return (
    <>
      <section className="card">
        <div className="card-head"><h2><Search size={16} /> Find a member&apos;s calls</h2></div>
        <div className="card-body stack">
          <form method="get" className="action-row">
            <input type="hidden" name="tab" value="member" />
            <label className="field">Member ID
              <input name="member" className="input mono" defaultValue={memberId ?? rawMember} pattern="[0-9a-fA-F-]{36}" placeholder="00000000-0000-0000-0000-000000000000" />
            </label>
            <div className="form-actions"><button type="submit" className="btn">Show calls</button></div>
          </form>
          {rawMember && !memberId ? <p className="notice danger"><span>That is not a member ID. Copy it from the member&apos;s page.</span></p> : null}
          {memberId ? (
            <p className="faint">
              <Link href={`/users/${memberId}`} prefetch={false} className="link">Open the member&apos;s page</Link> for their profile, reports and account actions.
            </p>
          ) : null}
        </div>
      </section>

      {memberId && walletResult ? (
        walletResult.status === "missing" ? (
          <section className="card"><EmptyState icon={Phone} title="No member with this ID">Check the ID; deleted accounts have no call records.</EmptyState></section>
        ) : (
          <>
            <MemberCallWalletCard wallet={walletResult.status === "ok" ? walletResult.wallet : null} userId={memberId} />
            <section className="card">
              <div className="card-head"><h2><Phone size={16} /> Calls</h2><span className="muted">Newest 100 · never audio</span></div>
              <div className="card-body"><MemberCallHistoryTable history={history} /></div>
            </section>
          </>
        )
      ) : null}
    </>
  );
}

// ---------------------------------------------------------------------------
// Packs waiting for a member, and pack-minute corrections
// ---------------------------------------------------------------------------

async function PacksTab({ memberId, role, returnTo }: { memberId: string | null; role: AdminRole; returnTo: string }) {
  const unclaimed: UnclaimedCallPack[] | null = can(role, "claimCallPacks") ? await load(getUnclaimedCallPacks) : null;
  if (!can(role, "claimCallPacks") && !can(role, "adjustCallMinutes")) {
    return <section className="card"><EmptyState icon={Phone} title="Packs are handled by support">Moderators can see a member&apos;s minutes on the A member tab.</EmptyState></section>;
  }

  return (
    <>
      {can(role, "claimCallPacks") ? (
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

      {can(role, "adjustCallMinutes") ? (
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
    </>
  );
}
