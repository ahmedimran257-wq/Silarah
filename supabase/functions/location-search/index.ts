import { createClient } from "@supabase/supabase-js";
import { corsHeaders } from "../_shared/cors.ts";
import { readResponseJson } from "../_shared/bounded_response.ts";
import {
  consumeDistributedRateLimit,
  rateLimitHeaders,
} from "../_shared/distributed_rate_limit.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const LOCATION_RESULT_SIGNING_SECRET =
  Deno.env.get("LOCATION_RESULT_SIGNING_SECRET") ?? "";
const PHOTON_URL = "https://photon.komoot.io/api";
const TIMEOUT_MS = 6_000;
const MAX_RESPONSE_BYTES = 512 * 1024;
// Results requested from Photon before the country filter (about 15 KB).
const PROVIDER_WINDOW = 50;

function featureCountryCode(raw: unknown): string {
  if (!raw || typeof raw !== "object") return "";
  const properties = (raw as Record<string, unknown>).properties;
  if (!properties || typeof properties !== "object") return "";
  return String((properties as Record<string, unknown>).countrycode ?? "")
    .trim()
    .toUpperCase();
}

type SearchPayload = {
  query?: unknown;
  country_code?: unknown;
  mode?: unknown;
  limit?: unknown;
  resolution_token?: unknown;
};

type ResolutionClaim = {
  v: 1;
  sub: string;
  exp: number;
  city: string;
  state: string;
  country: string;
  country_code: string;
  lat: number;
  lng: number;
  // District (Photon "county"). Optional so tokens issued before it was added
  // still verify during their ten-minute lifetime.
  district?: string;
};

// India alone has dozens of villages called Ramnagar or Shivajinagar in one
// state. Cities are unique per (region, name), so a same-name place in another
// district gets its district in the stored name instead of sharing a row.
function catalogCityName(claim: ResolutionClaim): string {
  const city = claim.city.trim();
  const district = (claim.district ?? "").trim();
  if (!district || district.toLowerCase() === city.toLowerCase()) return city;
  const qualified = `${city} (${district})`;
  return qualified.length <= 100 ? qualified : city;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  const correlationId = crypto.randomUUID();
  try {
    if (req.method !== "POST") {
      return json(405, { error: "method_not_allowed" });
    }
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json(401, { error: "unauthorized" });
    }

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: authData, error: authError } = await admin.auth.getUser(
      authHeader.slice("Bearer ".length),
    );
    const userId = authData.user?.id;
    if (authError || !userId) return json(401, { error: "unauthorized" });

    // Banned or deleted accounts cannot use the shared location service.
    const { data: account } = await admin
      .from("users")
      .select("is_banned, deleted_at")
      .eq("id", userId)
      .maybeSingle();
    if (account && (account.is_banned === true || account.deleted_at != null)) {
      return json(403, { error: "account_unavailable" });
    }

    const payload = await req.json() as SearchPayload;
    if (payload.mode === "resolve") {
      // Each resolve may create a catalogue city; keep it to human pace.
      const resolveLimit = await consumeDistributedRateLimit(admin, {
        scope: "location_resolve",
        subject: userId,
        maxRequests: 30,
        windowSeconds: 60,
      });
      if (!resolveLimit.allowed) {
        return new Response(
          JSON.stringify({ error: "location_search_limited" }),
          {
            status: 429,
            headers: {
              ...corsHeaders,
              ...rateLimitHeaders(resolveLimit),
              "Content-Type": "application/json",
            },
          },
        );
      }
      if (!LOCATION_RESULT_SIGNING_SECRET) {
        return json(503, { error: "location_resolution_unavailable" });
      }
      const claim = await verifyResolutionToken(
        String(payload.resolution_token ?? ""),
        userId,
      );
      if (!claim) {
        return json(400, { error: "invalid_location_resolution" });
      }
      const { data: cityId, error: cityError } = await admin.rpc(
        "get_or_create_city",
        {
          p_city_name: catalogCityName(claim),
          p_region_name: claim.state || claim.country,
          p_country_name: claim.country,
          p_country_code: claim.country_code,
          p_latitude: claim.lat,
          p_longitude: claim.lng,
        },
      );
      if (cityError || cityId == null) {
        console.error(
          `[location-search] ${correlationId} city_resolution_failed`,
        );
        return json(503, {
          error: "location_resolution_failed",
          correlation_id: correlationId,
        });
      }
      return json(200, { city_id: cityId });
    }

    const query = String(payload.query ?? "").trim();
    const countryCode = String(payload.country_code ?? "").trim().toUpperCase();
    const mode = payload.mode === "region" ? "region" : "city";
    const limit = Math.min(Math.max(Number(payload.limit) || 10, 1), 15);
    if (
      query.length < 2 || query.length > 80 ||
      !/^[A-Z]{2}$/.test(countryCode)
    ) {
      return json(400, { error: "invalid_location_query" });
    }

    // Typing a city sends a few searches a minute; these limits keep one
    // account from hammering the free public Photon service (which could
    // block Supabase's shared addresses for every member).
    let rateLimit = await consumeDistributedRateLimit(admin, {
      scope: "location_search",
      subject: userId,
      maxRequests: 30,
      windowSeconds: 60,
    });
    if (rateLimit.allowed) {
      rateLimit = await consumeDistributedRateLimit(admin, {
        scope: "location_search_daily",
        subject: userId,
        maxRequests: 600,
        windowSeconds: 86400,
      });
    }
    if (!rateLimit.allowed) {
      return new Response(
        JSON.stringify({ error: "location_search_limited" }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            ...rateLimitHeaders(rateLimit),
            "Content-Type": "application/json",
            "Cache-Control": "no-store",
          },
        },
      );
    }

    // Photon searches the whole world and has no country filter. Asking for
    // only the requested `limit` meant short prefixes ("Ban", "Kan", "Pat")
    // returned 15 foreign places and no Indian city at all. Ask for a wider,
    // place-only window and keep the selected country's results.
    const url = new URL(PHOTON_URL);
    url.searchParams.set("q", query);
    url.searchParams.set("limit", String(PROVIDER_WINDOW));
    url.searchParams.append(
      "osm_tag",
      mode === "region" ? "place:state" : "place",
    );

    const response = await fetch(url, {
      headers: {
        "Accept": "application/json",
        "User-Agent": "Silarah/1.0 (contact@silarah.com)",
      },
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (!response.ok) {
      console.warn(
        `[location-search] ${correlationId} provider_status=${response.status}`,
      );
      return json(response.status === 429 ? 503 : 502, {
        error: "location_provider_unavailable",
        correlation_id: correlationId,
      });
    }

    const data = await readResponseJson(response, MAX_RESPONSE_BYTES) as {
      features?: unknown[];
    };
    const features = Array.isArray(data.features)
      ? data.features
        .filter((feature) => featureCountryCode(feature) === countryCode)
        .slice(0, limit)
      : [];
    if (!LOCATION_RESULT_SIGNING_SECRET) {
      return json(503, { error: "location_resolution_unavailable" });
    }
    const signedFeatures = await Promise.all(
      features.map(async (feature) => {
        const claim = locationClaim(feature, userId);
        if (!claim) return null;
        return {
          ...(feature as Record<string, unknown>),
          silarah_resolution_token: await signResolutionClaim(claim),
        };
      }),
    );
    return json(200, { features: signedFeatures.filter(Boolean) });
  } catch (error) {
    const code = error instanceof DOMException && error.name === "TimeoutError"
      ? "location_provider_timeout"
      : "location_search_failed";
    console.error(`[location-search] ${correlationId} ${code}`);
    return json(503, { error: code, correlation_id: correlationId });
  }
});

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": status === 200 ? "private, max-age=300" : "no-store",
    },
  });
}

