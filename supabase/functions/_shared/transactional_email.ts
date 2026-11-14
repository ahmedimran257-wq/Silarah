import {
  BRAND,
  button,
  detailList,
  escapeHtml,
  footerBand,
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
  TERMS_URL,
} from "./email_layout.ts";

export interface SubscriptionEmailInput {
  eventType: string;
  firstName?: string | null;
  productId?: string | null;
  currency?: string | null;
  price?: number | null;
  expiresAt?: string | null;
  store?: string | null;
  transactionId?: string | null;
}

export interface RenderedTransactionalEmail {
  subject: string;
  html: string;
  text: string;
}

interface SubscriptionEmailCopy {
  subject: string;
  preheader: string;
  eyebrow: string;
  heading: string;
  intro: string;
  statusLabel: string;
  statusValue: string;
  benefits?: [string, string][];
  actionLabel: string;
  actionUrl: string;
  note: string;
  tone?: "standard" | "attention";
}

const APP_URL = "https://app.silarah.com/";

const PREMIUM_BENEFITS: [string, string][] = [
  [
    "Full match messaging",
    "Carry every conversation with your matches forward, without waiting.",
  ],
  [
    "All-India discovery and advanced filters",
    "Look beyond your city, with the filters that matter to you and your family.",
  ],
  [
    "Profile viewers and a weekly boost",
    "See who has visited your profile, and be seen by more members each week.",
  ],
];

const SIGN_OFF = ["With every good wish for your search,", "The Silarah team"];

const SERVICE_REASON =
  "This is a service message about your Silarah membership, so it is sent whatever your marketing preferences.";

export function renderSubscriptionEmail(
  input: SubscriptionEmailInput,
): RenderedTransactionalEmail {
  const firstName = cleanFirstName(input.firstName);
  const salutation = firstName
    ? `Assalamu alaikum ${firstName},`
    : "Assalamu alaikum,";
  const plan = planName(input.productId);
  const amount = formatAmount(input.price, input.currency);
  const effectiveDate = formatDate(input.expiresAt);
  const reference = shortReference(input.transactionId);
  const store = storeName(input.store);
  const copy = copyFor(input.eventType, effectiveDate, store);

  const details: [string, string][] = [
    ["Membership", plan],
    ...(amount ? [["Amount", amount] as [string, string]] : []),
    ...(effectiveDate
      ? [[dateLabel(input.eventType), effectiveDate] as [string, string]]
      : []),
    ...(store ? [["Payment provider", store] as [string, string]] : []),
    ...(reference ? [["Reference", reference] as [string, string]] : []),
  ];
  const e = escapeHtml;
  const supportLine =
    `Questions about your membership? Simply reply to this email and it reaches our support team at ${SUPPORT_EMAIL}.`;

  const html = renderEmailLayout({
    title: e(copy.subject),
    preheader: e(copy.preheader),
    eyebrow: e(copy.eyebrow),
    heading: e(copy.heading),
    tone: copy.tone,
    reason: e(SERVICE_REASON),
    body: [
      greeting(e(salutation)),
      paragraph(e(copy.intro)),
      panel(e(copy.statusLabel), e(copy.statusValue), { tone: copy.tone }),
      ...(copy.benefits
        ? [
          steps(
            "What is now open to you",
            copy.benefits.map(([title, text]) => [e(title), e(text)]),
          ),
        ]
        : []),
      detailList(
        "Membership details",
        details.map(([label, value]) => [e(label), e(value)]),
      ),
      button(e(copy.actionLabel), e(copy.actionUrl)),
      note(e(copy.note)),
      signOff(SIGN_OFF.map(e).join("<br>")),
      footerBand(
        `Questions about your membership? Simply reply to this email and it reaches our support team at <a class="link" href="mailto:${SUPPORT_EMAIL}" style="color:${BRAND.emerald};text-decoration:underline;">${SUPPORT_EMAIL}</a>.`,
      ),
    ].join("\n"),
  });

  const text = [
    "SILARAH",
    "Introductions with intention",
    "",
    copy.heading,
    "=".repeat(copy.heading.length),
    "",
    salutation,
    "",
    copy.intro,
    "",
    `${copy.statusLabel}: ${copy.statusValue}`,
    ...(copy.benefits
      ? [
        "",
        "What is now open to you",
        ...copy.benefits.map(([title, text], index) =>
          `${index + 1}. ${title}: ${text}`
        ),
      ]
      : []),
    "",
    "Membership details",
    ...details.map(([label, value]) => `${label}: ${value}`),
    "",
    `${copy.actionLabel}: ${copy.actionUrl}`,
    "",
    copy.note,
    "",
    ...SIGN_OFF,
    "",
    "--",
    supportLine,
    `Help centre: ${HELP_URL}`,
    `Privacy: ${PRIVACY_URL}`,
    `Terms: ${TERMS_URL}`,
    "",
    SERVICE_REASON,
    "",
  ].join("\n");

  return { subject: copy.subject, html, text };
}

