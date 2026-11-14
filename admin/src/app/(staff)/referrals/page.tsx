import { Gift } from "lucide-react";
import Link from "next/link";
import { SubmitButton } from "@/components/client-ui";
import { EmptyState, NoAccess, PageHeader, Stat, formatDate } from "@/components/ui";
import { can } from "@/lib/access";
import { requireArea } from "@/lib/auth";
import { getReferralOverview, type ReferralOverview } from "@/lib/operations";
import { endReferralGrant } from "../actions";

export const metadata = { title: "Referrals" };
export const dynamic = "force-dynamic";

export default async function ReferralsPage() {
  const { admin, allowed } = await requireArea("referrals");
  if (!allowed) return <NoAccess area="Referrals" />;
  const canEnd = can(admin.role, "endReferralGrants");

  let overview: ReferralOverview | null = null;
  try {
    overview = await getReferralOverview();
  } catch {
    overview = null;
  }

  return (
    <div>
      <PageHeader
        eyebrow="Members"
        title="Referrals"
        lede="Who invited whom, and the free Premium each referral earned. End a reward only when a referral was abused, for example accounts made only to collect it."
      />
      {!overview ? (
        <section className="card">
          <EmptyState icon={Gift} title="Referrals could not load">Check your staff session and retry.</EmptyState>
        </section>
      ) : (
        <div className="stack">
          <div className="stat-grid">
            <Stat label="Referrals" value={overview.totals.referrals} />
            <Stat label="Rewarded" value={overview.totals.rewarded} />
            <Stat label="Rewards active now" value={overview.totals.activeGrants} />
          </div>
          {overview.referrals.length === 0 ? (
            <section className="card">
              <EmptyState icon={Gift} title="No referrals yet">When a member joins with a referral code, it appears here.</EmptyState>
            </section>
          ) : overview.referrals.map((item) => (
            <article className="card" key={item.id}>
              <header className="card-head">
                <div>
                  <p className="eyebrow">{formatDate(item.createdAt)}</p>
                  <h2>{item.referrer ?? "Deleted member"} <span className="faint">invited</span> {item.referred ?? "Deleted member"}</h2>
                </div>
                <span className={`pill ${item.rewarded ? "ok" : "plain"}`}>{item.rewarded ? "Rewarded" : "Not rewarded yet"}</span>
              </header>
              <div className="card-body stack">
                <div className="action-row">
                  <Link href={`/users/${item.referrerId}`} prefetch={false} className="btn">Open inviter</Link>
                  <Link href={`/users/${item.referredId}`} prefetch={false} className="btn">Open new member</Link>
                </div>
                {item.grants.length > 0 ? (
                  <div className="list">
                    {item.grants.map((grant) => (
                      <div className="list-item" key={grant.id}>
                        <div>
                          <h3>{grant.role === "referrer" ? "Inviter's reward" : "New member's reward"} <span className={`pill ${grant.active ? "ok" : "plain"}`}>{grant.active ? "Active" : "Ended"}</span></h3>
                          <div className="meta"><span>{formatDate(grant.startsAt)} to {formatDate(grant.expiresAt)}</span></div>
                        </div>
                        {canEnd && grant.active ? (
                          <details className="disclosure">
                            <summary className="link">End reward</summary>
                            <form action={endReferralGrant} className="popover-form">
                              <input type="hidden" name="grantId" value={grant.id} />
                              <input type="hidden" name="returnTo" value="/referrals" />
                              <label className="field">Reason for the audit log
                                <input name="reason" className="input" required minLength={6} maxLength={500} placeholder="e.g. Same person on both accounts" />
                              </label>
                              <div className="form-actions"><SubmitButton className="btn btn-danger" confirm="End this Premium reward now?">End reward</SubmitButton></div>
                            </form>
                          </details>
                        ) : null}
                      </div>
                    ))}
                  </div>
                ) : null}
              </div>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
