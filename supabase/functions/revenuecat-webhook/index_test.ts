// Drives the real webhook handler with synthetic RevenueCat deliveries and a
// fake Supabase/Brevo backend. Nothing is deployed and no provider is
// contacted; every value below is a fixture.
import { assert, assertEquals } from "@std/assert";

const SECRET = "fixture-only-revenuecat-secret-of-40-chars";
const MEMBER = "6f1c2d3e-4b5a-4c6d-8e7f-9a0b1c2d3e4f";
const SUPABASE = "https://billing-webhook.example.invalid";
const ENV: Record<string, string> = {
  SUPABASE_URL: SUPABASE,
  SUPABASE_SERVICE_ROLE_KEY: "fixture-only-service-key",
  REVENUECAT_WEBHOOK_SECRET: SECRET,
  BREVO_API_KEY: "fixture-only-brevo-key",
  REVENUECAT_EXPECTED_APP_ID: "app_fixture",
  REVENUECAT_EXPECTED_ENVIRONMENT: "PRODUCTION",
  REVENUECAT_EXPECTED_ENTITLEMENT_ID: "premium",
  REVENUECAT_ALLOWED_PRODUCT_IDS: "silarah_monthly,silarah_three_month",
  REVENUECAT_ALLOWED_STORES: "PLAY_STORE",
};

type Handler = (req: Request) => Promise<Response>;

// The module reads its configuration once at load, then calls Deno.serve.
async function loadHandler(): Promise<Handler> {
  const saved = Object.keys(ENV).map((name) => [name, Deno.env.get(name)]);
  const savedTesters = Deno.env.get("REVENUECAT_SANDBOX_TESTER_IDS");
  const serve = Object.getOwnPropertyDescriptor(Deno, "serve")!;
  let handler: Handler | undefined;
  try {
    for (const [name, value] of Object.entries(ENV)) Deno.env.set(name, value);
    Deno.env.delete("REVENUECAT_SANDBOX_TESTER_IDS");
    Object.defineProperty(Deno, "serve", {
      configurable: true,
      value: (h: Handler) => {
        handler = h;
        return {};
      },
    });
    await import("./index.ts");
  } finally {
    Object.defineProperty(Deno, "serve", serve);
    for (const [name, value] of saved) {
      if (value == null) Deno.env.delete(name!);
      else Deno.env.set(name!, value);
    }
    if (savedTesters != null) {
      Deno.env.set("REVENUECAT_SANDBOX_TESTER_IDS", savedTesters);
    }
  }
  assert(handler, "the webhook registered a handler");
  return handler;
}

const handler = await loadHandler();

interface Backend {
  applyResult: Record<string, unknown> | null;
  applyError: boolean;
  claimRows: unknown[];
  brevoStatus: number;
  rpcCalls: { fn: string; body: Record<string, unknown> }[];
  brevoCalls: number;
  outboxUpdates: Record<string, unknown>[];
}