export async function sendBrevoTransactionalEmail(args: {
  apiKey: string;
  to: string;
  recipientName?: string | null;
  email: RenderedTransactionalEmail;
  dedupeKey: string;
  tags?: string[];
}): Promise<string | null> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10_000);
  let response: Response;
  try {
    response = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      signal: controller.signal,
      headers: {
        accept: "application/json",
        "api-key": args.apiKey,
        "content-type": "application/json",
        "idempotency-key": args.dedupeKey,
      },
      body: JSON.stringify({
        sender: { name: "Silarah", email: "noreply@mail.silarah.com" },
        replyTo: { name: "Silarah Support", email: "support@silarah.com" },
        to: [{
          email: args.to,
          ...(args.recipientName ? { name: args.recipientName } : {}),
        }],
        subject: args.email.subject,
        htmlContent: args.email.html,
        textContent: args.email.text,
        tags: args.tags ?? ["transactional", "subscription"],
        headers: { "X-Silarah-Dedupe-Key": args.dedupeKey },
      }),
    });
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    throw new Error(`Brevo rejected transactional email (${response.status}).`);
  }

  const responseText = await readResponseTextLimited(response, 64 * 1024);
  const payload = (() => {
    try {
      return JSON.parse(responseText) as { messageId?: string };
    } catch {
      return {};
    }
  })();
  return payload.messageId ?? null;
}

async function readResponseTextLimited(
  response: Response,
  maxBytes: number,
): Promise<string> {
  if (!response.body) return "";
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let bytesRead = 0;
  let result = "";
  while (bytesRead < maxBytes) {
    const { value, done } = await reader.read();
    if (done || !value) break;
    const remaining = Math.min(value.byteLength, maxBytes - bytesRead);
    result += decoder.decode(value.slice(0, remaining), { stream: true });
    bytesRead += remaining;
  }
  await reader.cancel().catch(() => undefined);
  return result;
}

function copyFor(
  eventType: string,
  effectiveDate: string | null,
  store: string | null,
): SubscriptionEmailCopy {
  const manageUrl = store === "Apple App Store"
    ? "https://apps.apple.com/account/subscriptions"
    : store === "Google Play"
    ? "https://play.google.com/store/account/subscriptions"
    : APP_URL;
  const provider = store ?? "your payment provider";
  const Provider = store ?? "Your payment provider";

  switch (eventType) {
    case "INITIAL_PURCHASE":
      return {
        subject: "Your Silarah Premium membership is active",
        preheader:
          "Thank you for choosing Premium. Full messaging, all-India discovery and profile viewers are open to you now.",
        eyebrow: "Membership confirmed",
        heading: "Welcome to Silarah Premium",
        intro:
          "Thank you for choosing Premium. It is active on your account now, so the next conversation can begin whenever you are ready.",
        statusLabel: "Membership status",
        statusValue: "Active",
        benefits: PREMIUM_BENEFITS,
        actionLabel: "Open Silarah",
        actionUrl: APP_URL,
        note:
          `${Provider} sends your official receipt separately. Silarah never sees your card or bank details.`,
      };
    case "RENEWAL":
      return {
        subject: "Your Silarah Premium membership renewed",
        preheader:
          "Your Premium membership renewed as planned. Your conversations and filters carry on without a break.",
        eyebrow: "Renewal confirmed",
        heading: "Your Premium continues",
        intro:
          "Your membership renewed as planned, so your conversations, filters and weekly boost carry on without a break.",
        statusLabel: "Membership status",
        statusValue: "Renewed and active",
        actionLabel: "Open Silarah",
        actionUrl: APP_URL,
        note:
          `${Provider} sends the official renewal receipt. You can change or stop future renewals at any time from your subscriptions in ${provider}.`,
      };
    case "PRODUCT_CHANGE":
      return {
        subject: "Your Silarah Premium plan was updated",
        preheader:
          "We have recorded your plan change. Here is what your membership looks like now.",
        eyebrow: "Plan updated",
        heading: "Your plan has been updated",
        intro:
          `We have recorded your plan change. The details below are exactly what ${provider} reported to us.`,
        statusLabel: "Membership status",
        statusValue: "Plan updated",
        actionLabel: "Review your membership",
        actionUrl: APP_URL,
        note:
          `Any proration or credit for the change is calculated and shown by ${provider}.`,
      };
    case "CANCELLATION":
      return {
        subject: "Your Silarah renewal has been cancelled",
        preheader: effectiveDate
          ? `Nothing changes today. Premium stays open to you until ${effectiveDate}.`
          : "Nothing changes today. Premium stays open to you until the end of your paid period.",
        eyebrow: "Renewal cancelled",
        heading: "Your renewal is cancelled",
        intro: effectiveDate
          ? `Nothing changes today. Premium stays fully open to you until ${effectiveDate}, and it will not renew after that.`
          : "Nothing changes today. Premium stays fully open to you until the end of the period you have already paid for, and it will not renew after that.",
        statusLabel: "Premium access until",
        statusValue: effectiveDate ?? "End of your current period",
        actionLabel: "Manage subscription",
        actionUrl: manageUrl,
        note:
          `Changed your mind? You can resume from ${provider} before the current period ends. Your profile, matches and conversations stay with you either way.`,
      };
    case "EXPIRATION":
      return {
        subject: "Your Silarah Premium membership has ended",
        preheader:
          "Your Premium period has ended. Your profile, matches and conversations are all still here.",
        eyebrow: "Membership ended",
        heading: "Your Premium period has ended",
        intro:
          "Thank you for the time you spent with Premium. Your profile, matches and conversations are all still here, now on the free membership.",
        statusLabel: "Membership status",
        statusValue: "Free membership",
        actionLabel: "See membership options",
        actionUrl: APP_URL,
        note:
          "You can return to Premium whenever it suits you, from the app. Nothing you have built is lost.",
      };
    case "REFUND":
      return {
        subject: "Your Silarah membership refund update",
        preheader:
          `${Provider} has confirmed your refund, and your Silarah account has been updated to match.`,
        eyebrow: "Refund confirmed",
        heading: "Your refund is confirmed",
        intro:
          `${Provider} has told us your payment was refunded, and we have updated your account to match. Your profile and conversations remain, on the free membership.`,
        statusLabel: "Membership status",
        statusValue: "Refunded",
        actionLabel: "Visit the help centre",
        actionUrl: HELP_URL,
        note:
          `When the money reaches you is decided by ${provider} and your bank, not by Silarah.`,
      };
    case "BILLING_ISSUE":
      return {
        subject: "Your Silarah Premium payment needs attention",
        preheader:
          `${Provider} could not take your latest Premium payment. A quick check of your payment method keeps Premium uninterrupted.`,
        eyebrow: "Action needed",
        heading: "We could not renew your Premium",
        intro:
          `${Provider} was unable to take the latest payment for your membership. Please check your payment method so Premium continues without interruption.`,
        statusLabel: "Membership status",
        statusValue: "Payment needs attention",
        actionLabel: "Update payment method",
        actionUrl: manageUrl,
        note:
          "Silarah never receives or stores your card or bank details, and we will never ask for them by email.",
        tone: "attention",
      };
    default:
      throw new Error(`Unsupported subscription email event: ${eventType}`);
  }
}

