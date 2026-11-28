import { Activity, BellRing, Clock, Gauge, Languages } from "lucide-react";
import { EmptyState, PageHeader, Stat, formatDateTime } from "@/components/ui";
import { requireAdmin } from "@/lib/auth";
import { getLocalizationOverview, getScheduledJobs, getSystemHealth, type ScheduledJobs } from "@/lib/operations";

export const metadata = { title: "System health" };

type Metric = { key: string; label: string; hint?: string; bad?: (value: number) => boolean };

const groups: { title: string; metrics: Metric[] }[] = [
  {
    title: "Notifications",
    metrics: [
      { key: "dispatchHealthy", label: "Dispatcher", hint: "1 = healthy", bad: (v) => v !== 1 },
      { key: "dispatchConsecutiveFailures", label: "Dispatch failures in a row", bad: (v) => v > 0 },
      { key: "dueNotifications", label: "Due now" },
      { key: "staleNotifications", label: "Overdue", bad: (v) => v > 0 },
      { key: "futureNotifications", label: "Scheduled" },
      { key: "fcmTokenUsers", label: "Members with push enabled" },
    ],
  },
  {
    title: "Queues",
    metrics: [
      { key: "openReports", label: "Open reports" },
      { key: "pendingPhotos", label: "Photos to review" },
      { key: "queuedCampaigns", label: "Queued campaigns" },
      { key: "failedEmails24h", label: "Failed emails · 24 h", bad: (v) => v > 0 },
      { key: "rateLimitRejections1h", label: "Rate-limited requests · 1 h" },
      { key: "subscriptionEvents24h", label: "Billing events · 24 h" },
    ],
  },
  {
    title: "Platform",
    metrics: [
      { key: "databaseUsageMb", label: "Database size (MB)" },
      { key: "storageUsageMb", label: "Storage used (MB)" },
      { key: "publishedContentPages", label: "Published pages" },
      { key: "publishedSuccessStories", label: "Published stories" },
      { key: "activeStaff", label: "Active staff" },
    ],
  },
];

type FreePlan = {
  databaseMb: number;
  databaseUsedMb: number;
  storageMb: number;
  storageUsedMb: number;
  monthlyActiveUsers: number;
  monthlyActiveUsed: number;
  dbConnections: number;
  dbConnectionsNow: number;
  peakDbConnections24h: number;
  onlineNow: number;
  peakOnline24h: number;
};

/** Same levels as the staff email alerts in the database. */
function limitTone(percent: number) {
  if (percent >= 85) return "is-danger";
  if (percent >= 70) return "is-warning";
  return "";
}

function FreePlanLimits({ plan }: { plan: FreePlan }) {
  const n = (value: number) => Number(value ?? 0).toLocaleString("en-IN");
  const rows = [
    { label: "Database size", used: plan.databaseUsedMb, limit: plan.databaseMb, unit: " MB" },
    { label: "Photo storage", used: plan.storageUsedMb, limit: plan.storageMb, unit: " MB" },
    { label: "Monthly active members", used: plan.monthlyActiveUsed, limit: plan.monthlyActiveUsers, unit: "" },
    {
      label: "Database connections (busiest in 24 h)",
      used: Math.max(plan.dbConnectionsNow, plan.peakDbConnections24h),
      limit: plan.dbConnections,
      unit: "",
    },
  ];
  return (
    <section className="card" aria-labelledby="free-plan-title">
      <div className="card-head">
        <h2 id="free-plan-title"><Gauge size={16} /> Free plan limits</h2>
        <span className="muted">
          {n(plan.onlineNow)} online now · peak {n(plan.peakOnline24h)} in 24 h
        </span>
      </div>
      <div className="card-body meter-list">
        {rows.map((row) => {
          const percent = row.limit > 0 ? Math.min(100, (100 * row.used) / row.limit) : 0;
          const rounded = Math.round(percent);
          return (
            <div className={`meter-row ${limitTone(percent)}`} key={row.label}>
              <div>
                <span>{row.label}</span>
                <strong>{n(row.used)}{row.unit} of {n(row.limit)}{row.unit} · {rounded}%</strong>
              </div>
              <progress className="meter" max={100} value={percent} aria-label={`${row.label} ${rounded}%`} />
            </div>
          );
        })}
        <p className="stat-hint">
          Staff are emailed when a limit reaches 70% and again at 85%. Bandwidth (5 GB a month) and
          function calls are not visible here; check them on the Supabase Usage page.
        </p>
      </div>
    </section>
  );
}

