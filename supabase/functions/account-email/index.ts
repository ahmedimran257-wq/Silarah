// EDGE FUNCTION: account-email
//
// Tells members, by email, that their account deletion was requested,
// cancelled or completed. The database queues one row per event
// (private.account_emails) and wakes this worker through pg_net; an hourly
// cron retries anything left behind. The completion notice is released only
// after the member's data is gone, and its address is erased once sent.
//
// Since migration 340 it also confirms privacy-rights requests (received,
// with the reference and the response date; answered) from their own queue,
// private.privacy_request_emails, claimed separately so an older deployment
// of this worker never sees them.
//
// Since migration 342 it also sends staff access emails (an invite to the
// admin panel, or a password-reset link) from private.staff_access_emails.
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { corsHeaders } from "../_shared/cors.ts";
import { isAuthorizedCronRequest } from "../_shared/cron_auth.ts";
import {
  button,
  detailList,
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

export interface QueuedPrivacyEmail {
  email_id: string;
  email_event: "received" | "resolved";
  recipient: string | null;
  first_name: string | null;
  request_id: string;
  request_kind: string;
  due_at: string;
}

const PRIVACY_KINDS: Record<string, string> = {
  access: "Access to your data",
  correction: "Correction of your data",
  erasure: "Erasure of your data",
  withdrawal: "Withdrawal of consent",
  nomination: "Nomination",
  grievance: "Grievance",
};

const PRIVACY_REASON =
  "You are receiving this because you made a privacy request in Silarah. It is a service message, not marketing.";

function longDate(value: string): string {
  return new Intl.DateTimeFormat("en-IN", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "Asia/Kolkata",
  }).format(new Date(value));
}

export function renderPrivacyEmail(
  row: QueuedPrivacyEmail,
): RenderedTransactionalEmail {
  const name = row.first_name?.trim();
  const helloText = name ? `Assalamu alaikum ${name},` : "Assalamu alaikum,";
  const hello = greeting(
    name ? `Assalamu alaikum ${escapeHtml(name)},` : "Assalamu alaikum,",
  );
  const kind = PRIVACY_KINDS[row.request_kind] ?? "Privacy request";
  const where = "Silarah > Settings > Privacy requests";

  if (row.email_event === "received") {
    const due = longDate(row.due_at);
    const subject = "We received your privacy request";
    const body = [
      hello,
      paragraph(
        `Thank you. Your request is with our team and we will respond by <strong>${
          escapeHtml(due)
        }</strong>.`,
      ),
      detailList("Your request", [
        ["Type", escapeHtml(kind)],
        ["Reference", escapeHtml(row.request_id)],
        ["Response by", escapeHtml(due)],
      ]),
      paragraph(
        `You can follow it in ${escapeHtml(where)}. Keep the reference if you write to us at <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a>.`,
      ),
      signOff("The Silarah team"),
    ].join("\n");
    return {
      subject,
      html: renderEmailLayout({
        title: subject,
        preheader: `We will respond by ${due}. Reference ${row.request_id}.`,
        eyebrow: "Privacy request",
        heading: "Your request is in",
        body,
        reason: escapeHtml(PRIVACY_REASON),
      }),
      text: [
        helloText,
        "",
        `Thank you. Your request is with our team and we will respond by ${due}.`,
        "",
        `Type: ${kind}`,
        `Reference: ${row.request_id}`,
        `Response by: ${due}`,
        "",
        `You can follow it in ${where}. Keep the reference if you write to us at ${SUPPORT_EMAIL}.`,
        "",
        "The Silarah team",
        "",
        PRIVACY_REASON,
      ].join("\n"),
    };
  }

  const subject = "We have answered your privacy request";
  const body = [
    hello,
    paragraph(
      `We have answered your request (${escapeHtml(kind.toLowerCase())}). Open ${
        escapeHtml(where)
      } to read our response.`,
    ),
    detailList("Your request", [["Reference", escapeHtml(row.request_id)]]),
    paragraph(
      `If anything is unclear, reply to us at <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> with the reference.`,
    ),
    signOff("The Silarah team"),
  ].join("\n");
  return {
    subject,
    html: renderEmailLayout({
      title: subject,
      preheader: "Open the app to read our response.",
      eyebrow: "Privacy request",
      heading: "Your request has an answer",
      body,
      reason: escapeHtml(PRIVACY_REASON),
    }),
    text: [
      helloText,
      "",
      `We have answered your request (${kind.toLowerCase()}). Open ${where} to read our response.`,
      `Reference: ${row.request_id}`,
      "",
      `If anything is unclear, reply to us at ${SUPPORT_EMAIL} with the reference.`,
      "",
      "The Silarah team",
      "",
      PRIVACY_REASON,
    ].join("\n"),
  };
}

