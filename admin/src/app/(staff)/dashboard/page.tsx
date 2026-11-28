import { Bell, ChevronRight, CircleCheck, Flag, ImageIcon, MessageSquareWarning, Phone, PhoneOff, RotateCcw, ScanFace, UserRoundCheck, Users, WalletCards } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import Link from "next/link";
import { LiveOperationsCockpit } from "@/components/live-operations-cockpit";
import { PageHeader, Stat } from "@/components/ui";
import { canAccess, formatCount, type Area } from "@/lib/access";
import { requireAdmin } from "@/lib/auth";
import { getCallOverview, getDashboardOverview, getSubscriptionSummary, type CallOverview, type SubscriptionSummary } from "@/lib/operations";

export const metadata = { title: "Overview" };

type Attention = { label: string; count: number; href: string; area: Area; icon: LucideIcon; urgent?: boolean };

function greeting() {
  const hour = Number(new Intl.DateTimeFormat("en-IN", { hour: "numeric", hourCycle: "h23", timeZone: "Asia/Kolkata" }).format(new Date()));
  if (hour < 12) return "Good morning";
  if (hour < 17) return "Good afternoon";
  return "Good evening";
}

export default async function DashboardPage() {
  const admin = await requireAdmin();
  const showCalls = canAccess(admin.role, "calls");
  const [overview, calls, subscriptions] = await Promise.all([
    getDashboardOverview(),
    showCalls ? getCallOverview().catch((): CallOverview | null => null) : Promise.resolve(null),
    getSubscriptionSummary().catch((): SubscriptionSummary | null => null),
  ]);
  const c = admin.counts;
  const metrics = overview.metrics ?? {};

  const candidates: Attention[] = [
    { label: "Photo checks waiting", count: c.photoChecks ?? 0, href: "/photo-verification", area: "photoChecks", icon: ScanFace, urgent: true },
    { label: "Open member reports", count: c.openReports ?? 0, href: "/moderation?tab=reports", area: "moderation", icon: Flag, urgent: true },
    { label: "Reported messages", count: c.messageReports ?? 0, href: "/moderation?tab=messages", area: "moderation", icon: MessageSquareWarning, urgent: true },
    { label: "Photos to review", count: c.pendingPhotos ?? 0, href: "/moderation?tab=photos", area: "moderation", icon: ImageIcon },
    { label: (c.privacyOverdue ?? 0) > 0 ? `Rights requests · ${c.privacyOverdue} overdue` : "Member rights requests", count: c.privacyOpen ?? 0, href: "/privacy", area: "privacy", icon: UserRoundCheck, urgent: (c.privacyOverdue ?? 0) > 0 },
    { label: "Unread alerts", count: c.unreadInbox ?? 0, href: "/inbox?view=unread", area: "inbox", icon: Bell },
    ...(calls ? [
      { label: "Failed call jobs", count: calls.dead_jobs, href: "/calls?tab=overview#jobs", area: "calls" as const, icon: RotateCcw, urgent: true },
      { label: "Paid call packs waiting", count: calls.unclaimed_packs ?? 0, href: "/calls?tab=packs", area: "calls" as const, icon: Phone },
    ] : []),
  ];
  const attention = candidates.filter((item) => canAccess(admin.role, item.area));
  const waiting = attention.filter((item) => item.count > 0);

  return (
    <div className="stack-lg">
      <PageHeader
        eyebrow={new Intl.DateTimeFormat("en-IN", { weekday: "long", day: "numeric", month: "long", timeZone: "Asia/Kolkata" }).format(new Date())}
        title={`${greeting()}`}
        lede={waiting.length === 0
          ? "Every queue is clear. Nothing needs a decision right now."
          : `${waiting.length === 1 ? "One queue needs" : `${waiting.length} queues need`} your attention. Oldest items are shown first on each page.`}
      />

      <section aria-labelledby="attention-title">
        <div className="section-head">
          <h2 id="attention-title">Needs your attention</h2>
        </div>
        <div className="attention">
          {attention.map((item) => {
            const Icon = item.icon;
            const tone = item.count === 0 ? "" : item.urgent ? " is-urgent" : " is-waiting";
            return (
              <Link key={item.href + item.label} href={item.href} prefetch={false} className={`attention-item${tone}`}>
                <span className="attention-icon" aria-hidden="true">
                  {item.count === 0 ? <CircleCheck size={19} /> : <Icon size={19} />}
                </span>
                <span>
                  <strong>{formatCount(item.count)}</strong>
                  <span>{item.label}</span>
                </span>
                <ChevronRight size={16} className="chev" aria-hidden="true" />
              </Link>
            );
          })}
        </div>
      </section>

      <section aria-labelledby="glance-title">
        <div className="section-head">
          <h2 id="glance-title">Calls, Premium and reports</h2>
          <p>Live figures</p>
        </div>
        <div className="stat-grid">
          {showCalls ? (
            calls ? (
              <>
                <Stat
                  label="Voice calling"
                  value={calls.calls_enabled ? "On" : "Off"}
                  icon={calls.calls_enabled ? Phone : PhoneOff}
                  hint={`${calls.live_calls} live · ${calls.calls_today} in 24 h`}
                  href="/calls"
                />
                <Stat
                  label="Call minutes this month"
                  value={calls.month_charged_minutes}
                  hint={`${calls.effective_cap_minutes > 0 ? Math.round((calls.month_charged_minutes / calls.effective_cap_minutes) * 100) : 0}% of the brake · about $${Number(calls.estimated_stream_cost_usd ?? 0).toFixed(2)} Stream`}
                  tone={calls.effective_cap_minutes > 0 && calls.month_charged_minutes / calls.effective_cap_minutes >= 0.9 ? "alert" : undefined}
                  href="/calls"
                />
              </>
            ) : <Stat label="Voice calling" value="—" hint="Calling data could not load" href="/calls" />
          ) : null}
          {subscriptions ? (
            <Stat
              label="Premium members"
              value={subscriptions.active + subscriptions.grace}
              icon={WalletCards}
              hint={`${subscriptions.grace} in billing grace · ${subscriptions.refunds} refunds all time`}
              tone={subscriptions.grace > 0 ? "alert" : undefined}
              href="/subscriptions"
            />
          ) : null}
          {canAccess(admin.role, "moderation") ? (
            <Stat
              label="Open reports"
              value={(c.openReports ?? 0) + (c.messageReports ?? 0)}
              icon={Flag}
              hint={`${c.openReports ?? 0} profiles · ${c.messageReports ?? 0} messages`}
              tone={(c.openReports ?? 0) + (c.messageReports ?? 0) > 0 ? "alert" : "clear"}
              href="/moderation?tab=reports"
            />
          ) : null}
        </div>
      </section>

      <LiveOperationsCockpit initial={overview} />

      <section aria-labelledby="base-title">
        <div className="section-head">
          <h2 id="base-title">Member base</h2>
          <p>From the 15-minute metrics snapshot</p>
        </div>
        <div className="stat-grid">
          <Stat label="Total members" value={metrics.totalUsers} icon={Users} href="/users" />
          <Stat label="Active in 7 days" value={metrics.activeSevenDays} icon={Users} />
          <Stat label="Active subscriptions" value={metrics.activeSubscriptions} icon={WalletCards} href="/subscriptions" />
        </div>
      </section>
    </div>
  );
}
