// EDGE FUNCTION: account-email
//
// Tells members, by email, that their account deletion was requested,
// cancelled or completed. The database queues one row per event
// (private.account_emails) and wakes this worker through pg_net; an hourly
// cron retries anything left behind. The completion notice is released only
// after the member's data is gone, and its address is erased once sent.
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { corsHeaders } from "../_shared/cors.ts";
import { isAuthorizedCronRequest } from "../_shared/cron_auth.ts";
import {
  button,
  escapeHtml,
  greeting,
  HELP_URL,
  note,
  panel,
  paragraph,
  PRIVACY_URL,
  renderEmailLayout,
  signOff,
  steps,
  SUPPORT_EMAIL,
} from "../_shared/email_layout.ts";
import {
  type RenderedTransactionalEmail,
  sendBrevoTransactionalEmail,
} from "../_shared/transactional_email.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY") ?? "";
const PLAY_SUBSCRIPTIONS_URL =
  "https://play.google.com/store/account/subscriptions";

type AccountEvent =
  | "deletion_requested"
  | "deletion_cancelled"
  | "deletion_completed";

export interface QueuedAccountEmail {
  email_id: string;
  email_event: AccountEvent;
  recipient: string | null;
  purge_after_at: string | null;
  first_name: string | null;
}

const REASON =
  "You are receiving this because of a change to your Silarah account. It is a service message, not marketing.";

function formatDate(value: string | null, now: Date): string | null {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  if (date.getTime() - now.getTime() < 24 * 60 * 60 * 1000) return null;
  return new Intl.DateTimeFormat("en-IN", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "Asia/Kolkata",
  }).format(date);
}

export function renderAccountEmail(
  row: QueuedAccountEmail,
  now = new Date(),
): RenderedTransactionalEmail {
  const name = row.first_name?.trim();
  const hello = greeting(
    name ? `Assalamu alaikum ${escapeHtml(name)},` : "Assalamu alaikum,",
  );
  const playNote = note(
    `Deleting your account does not cancel a Google Play subscription. If you have one, cancel it in <a href="${PLAY_SUBSCRIPTIONS_URL}">Google Play subscriptions</a>.`,
  );

  if (row.email_event === "deletion_requested") {
    const date = formatDate(row.purge_after_at, now);
    const when = date ? `on ${date}` : "within the next 24 hours";
    const subject = "We received your request to delete your Silarah account";
    const body = [
      hello,
      paragraph(
        `Your profile is now hidden from other members. Your account and the personal data in it will be permanently deleted ${
          escapeHtml(when)
        }.`,
      ),
      date
        ? panel(
          "Changed your mind?",
          `Sign in to Silarah before ${escapeHtml(date)} to keep your account.`,
        )
        : "",
      steps("What will be deleted", [
        [
          "Your profile",
          "Details, preferences, photos and verification results.",
        ],
        [
          "Your conversations",
          "Messages, interests, matches and saved profiles.",
        ],
        ["Your sign-in", "Your Silarah account itself."],
      ]),
      paragraph(
        `We keep only the minimum records the law requires, such as payment and tax records, abuse-prevention records and proof of consent, and only for as long as required. See our <a href="${PRIVACY_URL}">Privacy Policy</a>.`,
      ),
      playNote,
      signOff("The Silarah team"),
    ].join("\n");
    const text = [
      name ? `Assalamu alaikum ${name},` : "Assalamu alaikum,",
      "",
      `Your profile is now hidden from other members. Your account and the personal data in it will be permanently deleted ${when}.`,
      date
        ? `Changed your mind? Sign in to Silarah before ${date} to keep your account.`
        : "",
      "",
      "We delete your profile, details, preferences, photos, verification results, messages, interests, matches, saved profiles and sign-in account.",
      "We keep only the minimum records the law requires, such as payment and tax records, abuse-prevention records and proof of consent, and only for as long as required.",
      `Privacy Policy: ${PRIVACY_URL}`,
      "",
      `Deleting your account does not cancel a Google Play subscription: ${PLAY_SUBSCRIPTIONS_URL}`,
      "",
      "The Silarah team",
      "",
      REASON,
    ].filter((line, index, all) => line !== "" || all[index - 1] !== "").join(
      "\n",
    );
    return {
      subject,
      html: renderEmailLayout({
        title: subject,
        preheader: `Your account will be deleted ${when}.`,
        eyebrow: "Account deletion",
        heading: "Your deletion request is in",
        body,
        reason: escapeHtml(REASON),
        tone: "attention",
      }),
      text,
    };
  }

  if (row.email_event === "deletion_cancelled") {
    const subject = "Your Silarah account will not be deleted";
    const body = [
      hello,
      paragraph(
        "Your account deletion has been cancelled. Your profile, photos and conversations are just as you left them.",
      ),
      paragraph(
        `If you did not ask for this, contact us at <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a>.`,
      ),
      signOff("The Silarah team"),
    ].join("\n");
    return {
      subject,
      html: renderEmailLayout({
        title: subject,
        preheader: "Your account deletion has been cancelled.",
        eyebrow: "Account",
        heading: "Your account is staying",
        body,
        reason: escapeHtml(REASON),
      }),
      text: [
        name ? `Assalamu alaikum ${name},` : "Assalamu alaikum,",
        "",
        "Your account deletion has been cancelled. Your profile, photos and conversations are just as you left them.",
        `If you did not ask for this, contact us at ${SUPPORT_EMAIL}.`,
        "",
        "The Silarah team",
        "",
        REASON,
      ].join("\n"),
    };
  }

  const subject = "Your Silarah account has been deleted";
  const body = [
    greeting("Assalamu alaikum,"),
    paragraph(
      "Your Silarah account and the personal data in it have now been permanently deleted. We no longer hold your profile, photos, messages, interests or matches, and we will not collect any more data about you.",
    ),
    paragraph(
      `The only things kept are the minimum records the law requires, such as payment and tax records, abuse-prevention records and proof of consent. They are kept only for as long as required, then deleted. Backup copies expire on their normal schedule. See our <a href="${PRIVACY_URL}">Privacy Policy</a>.`,
    ),
    playNote,
    paragraph("Thank you for trusting Silarah. You are always welcome back."),
    button("Help centre", HELP_URL),
    signOff("The Silarah team"),
  ].join("\n");
  return {
    subject,
    html: renderEmailLayout({
      title: subject,
      preheader: "Your account and its data have been permanently deleted.",
      eyebrow: "Account deletion",
      heading: "Your account has been deleted",
      body,
      reason: escapeHtml(
        "You are receiving this one final message to confirm your deletion request was completed. No further emails will be sent.",
      ),
    }),
    text: [
      "Assalamu alaikum,",
      "",
      "Your Silarah account and the personal data in it have now been permanently deleted. We no longer hold your profile, photos, messages, interests or matches, and we will not collect any more data about you.",
      "The only things kept are the minimum records the law requires, such as payment and tax records, abuse-prevention records and proof of consent. They are kept only for as long as required, then deleted. Backup copies expire on their normal schedule.",
      `Privacy Policy: ${PRIVACY_URL}`,
      "",
      `Deleting your account does not cancel a Google Play subscription: ${PLAY_SUBSCRIPTIONS_URL}`,
      "",
      "Thank you for trusting Silarah. You are always welcome back.",
      "The Silarah team",
      "",
      "This is one final message to confirm your deletion request was completed. No further emails will be sent.",
    ].join("\n"),
  };
}

