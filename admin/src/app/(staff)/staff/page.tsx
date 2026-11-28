import { KeyRound, Mail, ShieldPlus, UserMinus } from "lucide-react";
import { SubmitButton } from "@/components/client-ui";
import { EmptyState, NoAccess, PageHeader, formatDateTime, relativeTime } from "@/components/ui";
import { roleLabels, type AdminRole } from "@/lib/access";
import { requireArea } from "@/lib/auth";
import { getStaffMembers, type StaffMemberRow } from "@/lib/operations";
import { inviteStaffMember, removeStaffMember, resetStaffAuthenticator, sendStaffAccessLink, updateStaffMember } from "../actions";

export const metadata = { title: "Staff access" };

const roles: AdminRole[] = ["support", "moderator", "super_admin"];
const roleHelp: Record<AdminRole, string> = {
  support: "Member rights, content, stories and campaigns",
  moderator: "Photo checks, reports, member actions and reveals",
  super_admin: "Everything, including bans, staff and security",
};

function accessState(member: StaffMemberRow) {
  if (member.status !== "active") return { label: "Revoked", tone: "danger" };
  if (member.link_pending_kind === "invite") return { label: "Invite sent", tone: "info" };
  if (!member.has_authenticator) return { label: "No authenticator yet", tone: "warn" };
  return { label: "Ready", tone: "ok" };
}

function RemoveForm({ member, note }: { member: StaffMemberRow; note?: string }) {
  return (
    <details className="disclosure">
      <summary className="btn btn-sm btn-ghost"><UserMinus size={14} /> Remove…</summary>
      <form action={removeStaffMember} className="popover-form">
        <input type="hidden" name="userId" value={member.user_id} />
        <input type="hidden" name="returnTo" value="/staff" />
        {note ? <p className="muted">{note}</p> : null}
        <label className="field">Reason for the audit log
          <input name="reason" className="input" required minLength={6} maxLength={500} placeholder="e.g. Left the team" />
        </label>
        <SubmitButton className="btn btn-sm btn-danger" confirm={`Remove ${member.email} from staff?`}>Remove from staff</SubmitButton>
      </form>
    </details>
  );
}

