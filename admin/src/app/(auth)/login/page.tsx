import { ArrowRight, LockKeyhole } from "lucide-react";
import Link from "next/link";
import { SubmitButton } from "@/components/client-ui";
import { signIn } from "./actions";

export const metadata = { title: "Sign in" };

type LoginPageProps = { searchParams: Promise<{ error?: string }> };

// Only messages this app writes are shown; anything else in the URL is
// replaced so a crafted link cannot put arbitrary text on the sign-in page.
const knownErrors = new Set([
  "Enter a valid email and password.",
  "Secure login is temporarily unavailable. Please try again.",
  "Too many attempts. Please wait and try again.",
  "Invalid email or password.",
  "Session expired. Please sign in again.",
]);

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const params = await searchParams;
  const error = params.error ? (knownErrors.has(params.error) ? params.error : "Please sign in again.") : null;

  return (
    <main className="auth">
      <section className="auth-card" aria-labelledby="login-title">
        <div className="brand">
          <span className="brand-mark" aria-hidden="true">S</span>
          <span><strong>Silarah</strong><small>Operations</small></span>
        </div>
        <h1 id="login-title">Staff sign in</h1>
        <p className="lede">For the Silarah team only. You will confirm with your authenticator app next.</p>

        <form action={signIn} className="auth-form">
          <label className="field" htmlFor="email">Work email
            <input id="email" name="email" type="email" className="input" autoComplete="username" required autoFocus />
          </label>
          <label className="field" htmlFor="password">Password
            <input id="password" name="password" type="password" className="input" autoComplete="current-password" required minLength={8} />
          </label>
          {error ? <p className="notice danger" role="alert"><span>{error}</span></p> : null}
          <SubmitButton className="btn btn-primary">Continue <ArrowRight size={16} /></SubmitButton>
        </form>
        <p className="faint"><Link href="/forgot-password" className="link">Forgot your password?</Link></p>

        <p className="auth-foot"><LockKeyhole size={13} /> Every sensitive action is role-checked and written to the audit trail.</p>
      </section>
    </main>
  );
}