async function complete(
  supabase: SupabaseClient,
  id: string,
  success: boolean,
  error: string | null,
) {
  await supabase.rpc("complete_account_email", {
    p_email_id: id,
    p_success: success,
    p_error: error,
  });
}

if (import.meta.main) {
  Deno.serve(async (req: Request) => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }
    if (!(await isAuthorizedCronRequest(req))) {
      console.warn("[account-email] Unauthorized invocation blocked.");
      return new Response("Unauthorized", { status: 401 });
    }
    if (!BREVO_API_KEY) {
      console.error("[account-email] BREVO_API_KEY is not configured.");
      return new Response("Email provider unavailable", { status: 503 });
    }
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data, error } = await supabase.rpc("claim_account_emails", {
      p_limit: 10,
    });
    if (error) {
      console.error("[account-email] Could not claim emails:", error.message);
      return new Response("Queue unavailable", { status: 503 });
    }
    const rows = (data ?? []) as QueuedAccountEmail[];
    let sent = 0;
    for (const row of rows) {
      if (!row.recipient) {
        await complete(supabase, row.email_id, false, "no_recipient");
        continue;
      }
      try {
        await sendBrevoTransactionalEmail({
          apiKey: BREVO_API_KEY,
          to: row.recipient,
          email: renderAccountEmail(row),
          dedupeKey: `account:${row.email_id}`,
          tags: ["transactional", "account"],
        });
        await complete(supabase, row.email_id, true, null);
        sent += 1;
      } catch (sendError) {
        await complete(
          supabase,
          row.email_id,
          false,
          sendError instanceof Error ? sendError.message : "send_failed",
        );
      }
    }
    return new Response(JSON.stringify({ claimed: rows.length, sent }), {
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
      },
    });
  });
}