function locationClaim(
  raw: unknown,
  userId: string,
): ResolutionClaim | null {
  if (!raw || typeof raw !== "object") return null;
  const feature = raw as Record<string, unknown>;
  const properties = feature.properties as Record<string, unknown> | undefined;
  const geometry = feature.geometry as Record<string, unknown> | undefined;
  const coordinates = geometry?.coordinates;
  if (
    !properties ||
    !Array.isArray(coordinates) ||
    coordinates.length < 2 ||
    typeof coordinates[0] !== "number" ||
    typeof coordinates[1] !== "number"
  ) return null;

  const city = String(properties.name ?? "").trim();
  const state = String(properties.state ?? "").trim();
  const country = String(properties.country ?? "").trim();
  const countryCode = String(properties.countrycode ?? "").trim().toUpperCase();
  const osmKey = String(properties.osm_key ?? "").trim().toLowerCase();
  const district = String(properties.county ?? properties.district ?? "")
    .trim()
    .slice(0, 100);
  const lat = coordinates[1];
  const lng = coordinates[0];
  if (
    osmKey !== "place" ||
    city.length < 2 ||
    city.length > 100 ||
    state.length > 100 ||
    country.length < 2 ||
    country.length > 100 ||
    !/^[A-Z]{2}$/.test(countryCode) ||
    lat < -90 ||
    lat > 90 ||
    lng < -180 ||
    lng > 180
  ) return null;

  return {
    v: 1,
    sub: userId,
    exp: Date.now() + 10 * 60 * 1000,
    city,
    state,
    country,
    country_code: countryCode,
    lat,
    lng,
    ...(district ? { district } : {}),
  };
}

async function signResolutionClaim(claim: ResolutionClaim): Promise<string> {
  const payload = new TextEncoder().encode(JSON.stringify(claim));
  const signature = await hmac(payload);
  return `${base64Url(payload)}.${base64Url(signature)}`;
}

async function verifyResolutionToken(
  token: string,
  userId: string,
): Promise<ResolutionClaim | null> {
  const parts = token.split(".");
  if (parts.length !== 2 || token.length > 2048) return null;
  try {
    const payload = fromBase64Url(parts[0]);
    const supplied = fromBase64Url(parts[1]);
    const expected = await hmac(payload);
    if (!constantTimeEqual(supplied, expected)) return null;
    const claim = JSON.parse(
      new TextDecoder().decode(payload),
    ) as ResolutionClaim;
    if (
      claim.v !== 1 ||
      claim.sub !== userId ||
      !Number.isSafeInteger(claim.exp) ||
      claim.exp < Date.now() ||
      claim.exp > Date.now() + 11 * 60 * 1000 ||
      !/^[A-Z]{2}$/.test(claim.country_code) ||
      claim.city.length < 2 ||
      claim.city.length > 100 ||
      claim.country.length < 2 ||
      claim.country.length > 100 ||
      claim.state.length > 100 ||
      (claim.district !== undefined &&
        (typeof claim.district !== "string" || claim.district.length > 100)) ||
      !Number.isFinite(claim.lat) ||
      claim.lat < -90 ||
      claim.lat > 90 ||
      !Number.isFinite(claim.lng) ||
      claim.lng < -180 ||
      claim.lng > 180
    ) return null;
    return claim;
  } catch {
    return null;
  }
}

async function hmac(payload: Uint8Array): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(LOCATION_RESULT_SIGNING_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const input = Uint8Array.from(payload);
  return new Uint8Array(
    await crypto.subtle.sign("HMAC", key, input.buffer),
  );
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
}

function fromBase64Url(value: string): Uint8Array {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  return Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
}

function constantTimeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let i = 0; i < a.length; i += 1) difference |= a[i] ^ b[i];
  return difference === 0;
}
