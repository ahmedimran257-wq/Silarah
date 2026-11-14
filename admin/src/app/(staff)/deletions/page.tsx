import { AlertTriangle, Clock, Mail, MailWarning, UserRoundX } from "lucide-react";
import Link from "next/link";
import { SubmitButton } from "@/components/client-ui";
import { EmptyState, NoAccess, PageHeader, Stat, formatDate, formatDateTime, isPast } from "@/components/ui";
import { can } from "@/lib/access";
import { requireArea } from "@/lib/auth";
import { getAccountDeletions, type AccountDeletionQueue } from "@/lib/operations";
import { cancelAccountDeletion, recordEmailDeletionRequest, scheduleAccountDeletion } from "../actions";

export const metadata = { title: "Deletions" };
export const dynamic = "force-dynamic";

const sourceLabel = {
  email: "Requested by email",
  staff: "Started by staff",
  app: "Requested in the app",
} as const;

function phaseLabel(phase: string | null, status: string | null) {
  if (!phase) return "Waiting";
  if (status === "dead_letter") return "Needs attention";
  if (status === "failed") return `Retrying (${phase})`;
  if (phase === "completed") return "Purged";
  return `Purging (${phase})`;
}

export default async function DeletionsPage() {
  const { admin, allowed } = await requireArea("deletions");
  if (!allowed) return <NoAccess area="Deletions" />;
  const canManage = can(admin.role, "manageDeletions");
  const canRecordEmail = can(admin.role, "recordEmailDeletion");

  let queue: AccountDeletionQueue | null = null;
  try {
    queue = await getAccountDeletions();
  } catch {
    queue = null;
  }

  return (
    <div>
      <PageHeader
        eyebrow="Trust & safety"
        title="Deletions"
        lede="Accounts waiting to be deleted. Members can cancel by signing in during the 30-day window; after that the nightly purge removes their photos, sign-in and data, then emails a final confirmation."
      />

      {!queue ? (
        <section className="card">
          <EmptyState icon={UserRoundX} title="The deletion queue could not load">
            Check your staff session and retry. Nothing was changed.
          </EmptyState>
        </section>
      ) : (
        <div className="stack">
          <div className="stat-grid">
            <Stat label="Waiting" value={String(queue.pending.length)} />
            <Stat label="Purged in 30 days" value={String(queue.completedLast30Days)} />
            <Stat label="Emails waiting" value={String(queue.emailsWaiting)} />
            <Stat label="Emails failed" value={String(queue.emailsFailed)} />
          </div>

          {canRecordEmail ? (
            <section className="card">
              <div className="card-head">
                <div>
                  <p className="eyebrow"><Mail size={12} />privacy@silarah.com</p>
                  <h2>Record an email deletion request</h2>
                </div>
              </div>
              <div className="card-body">
                <details className="disclosure">
                  <summary className="link">A member asked by email instead of using the app</summary>
                  <form action={recordEmailDeletionRequest} className="stack">
                    <input type="hidden" name="returnTo" value="/deletions" />
                    <p className="muted">
                      Only act when the email came from the address registered on the account. Copy the sender&apos;s
                      address exactly; if no account matches, reply asking them to write from their registered address.
                      The member gets the usual 30-day email and can still cancel by signing in.
                    </p>
                    <label className="field">Sender&apos;s email address
                      <input name="email" type="email" className="input" required maxLength={320} autoComplete="off" spellCheck={false} placeholder="name@example.com" />
                    </label>
                    <label className="field">Date the email arrived
                      <input name="receivedOn" type="date" className="input" required />
                    </label>
                    <label className="field">Note for the audit log (optional)
                      <input name="note" className="input" maxLength={400} placeholder="e.g. Subject: Delete my account" />
                    </label>
                    {canManage ? (
                      <label className="check-row">
                        <input type="checkbox" name="immediate" value="true" />
                        <span>Delete now instead of after 30 days (only when the member asked for immediate deletion)</span>
                      </label>
                    ) : null}
                    <div className="form-actions">
                      <SubmitButton className="btn btn-primary" confirm="Record this deletion request for the account registered to this email?">Record request</SubmitButton>
                    </div>
                  </form>
                </details>
              </div>
            </section>
          ) : null}

          {queue.stuck.length > 0 ? (
            <p role="alert" className="notice danger">
              <AlertTriangle size={16} />
              <span>
                {queue.stuck.length} purge {queue.stuck.length === 1 ? "job is" : "jobs are"} retrying or stopped.
                The purge retries on its own with backoff; one marked &ldquo;Needs attention&rdquo; has stopped and needs a developer.
              </span>
            </p>
          ) : null}
          {queue.emailsFailed > 0 ? (
            <p role="alert" className="notice danger">
              <MailWarning size={16} />
              <span>{queue.emailsFailed} account email(s) could not be delivered after six tries. Check the email provider in System health.</span>
            </p>
          ) : null}

          {queue.pending.length === 0 ? (
            <section className="card">
              <EmptyState icon={UserRoundX} title="No accounts are waiting to be deleted">
                When a member deletes their account in the app, emails a request, or staff start a deletion from a member&apos;s page, it appears here.
              </EmptyState>
            </section>
          ) : queue.pending.map((item) => {
            const due = isPast(item.purgeAfter);
            const started = Boolean(item.purgePhase);
            return (
              <article className="card" key={item.userId}>
                <header className="card-head">
                  <div>
                    <p className="eyebrow">{sourceLabel[item.source ?? (item.byStaff ? "staff" : "app")]}</p>
                    <h2>{item.name ?? "Member"} <span className="faint">{item.email ?? ""}</span></h2>
                  </div>
                  <span className={`pill ${due ? "danger" : "plain"}`}>
                    <Clock size={12} /> {due ? "Due for purge" : `Purge on ${formatDate(item.purgeAfter)}`}
                  </span>
                </header>
                <div className="card-body stack">
                  <dl className="kv">
                    <div><dt>Requested</dt><dd>{formatDateTime(item.requestedAt)}</dd></div>
                    <div><dt>Status</dt><dd>{phaseLabel(item.purgePhase, item.purgeStatus)}</dd></div>
                    {item.reason ? <div><dt>Reason</dt><dd>{item.reason}</dd></div> : null}
                    {item.purgeError ? <div><dt>Last error</dt><dd className="mono">{item.purgeError}</dd></div> : null}
                  </dl>
                  <div className="action-row">
                    <Link href={`/users/${item.userId}`} prefetch={false} className="btn">Open member</Link>
                  </div>
                  {canManage && !started ? (
                    <details className="disclosure">
                      <summary className="link">Cancel or delete now</summary>
                      <div className="stack">
                        <form action={cancelAccountDeletion} className="stack">
                          <input type="hidden" name="userId" value={item.userId} />
                          <input type="hidden" name="returnTo" value="/deletions" />
                          <label className="field">Reason for the audit log
                            <input name="reason" className="input" minLength={6} maxLength={500} required placeholder="e.g. Member asked by email to keep the account" />
                          </label>
                          <div className="form-actions">
                            <SubmitButton className="btn">Cancel deletion</SubmitButton>
                          </div>
                        </form>
                        {!due ? (
                          <form action={scheduleAccountDeletion} className="stack">
                            <input type="hidden" name="userId" value={item.userId} />
                            <input type="hidden" name="immediate" value="true" />
                            <input type="hidden" name="returnTo" value="/deletions" />
                            <label className="field">Reason for deleting before the 30 days end
                              <input name="reason" className="input" minLength={6} maxLength={500} required placeholder="e.g. Verified written request to delete immediately" />
                            </label>
                            <div className="form-actions">
                              <SubmitButton className="btn btn-danger" confirm="Delete this account now? This cannot be undone.">Delete now</SubmitButton>
                            </div>
                          </form>
                        ) : null}
                      </div>
                    </details>
                  ) : started ? (
                    <p className="faint">The purge has started, so this deletion can no longer be cancelled.</p>
                  ) : null}
                </div>
              </article>
            );
          })}
        </div>
      )}
    </div>
  );
}
