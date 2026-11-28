import { Bell, CheckCheck, ChevronRight } from "lucide-react";
import Link from "next/link";
import { SubmitButton } from "@/components/client-ui";
import { EmptyState, PageHeader, formatDateTime } from "@/components/ui";
import { canAccess, formatCount } from "@/lib/access";
import { inboxType } from "@/lib/labels";
import { requireAdmin } from "@/lib/auth";
import { encodeCursor, getAdminInbox, parseCursor } from "@/lib/operations";
import { markAdminNotificationRead, markAllAdminNotificationsRead } from "../actions";

export const metadata = { title: "Inbox" };

function href(view: "unread" | "all", after?: string) {
  const params = new URLSearchParams();
  if (view === "all") params.set("view", "all");
  if (after) params.set("after", after);
  const value = params.toString();
  return `/inbox${value ? `?${value}` : ""}`;
}

export default async function InboxPage({ searchParams }: { searchParams: Promise<{ view?: string; after?: string }> }) {
  const admin = await requireAdmin();
  const params = await searchParams;
  const view = params.view === "all" ? "all" : "unread";
  const cursor = parseCursor(params.after);
  const page = await getAdminInbox(view === "unread", cursor);
  const unread = admin.counts.unreadInbox ?? 0;
  const returnTo = href(view, params.after);

  return (
    <div>
      <PageHeader
        eyebrow="Today"
        title="Inbox"
        lede="Reports, privacy requests and their deadlines, refunds, deletion requests and system alerts. Newest first; each opens the page that handles it."
        actions={
          <form action={markAllAdminNotificationsRead}>
            <input type="hidden" name="returnTo" value={href(view)} />
            <SubmitButton className="btn" disabled={unread === 0} confirm={`Mark all ${formatCount(unread)} unread alerts as read?`}>
              <CheckCheck size={15} /> Mark all read
            </SubmitButton>
          </form>
        }
      />

      <nav className="tabs" aria-label="Inbox filter">
        <Link href={href("unread")} prefetch={false} className={`tab${view === "unread" ? " is-active" : ""}`} aria-current={view === "unread" ? "page" : undefined}>
          Unread {unread > 0 ? <span className="nav-count">{formatCount(unread)}</span> : null}
        </Link>
        <Link href={href("all")} prefetch={false} className={`tab${view === "all" ? " is-active" : ""}`} aria-current={view === "all" ? "page" : undefined}>
          All alerts
        </Link>
      </nav>

      <section className="card">
        {page.rows.length === 0 ? (
          <EmptyState icon={Bell} title={view === "unread" ? "You are all caught up" : "No alerts yet"}>
            {view === "unread" ? "New alerts will appear here. Older ones are under All alerts." : "Operational alerts will appear here when rules fire."}
          </EmptyState>
        ) : (
          <div className="list">
            {page.rows.map((item) => {
              const kind = inboxType(item.type, item.related_user_id);
              return (
              <article className={`list-item${item.is_read ? "" : " is-unread"}`} key={item.notification_id}>
                <div>
                  <h3>{kind.label}</h3>
                  <p>{item.message}</p>
                  <div className="meta">
                    <span>{formatDateTime(item.created_at)}</span>
                    {item.related_user_id ? (
                      canAccess(admin.role, "memberReview")
                        ? <Link href={`/users/${item.related_user_id}`} prefetch={false} className="mono">member {item.related_user_id.slice(0, 8)}</Link>
                        : <span className="mono">member {item.related_user_id.slice(0, 8)}</span>
                    ) : null}
                  </div>
                </div>
                <div className="aside">
                  {kind.href ? <Link href={kind.href} prefetch={false} className="btn btn-sm">Open</Link> : null}
                  {item.is_read ? <span className="pill plain">Read</span> : (
                    <form action={markAdminNotificationRead}>
                      <input type="hidden" name="notificationId" value={item.notification_id} />
                      <input type="hidden" name="returnTo" value={returnTo} />
                      <SubmitButton className="btn btn-sm">Mark read</SubmitButton>
                    </form>
                  )}
                </div>
              </article>
              );
            })}
          </div>
        )}
        {(cursor || page.next) ? (
          <nav className="pager" aria-label="Inbox pages">
            {cursor ? <Link href={href(view)} prefetch={false} className="link">← Back to newest</Link> : <span>Newest {page.rows.length}</span>}
            {page.next ? <Link href={href(view, encodeCursor(page.next))} prefetch={false} className="btn btn-sm">Older <ChevronRight size={14} /></Link> : <span>End of list</span>}
          </nav>
        ) : null}
      </section>
    </div>
  );
}
