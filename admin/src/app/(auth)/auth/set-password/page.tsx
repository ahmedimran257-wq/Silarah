import { KeyRound } from "lucide-react";
import { redirect } from "next/navigation";
import { SubmitButton } from "@/components/client-ui";
import { requireStaffSession } from "@/lib/auth";
import { passwordSetupFor } from "@/lib/staff-access";
import { setStaffPassword } from "../actions";

export const metadata = { title: "Choose a password" };
export const dynamic = "force-dynamic";

// Only the messages setStaffPassword writes are shown.
const knownErrors = new Set([
  "Use at least 12 characters.",
  "Use at most 72 characters.",
  "Use letters and at least one number.",
  "The two passwords do not match.",
  "That password is too easy to guess. Choose a longer one.",
  "The password could not be saved. Please try again.",
  "Check the password.",
]);

export default async function SetPasswordPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const admin = await requireStaffSession();
  const kind = await passwordSetupFor(admin.id);
  if (!kind) redirect("/auth/accept?state=invalid");
  const { error } = await searchParams;
  const message = error && knownErrors.has(error) ? error : error ? "Check the password." : null;

  return (
    <main className="auth">
      <section className="auth-card" aria-labelledby="password-title">
        <div className="brand">
          <span className="brand-mark" aria-hidden="true">S</span>
          <span><strong>Silarah</strong><small>Operations</small></span>
        </div>
        <h1 id="password-title">{kind === "invite" ? "Choose your password" : "Choose a new password"}</h1>
        <p className="lede">
          For <strong>{admin.email}</strong>. If you also use this address in the Silarah app, this becomes your app password too.
        </p>
        <form action={setStaffPassword} className="auth-form">
          <label className="field" htmlFor="password">New password
            <input id="password" name="password" type="password" className="input" autoComplete="new-password" required minLength={12} maxLength={72} autoFocus />
          </label>
          <label className="field" htmlFor="confirm">Type it again
            <input id="confirm" name="confirm" type="password" className="input" autoComplete="new-password" required minLength={12} maxLength={72} />
          </label>
          <p className="faint">At least 12 characters, with letters and a number.</p>
          {message ? <p className="notice danger" role="alert"><span>{message}</span></p> : null}
          <SubmitButton className="btn btn-primary">Save and continue</SubmitButton>
        </form>
        <p className="auth-foot"><KeyRound size={13} /> Next: your authenticator app.</p>
      </section>
    </main>
  );
}