export interface QueuedStaffAccessEmail {
  email_id: string;
  email_kind: "invite" | "reset";
  recipient: string | null;
  first_name: string | null;
  staff_role: string | null;
  link: string;
  expires_at: string;
  is_member: boolean;
}

const STAFF_ROLES: Record<string, string> = {
  super_admin: "Super admin",
  moderator: "Moderator",
  support: "Support",
};

const STAFF_REASON =
  "You are receiving this because a Silarah super admin gave this address staff access, or someone asked to reset its staff password. If that was not you, ignore this email: nothing changes unless the link is used.";

function linkExpiry(value: string): string {
  return new Intl.DateTimeFormat("en-IN", {
    day: "numeric",
    month: "long",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Asia/Kolkata",
  }).format(new Date(value)) + " IST";
}

export function renderStaffAccessEmail(
  row: QueuedStaffAccessEmail,
): RenderedTransactionalEmail {
  const name = row.first_name?.trim();
  const helloText = name ? `Assalamu alaikum ${name},` : "Assalamu alaikum,";
  const hello = greeting(
    name ? `Assalamu alaikum ${escapeHtml(name)},` : "Assalamu alaikum,",
  );
  const until = linkExpiry(row.expires_at);
  const role = STAFF_ROLES[row.staff_role ?? ""] ?? "Staff";
  const memberNote = row.is_member
    ? "This address already has a Silarah account. You sign in to the staff panel with it; the password you choose also becomes your Silarah app password."
    : "";

  if (row.email_kind === "invite") {
    const subject = "You are invited to Silarah Operations";
    const body = [
      hello,
      paragraph(
        `You have been given <strong>${escapeHtml(role)}</strong> access to Silarah Operations, the staff panel at admin.silarah.com.`,
      ),
      steps("How to start", [
        ["Open the link", "Press Continue on the page it opens."],
        ["Choose a password", "At least 12 characters, with letters and a number."],
        ["Add an authenticator", "Scan the code with Google Authenticator or a similar app. Every sign-in asks for it."],
      ]),
      button("Set up my access", row.link),
      memberNote ? note(escapeHtml(memberNote)) : "",
      paragraph(`The link works once, until ${escapeHtml(until)}. If it expires, ask a super admin to resend the invite.`),
      signOff("The Silarah team"),
    ].join("\n");
    return {
      subject,
      html: renderEmailLayout({
        title: subject,
        preheader: `${role} access to the Silarah staff panel. The link works until ${until}.`,
        eyebrow: "Staff access",
        heading: "Your staff access is ready",
        body,
        reason: escapeHtml(STAFF_REASON),
      }),
      text: [
        helloText,
        "",
        `You have been given ${role} access to Silarah Operations, the staff panel at admin.silarah.com.`,
        "",
        "1. Open the link and press Continue.",
        "2. Choose a password (at least 12 characters, with letters and a number).",
        "3. Add an authenticator app; every sign-in asks for it.",
        "",
        `Set up my access: ${row.link}`,
        "",
        memberNote,
        `The link works once, until ${until}. If it expires, ask a super admin to resend the invite.`,
        "",
        "The Silarah team",
        "",
        STAFF_REASON,
      ].filter((line, index, all) => line !== "" || all[index - 1] !== "").join("\n"),
    };
  }

  const subject = "Reset your Silarah staff password";
  const body = [
    hello,
    paragraph("Use this link to choose a new password for the Silarah staff panel."),
    button("Choose a new password", row.link),
    paragraph(`It works once, until ${escapeHtml(until)}. You still confirm with your authenticator afterwards.`),
    memberNote ? note(escapeHtml(memberNote)) : "",
    paragraph("If you did not ask for this, ignore this email. Your password stays the same."),
    signOff("The Silarah team"),
  ].join("\n");
  return {
    subject,
    html: renderEmailLayout({
      title: subject,
      preheader: `The link works once, until ${until}.`,
      eyebrow: "Staff access",
      heading: "Choose a new password",
      body,
      reason: escapeHtml(STAFF_REASON),
      tone: "attention",
    }),
    text: [
      helloText,
      "",
      "Use this link to choose a new password for the Silarah staff panel.",
      `Choose a new password: ${row.link}`,
      "",
      `It works once, until ${until}. You still confirm with your authenticator afterwards.`,
      memberNote,
      "If you did not ask for this, ignore this email. Your password stays the same.",
      "",
      "The Silarah team",
      "",
      STAFF_REASON,
    ].filter((line, index, all) => line !== "" || all[index - 1] !== "").join("\n"),
  };
}