export default async function StaffPage() {
  const { admin, allowed } = await requireArea("staff");
  if (!allowed) return <NoAccess area="Staff access" />;
  const staff = await getStaffMembers();

  return (
    <div className="stack-lg">
      <PageHeader
        eyebrow="Governance"
        title="Staff access"
        lede="Invite people by email and give them the smallest role that covers their work. Each invite emails a one-time link to choose a password and set up an authenticator app."
      />

      <div className="split">
        <section className="card">
          <div className="card-head"><h2>Team</h2><span className="muted">{staff.length} {staff.length === 1 ? "account" : "accounts"}</span></div>
          {staff.length === 0 ? (
            <EmptyState icon={ShieldPlus} title="No staff memberships">Invite your first teammate with the form.</EmptyState>
          ) : (
            <div className="list">
              {staff.map((member) => {
                const self = member.user_id === admin.id;
                const state = accessState(member);
                return (
                  <article className="list-item staff-item" key={member.user_id}>
                    <form action={updateStaffMember} className="staff-row">
                      <input type="hidden" name="userId" value={member.user_id} />
                      <input type="hidden" name="returnTo" value="/staff" />
                      <div>
                        <h3>{member.email} {self ? <span className="pill gold plain">You</span> : null} <span className={`pill ${state.tone}`}>{state.label}</span></h3>
                        <div className="meta">
                          <span>last sign-in {relativeTime(member.last_sign_in_at)}</span>
                          {member.link_pending_until ? <span>{member.link_pending_kind === "invite" ? "invite" : "reset link"} valid until {formatDateTime(member.link_pending_until)}</span> : null}
                          <span className="mono">{member.user_id.slice(0, 8)}</span>
                        </div>
                      </div>
                      <div className="aside">
                        <label className="sr-only" htmlFor={`role-${member.user_id}`}>Role</label>
                        <select id={`role-${member.user_id}`} name="role" defaultValue={member.role} className="select btn-sm" disabled={self}>
                          {roles.map((role) => <option key={role} value={role}>{roleLabels[role]}</option>)}
                        </select>
                        <label className="sr-only" htmlFor={`status-${member.user_id}`}>Status</label>
                        <select id={`status-${member.user_id}`} name="status" defaultValue={member.status} className="select btn-sm" disabled={self}>
                          <option value="active">Active</option>
                          <option value="revoked">Revoked</option>
                        </select>
                        {self ? (
                          <>
                            <input type="hidden" name="role" value={member.role} />
                            <input type="hidden" name="status" value={member.status} />
                          </>
                        ) : null}
                        <label className="check-row"><input type="checkbox" name="mfaRequired" defaultChecked={member.mfa_required} /> MFA</label>
                        <SubmitButton className="btn btn-sm">Save</SubmitButton>
                      </div>
                    </form>

                    {self ? null : member.status === "active" ? (
                      <div className="action-row staff-tools">
                        <form action={sendStaffAccessLink}>
                          <input type="hidden" name="userId" value={member.user_id} />
                          <input type="hidden" name="kind" value={member.has_authenticator ? "reset" : "invite"} />
                          <input type="hidden" name="returnTo" value="/staff" />
                          <SubmitButton className="btn btn-sm btn-ghost">
                            <Mail size={14} /> {member.has_authenticator ? "Email password reset" : "Resend invite"}
                          </SubmitButton>
                        </form>
                        {member.has_authenticator ? (
                          <details className="disclosure">
                            <summary className="btn btn-sm btn-ghost"><KeyRound size={14} /> Reset authenticator…</summary>
                            <form action={resetStaffAuthenticator} className="popover-form">
                              <input type="hidden" name="userId" value={member.user_id} />
                              <input type="hidden" name="returnTo" value="/staff" />
                              <p className="muted">Removes their authenticator and signs them out of the panel. They set up a new one at the next sign-in. Confirm who is asking first.</p>
                              <label className="field">Reason for the audit log
                                <input name="reason" className="input" required minLength={6} maxLength={500} placeholder="e.g. Lost phone, confirmed by call" />
                              </label>
                              <SubmitButton className="btn btn-sm btn-danger" confirm="Remove this person's authenticator?">Reset authenticator</SubmitButton>
                            </form>
                          </details>
                        ) : null}
                        <RemoveForm member={member} note="Takes them off the staff list and ends their panel sessions. A Silarah member account with the same address is not touched." />
                      </div>
                    ) : (
                      <div className="action-row staff-tools"><RemoveForm member={member} /></div>
                    )}
                  </article>
                );
              })}
            </div>
          )}
        </section>

        <section className="card">
          <div className="card-head"><h2><ShieldPlus size={16} /> Invite</h2></div>
          <form action={inviteStaffMember} className="card-body stack">
            <input type="hidden" name="returnTo" value="/staff" />
            <label className="field">Email<input name="email" type="email" className="input" required placeholder="name@silarah.com" autoComplete="off" /></label>
            <fieldset className="stack">
              <legend className="field">Role</legend>
              {roles.map((role) => (
                <label key={role} className="check-row">
                  <input type="radio" name="role" value={role} defaultChecked={role === "support"} />
                  <span><strong>{roleLabels[role]}</strong><br /><span className="muted">{roleHelp[role]}</span></span>
                </label>
              ))}
            </fieldset>
            <p className="faint">
              They get an email with a link that works for 72 hours. If the address already has a Silarah account, that account is used.
              Staff who forget their password use “Forgot your password?” on the sign-in page.
            </p>
            <div className="form-actions"><SubmitButton className="btn btn-primary">Send invite</SubmitButton></div>
          </form>
        </section>
      </div>
    </div>
  );
}
