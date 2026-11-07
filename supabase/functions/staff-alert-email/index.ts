// EDGE FUNCTION: staff-alert-email
//
// Emails active staff when an operational alert first fires: a free-plan
// limit reaching 70 % or 85 %, push dispatch failing, email failures and so
// on. The database queues one row per newly fired alert
// (private.set_operational_alert) and wakes this worker through pg_net; an
// hourly cron retries anything left behind. It only runs when an alert fires.
//
// Staff alerts are internal, so the email is deliberately plain and the
// worker stays self-contained instead of pulling in the member email layout.
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { corsHeaders } from "../_shared/cors.ts";
import { isAuthorizedCronRequest } from "../_shared/cron_auth.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY") ?? "";
const ADMIN_URL = "https://admin.silarah.com/system";

interface QueuedAlert {
  id: number;
  alert_key: string;
  message: string;
  created_at: string;
  recipients: string[];
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (!(await isAuthorizedCronRequest(req))) {
    console.warn("[staff-alert-email] Unauthorized invocation blocked.");
    return new Response("Unauthorized", { status: 401 });
  }
  if (!BREVO_API_KEY) {
    console.error("[staff-alert-email] BREVO_API_KEY is not configured.");
    return new Response("Email provider unavailable", { status: 503 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await supabase.rpc("claim_staff_alert_emails", {
    p_limit: 10,
  });
  if (error) {
    console.error("[staff-alert-email] Claim failed:", error.message);
    return new Response("Internal Server Error", { status: 500 });
  }

  const alerts = (data ?? []) as QueuedAlert[];
  let sent = 0;
  for (const alert of alerts) {
    const recipients = (alert.recipients ?? []).filter((email) =>
      /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
    );
    if (recipients.length === 0) {
      await complete(supabase, alert.id, false, "no_active_staff_email");
      continue;
    }
    try {
      await sendAlert(alert, recipients);
      await complete(supabase, alert.id, true, null);
      sent++;
    } catch (sendError) {
      const message = sendError instanceof Error
        ? sendError.message
        : "send_failed";
      console.error("[staff-alert-email] Send failed:", message);
      await complete(supabase, alert.id, false, message);
    }
  }

  return Response.json({ claimed: alerts.length, sent });
});

async function complete(
  supabase: SupabaseClient,
  id: number,
  sentOk: boolean,
  error: string | null,
) {
  const { error: rpcError } = await supabase.rpc("complete_staff_alert_email", {
    p_id: id,
    p_sent: sentOk,
    p_error: error,
  });
  if (rpcError) {
    console.error("[staff-alert-email] Complete failed:", rpcError.message);
  }
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

async function sendAlert(alert: QueuedAlert, recipients: string[]) {
  const isLimit = /_(70|85)$/.test(alert.alert_key);
  const level = alert.alert_key.endsWith("_85") ? "85%" : "70%";
  const subject = isLimit
    ? `Silarah: free-plan limit at ${level}`
    : "Silarah: system alert";
  const when = new Date(alert.created_at).toUTCString();
  const html =
    `<!doctype html><html><body style="margin:0;padding:24px;background:#F7F3EA;font-family:Arial,sans-serif;color:#1E2B26">
<div style="max-width:560px;margin:0 auto;background:#ffffff;border:1px solid #E5DCCB;border-radius:12px;padding:24px">
<p style="margin:0 0 6px;font-size:12px;letter-spacing:1px;text-transform:uppercase;color:#A3402C">Staff alert</p>
<h1 style="margin:0 0 16px;font-size:20px">${escapeHtml(subject)}</h1>
<p style="margin:0 0 16px;font-size:16px;line-height:24px">${
      escapeHtml(alert.message)
    }</p>
<p style="margin:0 0 16px;font-size:13px;color:#6B6458">Raised ${
      escapeHtml(when)
    }.</p>
<p style="margin:0"><a href="${ADMIN_URL}" style="color:#175C45;font-weight:bold">Open System health</a></p>
</div>
<p style="max-width:560px;margin:12px auto 0;font-size:12px;color:#8A8274">You receive this because you are active Silarah staff. One email is sent when an alert first fires.</p>
</body></html>`;
  const text = [
    subject,
    "",
    alert.message,
    "",
    `Raised ${when}.`,
    `System health: ${ADMIN_URL}`,
    "",
    "You receive this because you are active Silarah staff.",
  ].join("\n");

  const response = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    signal: AbortSignal.timeout(10_000),
    headers: {
      accept: "application/json",
      "api-key": BREVO_API_KEY,
      "content-type": "application/json",
      "idempotency-key": `staff-alert-${alert.id}`,
    },
    body: JSON.stringify({
      sender: { name: "Silarah", email: "noreply@mail.silarah.com" },
      to: recipients.map((email) => ({ email })),
      subject,
      htmlContent: html,
      textContent: text,
      tags: ["staff-alert"],
    }),
  });
  if (!response.ok) {
    await response.body?.cancel();
    throw new Error(`Brevo rejected staff alert (${response.status}).`);
  }
  await response.body?.cancel();
}
