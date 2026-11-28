import { Phone, WalletCards } from "lucide-react";
import Link from "next/link";
import { EmptyState, formatDate, formatDateTime } from "@/components/ui";
import { callResult, ledgerKind, talkTime } from "@/lib/labels";
import type { MemberCallRow, MemberCallWallet } from "@/lib/operations";

// One member's calling, for support and safety cases: minutes, what is
// waiting, the ledger and the call log. Metadata only; audio never exists.

function Fact({ label, value }: { label: string; value: React.ReactNode }) {
  return <div><dt>{label}</dt><dd>{value}</dd></div>;
}

function signed(value: number) {
  if (!value) return "—";
  return value > 0 ? `+${value}` : String(value);
}

const callModes: Record<string, string> = {
  ring: "Ring",
  silent: "Silent (no ringing; calls show as missed)",
  off: "Calls off",
};

export function MemberCallWalletCard({ wallet, userId }: { wallet: MemberCallWallet | null | undefined; userId: string }) {
  return (
    <section className="card">
      <div className="card-head">
        <h2><WalletCards size={16} /> Call minutes</h2>
        <Link href={`/calls?tab=member&member=${userId}`} prefetch={false} className="btn btn-sm btn-ghost">Calls page</Link>
      </div>
      <div className="card-body stack">
        {wallet === undefined ? null : wallet === null ? (
          <p className="notice danger"><span>Call minutes could not load for this member.</span></p>
        ) : (
          <>
            <dl className="kv">
              <Fact label="Premium" value={wallet.premium ? "Yes" : "No"} />
              <Fact
                label="Included this period"
                value={wallet.period
                  ? `${wallet.period.remaining} of ${wallet.period.granted} left (${wallet.period.used} used) · ${formatDate(wallet.period.start)} – ${formatDate(wallet.period.end)}${wallet.period.forfeited_at ? ` · forfeited ${formatDate(wallet.period.forfeited_at)}` : ""}`
                  : wallet.premium ? "Starts when the member next opens calling" : "None (not Premium)"}
              />
              <Fact label="Pack minutes" value={wallet.pack_minutes < 0
                ? <span className="pill danger">{wallet.pack_minutes} (refund after use — calling blocked until topped up)</span>
                : wallet.pack_minutes} />
              <Fact label="Held for a live call" value={wallet.held_now || "—"} />
              <Fact label="Charged this month" value={`${wallet.month_charged_minutes} minutes`} />
              <Fact label="Ringing" value={callModes[wallet.call_mode] ?? wallet.call_mode} />
              <Fact label="Chats with calls blocked" value={wallet.chats_with_calls_blocked} />
            </dl>

            {wallet.packs_waiting.length > 0 || wallet.pending_refunds.length > 0 ? (
              <div className="notice warn">
                <span>
                  {wallet.packs_waiting.length > 0 ? (
                    <>
                      <strong>{wallet.packs_waiting.length} paid {wallet.packs_waiting.length === 1 ? "pack" : "packs"} not credited yet</strong>
                      {" "}({wallet.packs_waiting.map((p) => `${p.product_id} · ${formatDateTime(p.received_at)}`).join("; ")}).
                      {" "}Confirm the Play order, then credit it under Packs waiting on the <Link href="/calls?tab=packs" prefetch={false} className="link">Calls page</Link>.{" "}
                    </>
                  ) : null}
                  {wallet.pending_refunds.length > 0 ? (
                    <>
                      <strong>{wallet.pending_refunds.length} {wallet.pending_refunds.length === 1 ? "refund" : "refunds"} waiting for {wallet.pending_refunds.length === 1 ? "its" : "their"} purchase</strong>
                      {" "}({wallet.pending_refunds.map((r) => `${r.product_id} · order ${r.transaction_id}`).join("; ")}). It is taken off automatically when the purchase arrives.
                    </>
                  ) : null}
                </span>
              </div>
            ) : null}

            {wallet.packs_claimed.length > 0 ? (
              <p className="faint">
                Packs credited after a store mismatch: {wallet.packs_claimed.map((p) => `${p.product_id} on ${formatDate(p.claimed_at)}${p.claim_source ? ` (${p.claim_source})` : ""}`).join("; ")}.
              </p>
            ) : null}

            {wallet.ledger.length === 0 ? (
              <p className="faint">No purchases, refunds, charges or adjustments yet.</p>
            ) : (
              <details className="disclosure">
                <summary className="link">Minutes ledger ({wallet.ledger.length} most recent)</summary>
                <div className="table-wrap">
                  <table className="table">
                    <thead><tr><th>When</th><th>What</th><th>Pack</th><th>Included</th><th>Order / note</th></tr></thead>
                    <tbody>
                      {wallet.ledger.map((row) => (
                        <tr key={row.id}>
                          <td>{formatDateTime(row.created_at)}</td>
                          <td>{ledgerKind(row.kind)}{row.product_id ? <span className="cell-sub">{row.product_id}</span> : null}</td>
                          <td>{signed(row.pack)}</td>
                          <td>{signed(row.included)}</td>
                          <td className="mono">{row.transaction_id ?? ""}{row.note ? <span className="cell-sub">{row.note}</span> : null}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </details>
            )}
          </>
        )}
      </div>
    </section>
  );
}

export function MemberCallHistoryTable({ history, showOther = true }: { history: MemberCallRow[] | null; showOther?: boolean }) {
  if (history === null) return <p className="notice danger"><span>Calls could not load for this member.</span></p>;
  if (history.length === 0) {
    return <EmptyState icon={Phone} title="No calls">This member has no call records in the retention period.</EmptyState>;
  }
  return (
    <div className="table-wrap">
      <table className="table">
        <thead>
          <tr><th>When</th><th>Direction</th>{showOther ? <th>Other member</th> : null}<th>Result</th><th>Talk time</th><th>Minutes charged</th></tr>
        </thead>
        <tbody>
          {history.map((row) => (
            <tr key={row.request_id}>
              <td>{formatDateTime(row.created_at)}</td>
              <td>{row.direction === "outgoing" ? "Called" : "Was called"}</td>
              {showOther ? (
                <td><Link href={`/users/${row.other_user_id}`} prefetch={false} className="mono">{row.other_user_id.slice(0, 8)}</Link></td>
              ) : null}
              <td>{callResult(row.status, row.reason)}{row.hidden_by_member ? <span className="cell-sub">removed from their history</span> : null}</td>
              <td>{talkTime(row.connected_seconds)}</td>
              <td>{row.charged_minutes ?? "—"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