function backend(overrides: Partial<Backend> = {}): Backend {
  return {
    applyResult: { applied: true, reason: "applied", email_dedupe_key: "k" },
    applyError: false,
    claimRows: [],
    brevoStatus: 201,
    rpcCalls: [],
    brevoCalls: 0,
    outboxUpdates: [],
    ...overrides,
  };
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

async function deliver(
  db: Backend,
  body: unknown,
  authorization: string | null = `Bearer ${SECRET}`,
): Promise<Response> {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input, init) => {
    const request = new Request(input, init);
    const url = new URL(request.url);
    if (url.origin === "https://api.brevo.com") {
      db.brevoCalls++;
      return json({ messageId: "fixture-message" }, db.brevoStatus);
    }
    assertEquals(url.origin, SUPABASE, "only the fake backend is contacted");
    const rpc = url.pathname.match(/^\/rest\/v1\/rpc\/(.+)$/)?.[1];
    if (rpc) {
      const args = await request.json();
      db.rpcCalls.push({ fn: rpc, body: args });
      if (rpc === "apply_revenuecat_subscription_event") {
        return db.applyError
          ? json({ message: "fixture failure", code: "XX000" }, 500)
          : json(db.applyResult);
      }
      if (rpc === "claim_transactional_email") return json(db.claimRows);
      return json(null);
    }
    if (url.pathname === "/rest/v1/users") {
      return json({ email: "member@example.invalid" });
    }
    if (url.pathname === "/rest/v1/profiles") {
      return json({ first_name: "Fixture" });
    }
    if (url.pathname === "/rest/v1/transactional_email_outbox") {
      db.outboxUpdates.push(await request.json());
      return json([]);
    }
    throw new Error(`unexpected request ${request.method} ${url.pathname}`);
  };
  try {
    const headers: Record<string, string> = {
      "content-type": "application/json",
    };
    if (authorization != null) headers.authorization = authorization;
    return await handler(
      new Request("https://edge.example.invalid/revenuecat-webhook", {
        method: "POST",
        headers,
        body: typeof body === "string" ? body : JSON.stringify(body),
      }),
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
}

const DAY = 24 * 60 * 60 * 1000;
let sequence = 0;

function event(overrides: Record<string, unknown> = {}) {
  const now = Date.now();
  return {
    event: {
      id: `fixture-event-${++sequence}`,
      type: "INITIAL_PURCHASE",
      app_user_id: MEMBER,
      original_app_user_id: MEMBER,
      event_timestamp_ms: now - 1000,
      expiration_at_ms: now + 30 * DAY,
      product_id: "silarah_monthly:monthly",
      app_id: "app_fixture",
      environment: "PRODUCTION",
      entitlement_ids: ["premium"],
      store: "PLAY_STORE",
      currency: "INR",
      price: 299,
      ...overrides,
    },
  };
}

const applyCall = (db: Backend) =>
  db.rpcCalls.find((call) => call.fn === "apply_revenuecat_subscription_event")
    ?.body;
const notified = (db: Backend) =>
  db.rpcCalls.some((call) => call.fn === "queue_notification");

Deno.test("only RevenueCat's exact secret is accepted", async () => {
  for (
    const authorization of [
      null,
      "",
      SECRET,
      `bearer ${SECRET}`,
      `Bearer ${SECRET.slice(0, -1)}`,
      `Bearer ${SECRET}x`,
      "Bearer ",
    ]
  ) {
    const db = backend();
    const response = await deliver(db, event(), authorization);
    assertEquals(
      response.status,
      401,
      `rejects ${JSON.stringify(authorization)}`,
    );
    assertEquals(db.rpcCalls.length, 0);
  }
});

Deno.test("a forged transfer or test event without the secret is refused", async () => {
  for (const type of ["TRANSFER", "TEST"]) {
    const db = backend();
    const response = await deliver(db, { event: { type } }, null);
    assertEquals(response.status, 401);
    assertEquals(db.rpcCalls.length, 0);
  }
});

Deno.test("authenticated transfer and test events are acknowledged without change", async () => {
  for (const type of ["TRANSFER", "TEST"]) {
    const db = backend();
    const response = await deliver(db, { event: { type } });
    assertEquals(response.status, 200);
    assertEquals(db.rpcCalls.length, 0);
  }
});

Deno.test("malformed deliveries are rejected before any database work", async () => {
  for (
    const body of [
      "not json",
      {},
      { event: { type: "RENEWAL" } },
      event({ id: "short" }),
      event({ event_timestamp_ms: Date.now() + 10 * 60 * 1000 }),
      event({ event_timestamp_ms: "yesterday" }),
      event({ expiration_at_ms: "soon" }),
      event({ price: "free" }),
    ]
  ) {
    const db = backend();
    const response = await deliver(db, body);
    assertEquals(response.status, 400, `rejects ${JSON.stringify(body)}`);
    assertEquals(db.rpcCalls.length, 0);
  }
});

Deno.test("events from outside the production app grant nothing", async () => {
  const cases: Record<string, Record<string, unknown>> = {
    "another app": { app_id: "app_other" },
    "a sandbox purchase": { environment: "SANDBOX" },
    "no Premium entitlement": { entitlement_ids: ["other"] },
    "missing entitlements": { entitlement_ids: undefined },
    "an unlisted product": { product_id: "silarah_lifetime" },
    "a lookalike product": { product_id: "silarah_monthly_x:monthly" },
    "another store": { store: "APP_STORE" },
    "a foreign original identity": {
      original_app_user_id: "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d",
      aliases: [],
    },
  };
  for (const [label, overrides] of Object.entries(cases)) {
    const db = backend();
    const response = await deliver(db, event(overrides));
    assertEquals(response.status, 400, label);
    assertEquals(db.rpcCalls.length, 0, label);
  }
});

Deno.test("an aliased original identity and a base-plan product are accepted", async () => {
  const db = backend();
  const response = await deliver(
    db,
    event({
      original_app_user_id: "$RCAnonymousID:fixture",
      aliases: ["$RCAnonymousID:fixture", MEMBER],
      product_id: "silarah_three_month:three-month",
    }),
  );
  assertEquals(response.status, 200);
  assertEquals(applyCall(db)?.p_product_id, "silarah_three_month:three-month");
});

Deno.test("an anonymous store identity is ignored, never applied", async () => {
  const db = backend();
  const response = await deliver(
    db,
    event({
      app_user_id: "$RCAnonymousID:fixture",
      original_app_user_id: "$RCAnonymousID:fixture",
    }),
  );
  assertEquals(response.status, 200);
  assertEquals(db.rpcCalls.length, 0);
});

Deno.test("a purchase is applied once with its store expiry, notified and emailed", async () => {
  const db = backend({ claimRows: [{ id: "outbox-1" }] });
  const delivery = event();
  const response = await deliver(db, delivery);
  assertEquals(response.status, 200);
  const apply = applyCall(db)!;
  assertEquals(apply.p_user_id, MEMBER);
  assertEquals(apply.p_provider_event_id, delivery.event.id);
  assertEquals(apply.p_event_type, "INITIAL_PURCHASE");
  assertEquals(apply.p_subscription_status, "active");
  assertEquals(
    apply.p_subscription_expires_at,
    new Date(delivery.event.expiration_at_ms).toISOString(),
  );
  assert(notified(db));
  assertEquals(db.brevoCalls, 1);
  assertEquals(db.outboxUpdates.at(-1)?.status, "sent");
});

Deno.test("a database failure returns 500 so RevenueCat retries", async () => {
  const db = backend({ applyError: true });
  const response = await deliver(db, event());
  assertEquals(response.status, 500);
  assert(!notified(db));
});

Deno.test("a duplicate delivery changes nothing and sends nothing twice", async () => {
  const db = backend({
    applyResult: {
      applied: false,
      reason: "duplicate_event",
      email_dedupe_key: "k",
    },
  });
  const response = await deliver(db, event());
  assertEquals(response.status, 200);
  assert(!notified(db));
  assertEquals(db.brevoCalls, 0);
});

Deno.test("an email that cannot be sent is retried, not lost", async () => {
  const db = backend({ claimRows: [{ id: "outbox-1" }], brevoStatus: 500 });
  const response = await deliver(db, event());
  assertEquals(response.status, 500);
  assertEquals(db.outboxUpdates.at(-1)?.status, "failed");
});

Deno.test("a store refund is recorded as a refund", async () => {
  const now = Date.now();
  const db = backend();
  await deliver(
    db,
    event({
      type: "CANCELLATION",
      cancel_reason: "CUSTOMER_SUPPORT",
      expiration_at_ms: now - 1000,
      price: -299,
    }),
  );
  const apply = applyCall(db)!;
  assertEquals(apply.p_event_type, "REFUND");
  assertEquals(apply.p_subscription_status, "none");
});

Deno.test("a billing-error cancellation defers to the billing issue", async () => {
  const db = backend();
  const response = await deliver(
    db,
    event({ type: "CANCELLATION", cancel_reason: "BILLING_ERROR" }),
  );
  assertEquals(response.status, 200);
  assertEquals(db.rpcCalls.length, 0);
});

Deno.test("a billing issue keeps access only until the grace expiry", async () => {
  const grace = Date.now() + 7 * DAY;
  const db = backend();
  await deliver(
    db,
    event({ type: "BILLING_ISSUE", grace_period_expiration_at_ms: grace }),
  );
  const apply = applyCall(db)!;
  assertEquals(apply.p_subscription_status, "grace");
  assertEquals(apply.p_subscription_expires_at, new Date(grace).toISOString());

  const missing = backend();
  const response = await deliver(
    missing,
    event({ type: "BILLING_ISSUE", expiration_at_ms: undefined }),
  );
  assertEquals(response.status, 400);
  assertEquals(missing.rpcCalls.length, 0);
});

Deno.test("access is never granted without an expiry", async () => {
  const db = backend();
  const response = await deliver(
    db,
    event({ type: "RENEWAL", expiration_at_ms: undefined }),
  );
  assertEquals(response.status, 400);
  assertEquals(db.rpcCalls.length, 0);
});

Deno.test("one plan ending while the other continues sends no ended notice", async () => {
  const db = backend({
    applyResult: {
      applied: true,
      reason: "applied",
      email_dedupe_key: "k",
      access_kept: true,
    },
  });
  const response = await deliver(
    db,
    event({ type: "EXPIRATION", expiration_at_ms: Date.now() - 1000 }),
  );
  assertEquals(response.status, 200);
  assertEquals(applyCall(db)?.p_subscription_status, "none");
  assert(!notified(db));
});

Deno.test("unhandled event types change nothing", async () => {
  const db = backend();
  const response = await deliver(
    db,
    event({ type: "NON_RENEWING_PURCHASE" }),
  );
  assertEquals(response.status, 200);
  assertEquals(db.rpcCalls.length, 0);
});