function dateLabel(eventType: string): string {
  return eventType === "CANCELLATION"
    ? "Access until"
    : eventType === "INITIAL_PURCHASE" || eventType === "RENEWAL"
    ? "Renews on"
    : "Effective date";
}

function planName(productId?: string | null): string {
  const product = productId?.toLowerCase() ?? "";
  // Play sends `subscriptionId:basePlanId`; match on the subscription ID.
  switch (product.split(":")[0]) {
    case "silarah_monthly":
      return "Silarah Premium Monthly";
    case "silarah_three_month":
      return "Silarah Premium 3 Months";
  }
  if (product.includes("annual") || product.includes("year")) {
    return "Silarah Premium Annual";
  }
  return "Silarah Premium";
}

function formatAmount(
  price?: number | null,
  currency?: string | null,
): string | null {
  // Cancellation, expiry and billing-issue events carry no charge.
  if (price == null || !Number.isFinite(price) || price === 0 || !currency) {
    return null;
  }
  try {
    return new Intl.NumberFormat("en", {
      style: "currency",
      currency: currency.toUpperCase(),
      maximumFractionDigits: 2,
    }).format(price);
  } catch (_) {
    return `${currency.toUpperCase()} ${price.toFixed(2)}`;
  }
}

function formatDate(value?: string | null): string | null {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(date);
}

function storeName(store?: string | null): string | null {
  switch (store?.toUpperCase()) {
    case "PLAY_STORE":
    case "GOOGLE_PLAY":
      return "Google Play";
    case "APP_STORE":
    case "MAC_APP_STORE":
      return "Apple App Store";
    case "STRIPE":
      return "Stripe";
    case "TEST_STORE":
      return "RevenueCat Test Store";
    default:
      return store?.trim() || null;
  }
}

function shortReference(value?: string | null): string | null {
  const reference = value?.trim();
  if (!reference) return null;
  // Google Play order IDs (GPA.xxxx-xxxx-xxxx-xxxxx) stay whole: the refund
  // policy asks members to quote them to support.
  if (reference.length <= 32) return reference;
  return `${reference.slice(0, 8)}...${reference.slice(-6)}`;
}

function cleanFirstName(value?: string | null): string | null {
  const cleaned = value?.trim().replace(/\s+/g, " ");
  if (!cleaned) return null;
  return cleaned.slice(0, 60);
}
