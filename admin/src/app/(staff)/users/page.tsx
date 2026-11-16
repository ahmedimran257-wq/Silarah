import { ChevronRight, MoreHorizontal, Users } from "lucide-react";
import Link from "next/link";
import { Suspense } from "react";
import { SearchField, SubmitButton } from "@/components/client-ui";
import { EmptyState, PageHeader, StatusPill, formatDate, relativeTime } from "@/components/ui";
import { can } from "@/lib/access";
import { requireAdmin } from "@/lib/auth";
import { encodeCursor, getUsers, parseCursor, userPageSize } from "@/lib/operations";
import { accountAction, bulkAccountAction } from "../actions";
import { MemberIdentity, SelectAll } from "./member-tools";

export const metadata = { title: "Members" };

const bulkFormId = "bulk-user-action";

// The directory reports "test_premium" for members on staff-granted test
// Premium who have no paid subscription.
const planLabel: Record<string, string> = { none: "Free", test_premium: "Test Premium" };

function href(query: string, after?: string) {
  const params = new URLSearchParams();
  if (query) params.set("q", query);
  if (after) params.set("after", after);
  const value = params.toString();
  return `/users${value ? `?${value}` : ""}`;
}

export default async function UsersPage({ searchParams }: { searchParams: Promise<{ q?: string; after?: string }> }) {
  const admin = await requireAdmin();
  const params = await searchParams;
  const query = (params.q ?? "").trim().slice(0, 120);
  const cursor = parseCursor(params.after);
  const page = await getUsers(query, cursor);
  const canModerate = can(admin.role, "moderateAccounts");
  const canBan = can(admin.role, "banAccounts");
  const canReveal = can(admin.role, "revealPii");
  const returnTo = href(query, params.after);

  return (
    <div>
      <PageHeader
        eyebrow="Members"
        title="Member directory"
        lede="Newest members first. Names and emails stay masked until you reveal one with a reason, and every reveal is written to the audit trail."
      />

      <div className="toolbar">
        <Suspense fallback={<div className="search"><input className="input" disabled placeholder="Search" /></div>}>
          <SearchField label="Search members" placeholder="Search by name, email or member ID" />
        </Suspense>
        {canModerate ? (
          <form id={bulkFormId} action={bulkAccountAction} className="row">
            <input type="hidden" name="returnTo" value={returnTo} />
            <label className="sr-only" htmlFor="bulk-action">Bulk action</label>
            <select id="bulk-action" name="action" defaultValue="suspend" className="select btn-sm">
              <option value="suspend">Suspend selected</option>
              <option value="restore">Restore selected</option>
              {canBan ? <option value="shadowban">Shadowban selected</option> : null}
              {canBan ? <option value="ban">Ban selected</option> : null}
            </select>
            <label className="sr-only" htmlFor="bulk-reason">Reason</label>
            <input id="bulk-reason" name="reason" className="input btn-sm" placeholder="Reason (required)" minLength={6} required />
            <SubmitButton className="btn btn-sm" confirm="Apply this action to every selected member?">Apply</SubmitButton>
          </form>
        ) : null}
      </div>

      <section className="card">
        {page.rows.length === 0 ? (
          <EmptyState icon={Users} title={query ? "No members match this search" : "No members yet"}>
            {query ? "Try part of a first name, an email address, or paste a full member ID." : "New sign-ups appear here as soon as they create a profile."}
          </EmptyState>
        ) : (
          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr>
                  {canModerate ? <th className="check"><SelectAll formId={bulkFormId} /></th> : null}
                  <th>Member</th>
                  <th>Joined</th>
                  <th>Last active</th>
                  <th>Profile</th>
                  <th>Plan</th>
                  <th>Status</th>
                  {canModerate ? <th className="right">Actions</th> : null}
                </tr>
              </thead>
              <tbody>
                {page.rows.map((user) => {
                  const restricted = user.visibility === "suspended" || user.is_shadowbanned || user.is_banned;
                  const canRestore = !user.is_banned || canBan;
                  const status = user.is_banned ? "banned" : user.is_shadowbanned ? "shadowbanned" : user.visibility;
                  return (
                    <tr key={user.user_id}>
                      {canModerate ? (
                        <td className="check">
                          <input form={bulkFormId} type="checkbox" name="userIds" value={user.user_id} aria-label={`Select ${user.name}`} />
                        </td>
                      ) : null}
                      <td>
                        <MemberIdentity userId={user.user_id} maskedName={user.name} maskedEmail={user.email} canReveal={canReveal} />
                      </td>
                      <td><span className="cell-main num">{formatDate(user.joined_at)}</span><span className="cell-sub">{user.country_code || "—"} · {user.gender || "—"}</span></td>
                      <td className="muted">{relativeTime(user.last_active_at)}</td>
                      <td>
                        <span className="cell-main num">{user.completeness_score ?? 0}% complete</span>
                        <span className="cell-sub">
                          {user.has_verification_badge ? "Photo verified" : "Not photo verified"}
                          {user.approval_block_reason ? ` · ${user.approval_block_reason}` : ""}
                        </span>
                      </td>
                      <td><StatusPill status={user.subscription_status || "none"} label={planLabel[user.subscription_status] ?? undefined} /></td>
                      <td><StatusPill status={status} /></td>
                      {canModerate ? (
                        <td className="right">
                          {canRestore ? (
                            <details className="disclosure">
                              <summary className="btn btn-ghost btn-sm btn-icon" aria-label={`Actions for ${user.name}`}><MoreHorizontal size={16} /></summary>
                              <div className="popover-form">
                                <Link href={`/users/${user.user_id}`} prefetch={false} className="btn btn-sm">Review profile</Link>
                                <form action={accountAction} className="action-row">
                                  <input type="hidden" name="userId" value={user.user_id} />
                                  <input type="hidden" name="returnTo" value={returnTo} />
                                  <input type="hidden" name="action" value={restricted ? "restore" : "suspend"} />
                                  <SubmitButton className="btn btn-sm" confirm={restricted ? undefined : "Suspend this member? Their profile is hidden until restored."}>
                                    {user.is_shadowbanned ? "Remove shadowban" : restricted ? "Restore" : "Suspend"}
                                  </SubmitButton>
                                </form>
                                {canBan && !user.is_banned ? (
                                  <form action={accountAction} className="stack">
                                    <input type="hidden" name="userId" value={user.user_id} />
                                    <input type="hidden" name="returnTo" value={returnTo} />
                                    <input name="reason" className="input btn-sm" placeholder="Reason for audit log" minLength={6} required />
                                    <div className="action-row">
                                      {!user.is_shadowbanned ? <SubmitButton className="btn btn-sm" name="action" value="shadowban">Shadowban</SubmitButton> : null}
                                      <SubmitButton className="btn btn-sm btn-danger" name="action" value="ban" confirm="Ban this member permanently?">Ban</SubmitButton>
                                    </div>
                                  </form>
                                ) : null}
                              </div>
                            </details>
                          ) : <span className="faint">Super admin only</span>}
                        </td>
                      ) : null}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
        {(cursor || page.next) ? (
          <nav className="pager" aria-label="Member pages">
            {cursor ? <Link href={href(query)} prefetch={false} className="link">← Back to newest</Link> : <span>Showing the newest {page.rows.length}</span>}
            {page.next ? (
              <Link href={href(query, encodeCursor(page.next))} prefetch={false} className="btn btn-sm">
                Older members <ChevronRight size={14} />
              </Link>
            ) : <span>End of list</span>}
          </nav>
        ) : page.rows.length > 0 ? (
          <div className="pager"><span>{page.rows.length} of {page.rows.length} shown</span><span>Up to {userPageSize} per page</span></div>
        ) : null}
      </section>
    </div>
  );
}
