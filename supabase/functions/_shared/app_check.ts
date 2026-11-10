// Verifies Firebase App Check tokens, which prove a request came from the
// genuine Silarah app on a device Play Integrity accepts.

const PROJECT_NUMBER = "163379661830";
const ANDROID_APP_ID = "1:163379661830:android:062cb833b274c89dedc787";
const ISSUER = `https://firebaseappcheck.googleapis.com/${PROJECT_NUMBER}`;
const JWKS_URL = "https://firebaseappcheck.googleapis.com/v1/jwks";
const JWKS_TTL_MS = 6 * 60 * 60 * 1000;

type Jwk = JsonWebKey & { kid?: string };
export type JwksLoader = () => Promise<Jwk[]>;

let cachedKeys: { keys: Jwk[]; fetchedAt: number } | null = null;

const loadJwks: JwksLoader = async () => {
  if (cachedKeys && Date.now() - cachedKeys.fetchedAt < JWKS_TTL_MS) {
    return cachedKeys.keys;
  }
  const response = await fetch(JWKS_URL);
  if (!response.ok) throw new Error("app_check_jwks_unavailable");
  const body = await response.json() as { keys?: Jwk[] };
  const keys = body.keys ?? [];
  cachedKeys = { keys, fetchedAt: Date.now() };
  return keys;
};

function decodeSegment(segment: string) {
  const base64 = segment.replaceAll("-", "+").replaceAll("_", "/");
  const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
  return Uint8Array.from(atob(padded), (char) => char.charCodeAt(0));
}

function decodeJson(segment: string): Record<string, unknown> {
  return JSON.parse(new TextDecoder().decode(decodeSegment(segment)));
}

/** Any failure, including an outage, counts as not verified. */
export async function verifyAppCheckToken(
  token: string | null,
  loadKeys: JwksLoader = loadJwks,
): Promise<boolean> {
  try {
    const parts = token?.split(".") ?? [];
    if (parts.length !== 3) return false;
    const [encodedHeader, encodedPayload, encodedSignature] = parts;

    const header = decodeJson(encodedHeader);
    if (header.alg !== "RS256" || typeof header.kid !== "string") return false;

    const jwk = (await loadKeys()).find((key) => key.kid === header.kid);
    if (!jwk) return false;
    const key = await crypto.subtle.importKey(
      "jwk",
      jwk,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"],
    );
    const signatureValid = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      key,
      decodeSegment(encodedSignature),
      new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`),
    );
    if (!signatureValid) return false;

    const claims = decodeJson(encodedPayload);
    return claims.iss === ISSUER &&
      claims.sub === ANDROID_APP_ID &&
      Array.isArray(claims.aud) &&
      claims.aud.includes(`projects/${PROJECT_NUMBER}`) &&
      typeof claims.exp === "number" &&
      claims.exp * 1000 > Date.now();
  } catch {
    return false;
  }
}
