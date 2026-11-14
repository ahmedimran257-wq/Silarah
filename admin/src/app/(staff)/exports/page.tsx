import { NoAccess, PageHeader } from "@/components/ui";
import { requireArea } from "@/lib/auth";

export const metadata = { title: "Exports" };
export const dynamic = "force-dynamic";

const options = [
  { value: "users", label: "Members", detail: "Member ID, masked email, join date, gender, country, Premium, ban and deletion status. No names, photos or messages." },
  { value: "reports", label: "Reports", detail: "Report ID, date, reason, status and the member IDs involved." },
  { value: "audit", label: "Audit trail", detail: "Every staff action: when, what, which staff member and which member." },
];

export default async function ExportsPage() {
  const { allowed } = await requireArea("exports");
  if (!allowed) return <NoAccess area="Exports" />;

  return (
    <div>
      <PageHeader
        eyebrow="Governance"
        title="Exports"
        lede="Download up to 5,000 recent rows as a spreadsheet file. Every export is recorded with its purpose. Store files securely and delete them when the purpose is met."
      />
      <div className="stack">
        {options.map((option) => (
          <section className="card" key={option.value}>
            <div className="card-head"><h2>{option.label}</h2></div>
            <div className="card-body">
              <form action="/api/export" method="post" className="stack">
                <input type="hidden" name="type" value={option.value} />
                <p className="muted">{option.detail}</p>
                <label className="field">Purpose (recorded in the audit trail)
                  <input name="purpose" className="input" required minLength={12} maxLength={300} placeholder="e.g. Monthly safety review for the board" />
                </label>
                <div className="form-actions"><button type="submit" className="btn btn-primary">Download CSV</button></div>
              </form>
            </div>
          </section>
        ))}
      </div>
    </div>
  );
}
