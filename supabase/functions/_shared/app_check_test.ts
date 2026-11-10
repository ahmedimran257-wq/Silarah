import { assertEquals } from "@std/assert";
import { verifyAppCheckToken } from "./app_check.ts";

const PROJECT = "163379661830";
const APP = "1:163379661830:android:062cb833b274c89dedc787";

const algorithm = {
  name: "RSASSA-PKCS1-v1_5",
  modulusLength: 2048,
  publicExponent: new Uint8Array([1, 0, 1]),
  hash: "SHA-256",
};

const pair = await crypto.subtle.generateKey(algorithm, true, [
  "sign",
  "verify",
]);
const other = await crypto.subtle.generateKey(algorithm, true, [
  "sign",
  "verify",
]);
const jwk = {
  ...await crypto.subtle.exportKey("jwk", pair.publicKey),
  kid: "key-1",
};
const loadKeys = () => Promise.resolve([jwk]);

function segment(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-")
    .replaceAll("/", "_").replaceAll("=", "");
}
const encode = (value: unknown) =>
  segment(new TextEncoder().encode(JSON.stringify(value)));

async function token(
  claims: Record<string, unknown> = {},
  header: Record<string, unknown> = {},
  signer: CryptoKey = pair.privateKey,
): Promise<string> {
  const body = `${encode({ alg: "RS256", kid: "key-1", ...header })}.${
    encode({
      iss: `https://firebaseappcheck.googleapis.com/${PROJECT}`,
      sub: APP,
      aud: [`projects/${PROJECT}`],
      exp: Math.floor(Date.now() / 1000) + 600,
      ...claims,
    })
  }`;
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    signer,
    new TextEncoder().encode(body),
  );
  return `${body}.${segment(new Uint8Array(signature))}`;
}

Deno.test("accepts a genuine token", async () => {
  assertEquals(await verifyAppCheckToken(await token(), loadKeys), true);
});

Deno.test("rejects missing or malformed tokens", async () => {
  assertEquals(await verifyAppCheckToken(null, loadKeys), false);
  assertEquals(await verifyAppCheckToken("", loadKeys), false);
  assertEquals(await verifyAppCheckToken("a.b.c", loadKeys), false);
});

Deno.test("rejects a token signed by another key", async () => {
  const forged = await token({}, {}, other.privateKey);
  assertEquals(await verifyAppCheckToken(forged, loadKeys), false);
});

Deno.test("rejects expired tokens and other apps or projects", async () => {
  for (
    const claims of [
      { exp: Math.floor(Date.now() / 1000) - 1 },
      { sub: "1:163379661830:android:someoneelse" },
      { aud: ["projects/1"] },
      { iss: "https://example.com/" + PROJECT },
    ]
  ) {
    assertEquals(
      await verifyAppCheckToken(await token(claims), loadKeys),
      false,
    );
  }
});

Deno.test("rejects other algorithms and unknown keys", async () => {
  assertEquals(
    await verifyAppCheckToken(await token({}, { alg: "none" }), loadKeys),
    false,
  );
  assertEquals(
    await verifyAppCheckToken(await token({}, { kid: "nope" }), loadKeys),
    false,
  );
});

Deno.test("treats a key outage as not verified", async () => {
  const outage = () => Promise.reject(new Error("offline"));
  assertEquals(await verifyAppCheckToken(await token(), outage), false);
});
