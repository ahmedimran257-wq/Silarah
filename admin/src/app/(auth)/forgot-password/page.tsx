import { ArrowLeft, Mail } from "lucide-react";
import Link from "next/link";
import { SubmitButton } from "@/components/client-ui";
import { requestStaffPasswordReset } from "../auth/actions";

export const metadata = { title: "Reset password" };

const errors: Record<string, string> = {
  email: "Enter the full email address you use for staff sign-in.",
  busy: "Too many attempts, or the service is busy. Please wait a few minutes and try again.",
};

export default async function ForgotPasswordPage({ searchParams }: { searchParams: Promise<{ sent?: string; error?: string }> }) {
  const { sent, error } = await searchParams;
  return (
    <main className="auth">
      <section className="auth-card" aria-labelledby="forgot-title">
        <div className="brand">
          <span className="brand-mark" aria-hidden="true">S</span>
          <span><strong>Silarah</strong><small>Operations</small></span>
        </div>
        <h1 id="forgot-title">Reset your password</h1>
        {sent ? (
          <p className="notice ok" role="status">
            <Mail size={16} />
            <span>If that address belongs to Silarah staff, a reset link is on its way. It works once, for one hour. Check spam if it has not arrived in a few minutes.</span>
          </p>
        ) : (
          <>
            <p className="lede">We email a one-time link. You still confirm with your authenticator afterwards.</p>
            <form action={requestStaffPasswordReset} className="auth-form">
              <label className="field" htmlFor="email">Work email
                <input id="email" name="email" type="email" className="input" autoComplete="username" required autoFocus />
              </label>
              {error && errors[error] ? <p className="notice danger" role="alert"><span>{errors[error]}</span></p> : null}
              <SubmitButton className="btn btn-primary">Email me a link</SubmitButton>
            </form>
          </>
        )}
        <p className="auth-foot"><Link href="/login" className="link"><ArrowLeft size={13} /> Back to sign in</Link></p>
        <p className="faint">Lost your authenticator? Ask a super admin to reset it from Staff access.</p>
      </section>
    </main>
  );
}
