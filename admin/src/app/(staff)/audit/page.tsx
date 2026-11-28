import { ChevronRight, FileClock } from "lucide-react";
import Form from "next/form";
import Link from "next/link";
import { EmptyState, PageHeader, formatDateTime } from "@/components/ui";
import { requireAdmin } from "@/lib/auth";
import { encodeCursor, getAuditFeed, parseCursor } from "@/lib/operations";

export const metadata = { title: "Audit trail" };

// Common actions for the filter; the box also accepts any exact action name.
const knownActions = [
  "admin_user_pii_revealed",
  "admin_user_directory_read",
  "message_reports_queue_read",
  "admin_work_item_claimed",
  "admin_notification_read",
  "admin_notifications_read_all",
  "voice_calls_switched",
  "voice_call_settings_changed",
  "voice_call_job_retried",
  "voice_call_minutes_adjusted",
  "privacy_request_reviewed",
  "privacy_request_hold_set",
];

function href(action: string, after?: string) {
  const params = new URLSearchParams();
  if (action) params.set("action", action);
  if (after) params.set("after", after);
  const value = params.toString();
  return `/audit${value ? `?${value}` : ""}`;
}

function details(value: Record<string, unknown> | null) {
  if (!value || Object.keys(value).length === 0) return null;
  return Object.entries(value)
    .map(([key, item]) => `${key.replaceAll("_", " ")}: ${typeof item === "object" ? JSON.stringify(item) : String(item)}`)
    .join(" · ");
}

export default async function AuditPage({ searchParams }: { searchParams: Promise<{ action?: string; after?: string }> }) {
  await requireAdmin();
  const params = await searchParams;
  const action = (params.action ?? "").trim().slice(0, 80);
  const cursor = parseCursor(params.after);
  const page = await getAuditFeed(cursor, action);

  return (
    <div>
      <PageHeader
        eyebrow="Governance"
        title="Audit trail"
        lede="Every privileged staff action and sensitive read, newest first. Entries cannot be edited or deleted."
      />

      <Form className="toolbar" action="/audit">
        <div className="row">
          <label className="sr-only" htmlFor="audit-action">Action</label>
          <input id="audit-action" name="action" list="audit-actions" className="input" placeholder="Filter by exact action, e.g. admin_user_pii_revealed" defaultValue={action} />
          <datalist id="audit-actions">{knownActions.map((item) => <option key={item} value={item} />)}</datalist>
          <button className="btn" type="submit">Filter</button>
          {action ? <Link href="/audit" prefetch={false} className="btn btn-ghost">Clear</Link> : null}
        </div>
      </Form>

      <section className="card">
        {page.rows.length === 0 ? (
          <EmptyState icon={FileClock} title={action ? "No entries for this action" : "No audit entries yet"}>
            {action ? "Check the action name, or clear the filter." : "Staff actions will be recorded here."}
          </EmptyState>
        ) : (
          <div className="table-wrap">
            <table className="table">
              <thead><tr><th>When</th><th>Staff</th><th>Action</th><th>Member</th><th>Details</th></tr></thead>
              <tbody>
                {page.rows.map((event) => (
                  <tr key={event.audit_id}>
                    <td className="num">{formatDateTime(event.created_at)}</td>
                    <td><span className="cell-main">{event.admin_email ?? "System"}</span><span className="cell-sub">{event.actor_role?.replaceAll("_", " ") ?? "unknown role"}</span></td>
                    <td><Link href={href(event.action_type)} prefetch={false} className="pill info plain">{event.action_type.replaceAll("_", " ")}</Link></td>
                    <td className="mono">{event.target_user_id ? event.target_user_id.slice(0, 8) : "—"}</td>
                    <td className="muted wrap-anywhere">{details(event.details) ?? "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {(cursor || page.next) ? (
          <nav className="pager" aria-label="Audit pages">
            {cursor ? <Link href={href(action)} prefetch={false} className="link">← Back to newest</Link> : <span>Newest {page.rows.length}</span>}
            {page.next ? <Link href={href(action, encodeCursor(page.next))} prefetch={false} className="btn btn-sm">Older <ChevronRight size={14} /></Link> : <span>End of trail</span>}
          </nav>
        ) : null}
      </section>
    </div>
  );
}
