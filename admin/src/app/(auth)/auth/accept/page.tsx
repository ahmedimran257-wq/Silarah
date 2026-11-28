import { ArrowRight, KeyRound } from "lucide-react";
import Link from "next/link";
import { SubmitButton } from "@/components/client-ui";
import { acceptStaffLink } from "../actions";

export const metadata = { title: "Staff access" };
export const dynamic = "force-dynamic";

type Props = { searchParams: Promise<{ token?: string; state?: string }> };

// Opening the emailed link only shows this page. The link is used when the
// person presses Continue, so a mail scanner that opens links cannot use it up.
export default async function AcceptPage({ searchParams }: Props) {
  const { token, state } = await searchParams;
  const valid = typeof token === "string" && /^[0-9a-f]{64}$/.test(token);

  return (
    <main className="auth">
      <section className="auth-card" aria-labelledby="accept-title">
        <div className="brand">
          <span className="brand-mark" aria-hidden="true">S</span>
          <span><strong>Silarah</strong><small>Operations</small></span>
        </div>
        {state === "invalid" || (!valid && state !== "unavailable") ? (
          <>
            <h1 id="accept-title">This link no longer works</h1>
            <p className="lede">
              Links work once: an invite for 72 hours, a password reset for one hour, and only the newest one
              sent to you. Ask a super admin to send a new invite, or reset your password from the sign-in page.
            </p>
            <div className="auth-form"><Link href="/forgot-password" className="btn">Reset my password</Link></div>
          </>
        ) : state === "unavailable" ? (
          <>
            <h1 id="accept-title">Sign-in is not available right now</h1>
            <p className="lede">Your link was used but sign-in could not finish. Reset your password from the sign-in page to get a new one.</p>
            <div className="auth-form"><Link href="/forgot-password" className="btn">Reset my password</Link></div>
          </>
        ) : (
          <>
            <h1 id="accept-title">Set up your staff access</h1>
            <p className="lede">Next you choose a password, then confirm with an authenticator app on your phone.</p>
            <form action={acceptStaffLink} className="auth-form">
              <input type="hidden" name="token" value={token} />
              <SubmitButton className="btn btn-primary">Continue <ArrowRight size={16} /></SubmitButton>
            </form>
          </>
        )}
        <p className="auth-foot"><KeyRound size={13} /> Staff only. Every sign-in needs a password and an authenticator code.</p>
      </section>
    </main>
  );
}
