import { createClient } from "@supabase/supabase-js";
import { Image } from "imagescript";
import { encode } from "blurhash";
import { verifyAppCheckToken } from "../_shared/app_check.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { hasSafeJpegDimensions } from "./jpeg_dimensions.ts";
import {
  consumeDistributedRateLimit,
  rateLimitHeaders,
} from "../_shared/distributed_rate_limit.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BUCKET_NAME = "profile-photos";
const MAX_BYTES = 5 * 1024 * 1024;
// Off until a Play-delivered build shows valid tokens in the logs: while off,
// the result is only logged, so a broken attestation cannot hold every photo.
const ATTESTATION_REQUIRED =
  Deno.env.get("PHOTO_ATTESTATION_REQUIRED") === "true";

type ValidationPayload = {
  storage_path?: string;
  moderation?: {
    nsfw_confidence?: unknown;
    category?: unknown;
  };
  record?: { name?: string };
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  const correlationId = crypto.randomUUID();
  try {
    if (req.method !== "POST") {
      return json(405, { error: "method_not_allowed" });
    }
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return json(401, { error: "unauthorized" });
    }
    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const token = authHeader.slice("Bearer ".length);
    const { data: authData, error: authError } = await admin.auth.getUser(
      token,
    );
    const userId = authData.user?.id;
    if (authError || !userId) return json(401, { error: "unauthorized" });

    const payload = await req.json() as ValidationPayload;
    const storagePath = String(payload.storage_path ?? "");
    if (
      !storagePath.startsWith(`${userId}/`) ||
      !/^[0-9a-f-]{36}\/[0-9a-f-]{36}[.]jpg$/i.test(storagePath)
    ) {
      return json(400, { error: "invalid_upload_path" });
    }
    const rateLimit = await consumeDistributedRateLimit(admin, {
      scope: "photo_validation",
      subject: userId,
      maxRequests: 20,
      windowSeconds: 60 * 60,
    });
    if (!rateLimit.allowed) {
      return new Response(
        JSON.stringify({ error: "validation_rate_limited" }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            ...rateLimitHeaders(rateLimit),
            "Content-Type": "application/json",
          },
        },
      );
    }

    const { data: prior } = await admin.from("photos")
      .select("id, status")
      .eq("storage_path", storagePath)
      .maybeSingle();
    if (prior) {
      return json(200, {
        action: prior.status === "active" ? "active" : "pending_review",
        photo_id: prior.id,
      });
    }

    const { data: object, error: downloadError } = await admin.storage
      .from(BUCKET_NAME)
      .download(storagePath);
    if (downloadError || !object) {
      return json(404, { error: "upload_not_found" });
    }
    const bytes = new Uint8Array(await object.arrayBuffer());
    if (
      bytes.byteLength < 32 || bytes.byteLength > MAX_BYTES ||
      !isJpeg(bytes)
    ) {
      await admin.storage.from(BUCKET_NAME).remove([storagePath]);
      return json(422, { error: "invalid_image" });
    }

    if (!hasSafeJpegDimensions(bytes)) {
      await admin.storage.from(BUCKET_NAME).remove([storagePath]);
      return json(422, { error: "invalid_image_dimensions" });
    }

    let image: Image;
    try {
      image = await Image.decode(bytes);
    } catch {
      await admin.storage.from(BUCKET_NAME).remove([storagePath]);
      return json(422, { error: "invalid_image" });
    }
    if (
      image.width < 320 || image.height < 320 ||
      image.width > 8000 || image.height > 8000 ||
      image.width * image.height > 32_000_000
    ) {
      await admin.storage.from(BUCKET_NAME).remove([storagePath]);
      return json(422, { error: "invalid_image_dimensions" });
    }

    const blurhash = createBlurHash(image);
    const clientScore = boundedScore(payload.moderation?.nsfw_confidence);
    const attested = await verifyAppCheckToken(
      req.headers.get("X-Firebase-AppCheck"),
    );
    console.log(`[validate-photo-upload] app_check_valid=${attested}`);
    const { data: finalizedRows, error: finalizeError } = await admin.rpc(
      "finalize_profile_photo_upload",
      {
        p_user_id: userId,
        p_storage_path: storagePath,
        p_observed_mime: "image/jpeg",
        p_observed_bytes: bytes.byteLength,
        p_blurhash: blurhash,
        p_client_nsfw_score: clientScore,
        p_device_attested: attested || !ATTESTATION_REQUIRED,
      },
    );
    const finalized = Array.isArray(finalizedRows)
      ? finalizedRows[0]
      : finalizedRows;
    if (finalizeError || !finalized?.photo_id) {
      await admin.storage.from(BUCKET_NAME).remove([storagePath]);
      console.warn(
        `[validate-photo-upload] ${correlationId} finalize rejected`,
        finalizeError?.code ?? "invalid_result",
      );
      return json(409, { error: "upload_reservation_invalid" });
    }

    const action = finalized.action === "active" ? "active" : "pending_review";
    return json(202, {
      action,
      photo_id: finalized.photo_id,
      message: action === "active"
        ? "Photo published and queued for ongoing moderation."
        : "Flagged photo received for safety review.",
    });
  } catch (error) {
    console.error(`[validate-photo-upload] ${correlationId}`, error);
    return json(500, {
      error: "photo_validation_failed",
      correlation_id: correlationId,
    });
  }
});

function isJpeg(bytes: Uint8Array): boolean {
  return bytes.length >= 4 &&
    bytes[0] === 0xff &&
    bytes[1] === 0xd8 &&
    bytes[bytes.length - 2] === 0xff &&
    bytes[bytes.length - 1] === 0xd9;
}

function boundedScore(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.min(1, Math.max(0, parsed)) : 0;
}

function createBlurHash(image: Image): string {
  const scale = Math.min(32 / image.width, 32 / image.height, 1);
  const width = Math.max(1, Math.round(image.width * scale));
  const height = Math.max(1, Math.round(image.height * scale));
  const thumbnail = image.resize(width, height);
  const rgba = new Uint8ClampedArray(
    thumbnail.bitmap.buffer,
    thumbnail.bitmap.byteOffset,
    thumbnail.bitmap.byteLength,
  );
  return encode(rgba, width, height, 4, 3);
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}