export default async function SystemPage() {
  await requireAdmin();
  const [health, locales, scheduled] = await Promise.all([
    getSystemHealth(),
    getLocalizationOverview(),
    getScheduledJobs().catch((): ScheduledJobs | null => null),
  ]);
  const h = health ?? {};
  const freePlan = (h as Record<string, unknown>).freePlan as FreePlan | undefined;

  return (
    <div className="stack-lg">
      <PageHeader
        eyebrow="Governance"
        title="System health"
        lede="Operational counters from the 15-minute metrics snapshot. Anything that needs attention is highlighted."
      />
      {freePlan ? <FreePlanLimits plan={freePlan} /> : null}
      {groups.map((group) => (
        <section key={group.title}>
          <div className="section-head"><h2>{group.title}</h2></div>
          <div className="stat-grid">
            {group.metrics.map((metric) => {
              const value = Number(h[metric.key] ?? 0);
              const bad = metric.bad?.(value) ?? false;
              return <Stat key={metric.key} label={metric.label} value={value} hint={metric.hint} tone={bad ? "alert" : undefined} icon={bad ? Activity : undefined} />;
            })}
          </div>
        </section>
      ))}

      <ActiveAlerts scheduled={scheduled} />
      <ScheduledJobsCard scheduled={scheduled} />

      <section className="card">
        <div className="card-head"><h2><Languages size={16} /> Content by language</h2></div>
        {locales.length === 0 ? (
          <EmptyState icon={Languages} title="No app content yet">Pages created under Content are counted here by language.</EmptyState>
        ) : (
          <div className="table-wrap">
            <table className="table">
              <thead><tr><th>Language</th><th className="right">Pages</th><th className="right">Published</th><th>Last updated</th></tr></thead>
              <tbody>
                {locales.map((locale) => (
                  <tr key={locale.locale}>
                    <td className="mono">{locale.locale}</td>
                    <td className="right num">{Number(locale.page_count).toLocaleString("en-IN")}</td>
                    <td className="right num">{Number(locale.published_count).toLocaleString("en-IN")}</td>
                    <td>{formatDateTime(locale.last_updated)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}

const alertLabels: Record<string, string> = {
  photo_checks_due: "Photo checks near the 48-hour deadline",
  reports_waiting_24h: "Reports waiting over a day",
  account_purge_overdue: "Accounts past their deletion date",
  account_purge_stuck: "Account purges not finishing",
  member_emails_failing: "Member emails not going out",
  staff_alert_emails_failing: "Staff alert emails not going out",
  scheduled_jobs_failing: "Scheduled jobs failing",
  call_pack_refunds_waiting: "Pack refunds waiting for their purchase",
  voice_call_worker_dead_job: "Voice-call job failed for good",
  voice_call_minutes_70: "Call minutes at 70% of the brake",
  voice_call_minutes_90: "Call minutes at 90% of the brake",
};

function ActiveAlerts({ scheduled }: { scheduled: ScheduledJobs | null }) {
  if (!scheduled) return null;
  return (
    <section className="card">
      <div className="card-head">
        <h2><BellRing size={16} /> Alerts in force</h2>
        <span className="muted">Each one is in the Inbox and was emailed to staff when it first fired</span>
      </div>
      <div className="card-body">
        {scheduled.active_alerts.length === 0 ? (
          <p className="faint">No alert is active. Deadlines, failed jobs and stuck emails are checked every 15 minutes.</p>
        ) : (
          <ul className="plain-list">
            {scheduled.active_alerts.map((alert) => (
              <li key={alert.key}>
                <strong>{alertLabels[alert.key] ?? alert.key.replaceAll("_", " ")}</strong>
                {alert.value !== null ? ` · ${alert.value}` : ""}
                {alert.since ? <span className="faint"> · since {formatDateTime(alert.since)}</span> : null}
              </li>
            ))}
          </ul>
        )}
      </div>
    </section>
  );
}

function ScheduledJobsCard({ scheduled }: { scheduled: ScheduledJobs | null }) {
  return (
    <section className="card">
      <div className="card-head"><h2><Clock size={16} /> Scheduled jobs</h2><span className="muted">Last run of every database job · failures in 24 h first</span></div>
      {scheduled === null ? (
        <div className="card-body"><p className="notice danger"><span>Scheduled jobs could not load.</span></p></div>
      ) : (
        <div className="table-wrap">
          <table className="table">
            <thead><tr><th>Job</th><th>Schedule</th><th>Last run</th><th className="right">Failed · 24 h</th></tr></thead>
            <tbody>
              {scheduled.jobs.map((job) => (
                <tr key={job.name}>
                  <td className="mono">{job.name}{job.active ? null : <span className="cell-sub">paused</span>}</td>
                  <td className="mono">{job.schedule}</td>
                  <td>
                    {job.last_run_at ? formatDateTime(job.last_run_at) : "Not run recently"}
                    {job.last_status && job.last_status !== "succeeded" ? <span className="cell-sub">{job.last_status}{job.last_error ? `: ${job.last_error}` : ""}</span> : null}
                  </td>
                  <td className="right num">{job.failures_24h > 0 ? <span className="pill danger">{job.failures_24h}</span> : "0"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
