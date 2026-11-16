import type { LucideIcon } from "lucide-react";
import { Inbox, Lock } from "lucide-react";

export function PageHeader({
  eyebrow,
  title,
  lede,
  actions,
}: {
  eyebrow?: string;
  title: string;
  lede?: React.ReactNode;
  actions?: React.ReactNode;
}) {
  return (
    <header className="page-head">
      <div>
        {eyebrow ? <p className="eyebrow">{eyebrow}</p> : null}
        <h1>{title}</h1>
        {lede ? <p className="lede">{lede}</p> : null}
      </div>
      {actions ? <div className="page-actions">{actions}</div> : null}
    </header>
  );
}

export function EmptyState({
  icon: Icon = Inbox,
  title,
  children,
  action,
}: {
  icon?: LucideIcon;
  title: string;
  children?: React.ReactNode;
  action?: React.ReactNode;
}) {
  return (
    <div className="empty">
      <span className="empty-icon" aria-hidden="true"><Icon size={22} /></span>
      <h3>{title}</h3>
      {children ? <p>{children}</p> : null}
      {action}
    </div>
  );
}

export function NoAccess({ area }: { area: string }) {
  return (
    <div className="card">
      <EmptyState icon={Lock} title={`${area} is not part of your role`}>
        Ask a super admin if you need this area. Nothing has been loaded or changed.
      </EmptyState>
    </div>
  );
}

export function Stat({
  label,
  value,
  hint,
  icon: Icon,
  tone,
  href,
}: {
  label: string;
  value: number | string | null | undefined;
  hint?: string;
  icon?: LucideIcon;
  tone?: "alert" | "clear";
  href?: string;
}) {
  const display = typeof value === "number" ? value.toLocaleString("en-IN") : value ?? "—";
  const body = (
    <>
      <span className="stat-label">{Icon ? <Icon size={15} aria-hidden="true" /> : null}{label}</span>
      <span className="stat-value">{display}</span>
      {hint ? <span className="stat-hint">{hint}</span> : null}
    </>
  );
  const className = `stat${tone ? ` is-${tone}` : ""}`;
  return href ? <a href={href} className={className}>{body}</a> : <div className={className}>{body}</div>;
}

const toneByStatus: Record<string, string> = {
  active: "ok", visible: "ok", published: "ok", queued: "info", sent: "ok", resolved: "ok",
  approved: "ok", grace: "warn", reviewing: "info", pending: "warn", draft: "plain",
  scheduled: "info", archived: "plain", rejected: "danger", suspended: "danger",
  banned: "danger", shadowbanned: "warn", revoked: "danger", hidden: "warn",
  deactivated: "plain", profile_pending: "warn", none: "plain", expired: "plain",
  cancelled: "plain", failed: "danger", test_premium: "info",
};

export function StatusPill({ status, label }: { status: string; label?: string }) {
  const key = status.toLowerCase();
  const tone = toneByStatus[key] ?? "plain";
  return <span className={`pill ${tone}`}>{label ?? status.replaceAll("_", " ")}</span>;
}

const dateTime = new Intl.DateTimeFormat("en-IN", {
  day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit",
  timeZone: "Asia/Kolkata",
});
const dateOnly = new Intl.DateTimeFormat("en-IN", {
  day: "numeric", month: "short", year: "numeric", timeZone: "Asia/Kolkata",
});

// Server-rendered times use one fixed zone so the markup is identical for
// every viewer and hydration never re-renders it.
export function formatDateTime(value: string | null | undefined) {
  return value ? `${dateTime.format(new Date(value))} IST` : "—";
}

export function formatDate(value: string | null | undefined) {
  return value ? dateOnly.format(new Date(value)) : "—";
}

export function isPast(value: string) {
  return new Date(value).getTime() < Date.now();
}

export function relativeTime(value: string | null | undefined, now = Date.now()) {
  if (!value) return "never";
  const seconds = Math.round((now - new Date(value).getTime()) / 1000);
  if (seconds < 60) return "just now";
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 48) return `${hours} h ago`;
  return `${Math.round(hours / 24)} days ago`;
}
