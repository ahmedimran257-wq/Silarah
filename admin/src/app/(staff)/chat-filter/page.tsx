import { MessageSquareWarning } from "lucide-react";
import { SubmitButton } from "@/components/client-ui";
import { EmptyState, NoAccess, PageHeader, formatDate } from "@/components/ui";
import { can } from "@/lib/access";
import { requireArea } from "@/lib/auth";
import { getBlockedTerms, type BlockedTerm } from "@/lib/operations";
import { deleteBlockedTerm, saveBlockedTerm } from "../actions";

export const metadata = { title: "Chat filter" };
export const dynamic = "force-dynamic";

export default async function ChatFilterPage() {
  const { admin, allowed } = await requireArea("chatFilter");
  if (!allowed) return <NoAccess area="Chat filter" />;
  const canEdit = can(admin.role, "manageChatFilter");

  let terms: BlockedTerm[] | null = null;
  try {
    terms = await getBlockedTerms();
  } catch {
    terms = null;
  }

  return (
    <div>
      <PageHeader
        eyebrow="Trust & safety"
        title="Chat filter"
        lede="Words and phrases checked in every chat message. Block stops the message from being sent; flag lets it through and adds it to the review queue."
      />
      <div className="stack">
        {canEdit ? (
          <section className="card">
            <div className="card-head"><h2>Add or update a word</h2></div>
            <div className="card-body">
              <form action={saveBlockedTerm} className="stack">
                <input type="hidden" name="returnTo" value="/chat-filter" />
                <div className="form-grid">
                  <label className="field">Word or phrase
                    <input name="term" className="input" required minLength={2} maxLength={80} placeholder="e.g. send money" />
                  </label>
                  <label className="field">Action
                    <select name="severity" className="select" defaultValue="flag">
                      <option value="flag">Flag for review</option>
                      <option value="block">Block the message</option>
                    </select>
                  </label>
                </div>
                <label className="field">Why (visible to staff only)
                  <input name="reason" className="input" maxLength={200} placeholder="e.g. Common opener in money scams" />
                </label>
                <div className="form-actions"><SubmitButton className="btn btn-primary">Save to filter</SubmitButton></div>
              </form>
            </div>
          </section>
        ) : null}

        {!terms ? (
          <section className="card">
            <EmptyState icon={MessageSquareWarning} title="The filter could not load">Check your staff session and retry.</EmptyState>
          </section>
        ) : terms.length === 0 ? (
          <section className="card">
            <EmptyState icon={MessageSquareWarning} title="The filter is empty">Add words that signal scams, contact sharing or abuse.</EmptyState>
          </section>
        ) : (
          <section className="card">
            <div className="card-head"><h2>{terms.length} {terms.length === 1 ? "entry" : "entries"}</h2></div>
            <div className="list">
              {terms.map((item) => (
                <div className="list-item" key={item.term}>
                  <div>
                    <h3><span className="mono">{item.term}</span> <span className={`pill ${item.severity === "block" ? "danger" : "warn"}`}>{item.severity === "block" ? "Blocks" : "Flags"}</span></h3>
                    <div className="meta">
                      {item.reason ? <span>{item.reason}</span> : null}
                      <span>Added {formatDate(item.created_at)}</span>
                    </div>
                  </div>
                  {canEdit ? (
                    <form action={deleteBlockedTerm}>
                      <input type="hidden" name="term" value={item.term} />
                      <input type="hidden" name="returnTo" value="/chat-filter" />
                      <SubmitButton className="btn" confirm={`Remove "${item.term}" from the chat filter?`}>Remove</SubmitButton>
                    </form>
                  ) : null}
                </div>
              ))}
            </div>
          </section>
        )}
      </div>
    </div>
  );
}