async function sendStaffAccessEmails(supabase: SupabaseClient): Promise<{ claimed: number; sent: number }> {
  const { data, error } = await supabase.rpc("claim_staff_access_emails", { p_limit: 10 });
  if (error) {
    // Before migration 342 the RPC does not exist.
    console.error("[account-email] Could not claim staff emails:", error.message);
    return { claimed: 0, sent: 0 };
  }
  const rows = (data ?? []) as QueuedStaffAccessEmail[];
  let sent = 0;
  for (const row of rows) {
    const done = (success: boolean, message: string | null) =>
      supabase.rpc("complete_staff_access_email", {
        p_email_id: row.email_id,
        p_success: success,
        p_error: message,
      });
    if (!row.recipient || !row.link) {
      await done(false, "no_recipient");
      continue;
    }
    try {
      await sendBrevoTransactionalEmail({
        apiKey: BREVO_API_KEY,
        to: row.recipient,
        email: renderStaffAccessEmail(row),
        dedupeKey: `staff:${row.email_id}`,
        tags: ["transactional", "staff"],
      });
      await done(true, null);
      sent += 1;
    } catch (sendError) {
      await done(false, sendError instanceof Error ? sendError.message : "send_failed");
    }
  }
  return { claimed: rows.length, sent };
}

async function sendPrivacyEmails(supabase: SupabaseClient): Promise<{ claimed: number; sent: number }> {
  const { data, error } = await supabase.rpc("claim_privacy_request_emails", {
    p_limit: 10,
  });
  if (error) {
    // Before migration 340 the RPC does not exist; account emails still go out.
    console.error("[account-email] Could not claim privacy emails:", error.message);
    return { claimed: 0, sent: 0 };
  }
  const rows = (data ?? []) as QueuedPrivacyEmail[];
  let sent = 0;
  for (const row of rows) {
    const done = (success: boolean, message: string | null) =>
      supabase.rpc("complete_privacy_request_email", {
        p_email_id: row.email_id,
        p_success: success,
        p_error: message,
      });
    if (!row.recipient) {
      await done(false, "no_recipient");
      continue;
    }
    try {
      await sendBrevoTransactionalEmail({
        apiKey: BREVO_API_KEY,
        to: row.recipient,
        email: renderPrivacyEmail(row),
        dedupeKey: `privacy:${row.email_id}`,
        tags: ["transactional", "privacy"],
      });
      await done(true, null);
      sent += 1;
    } catch (sendError) {
      await done(false, sendError instanceof Error ? sendError.message : "send_failed");
    }
  }
  return { claimed: rows.length, sent };
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
    const privacy = await sendPrivacyEmails(supabase);
    const staff = await sendStaffAccessEmails(supabase);
    return new Response(JSON.stringify({ claimed: rows.length, sent, privacy, staff }), {
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
      },
    });
  });
}
