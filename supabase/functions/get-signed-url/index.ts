// EDGE FUNCTION: get-signed-url
//
// Issues a short-lived pre-signed upload URL for profile photos.
//
//   1. Check photo quota (max 4) — 403 if exceeded
//   2. Rate-limit: max 100 URL requests/hour per user (anti-scraping)
//   3. Insert 'pending_upload' placeholder in photos table
//   4. Return the pre-signed upload URL to the client
//
// This prevents the bypass vulnerability where a malicious client
// hoards pre-signed URLs without the DB tracking rows,
// bypassing the photo quota entirely.
//
// Storage SELECT RLS is disabled on the bucket — all reads
// served via signed URLs from this function only.
import { createClient } from "@supabase/supabase-js";
import { corsHeaders, handleCors } from "../_shared/cors.ts";
import {
  consumeDistributedRateLimit,
  rateLimitHeaders,
} from "../_shared/distributed_rate_limit.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const BUCKET_NAME = "profile-photos";
const MAX_PHOTOS = 4;
// Supabase fixes upload-token validity at two hours. Reservation expiry is
// enforced separately by finalize_profile_photo_upload, not by this metadata.
const UPLOAD_URL_EXPIRES_IN = 7200;
// Authorization is checked again when issuing a new read URL. Storage/CDN
// response caching is independent of this token TTL.
const READ_URL_EXPIRES_IN = 300;
const RATE_LIMIT_WINDOW = 60 * 60; // 1 hour in seconds
const PURPOSE_LIMITS: Record<string, number> = {
  read: 300,
  upload: 20,
  delete: 20,
};

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // Authenticate caller
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return errorResponse(401, "Missing or invalid Authorization header.");
    }
    const userToken = authHeader.slice("Bearer ".length);
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: authData, error: authError } = await adminClient.auth
      .getUser(userToken);
    const userId = authData.user?.id;
    if (authError || !userId || !isUuid(userId)) {
      return errorResponse(401, "Unauthorized.");
    }

    const [
      { data: account, error: accountError },
      { data: profileState, error: profileStateError },
    ] = await Promise.all([
      adminClient
        .from("users")
        .select("is_banned, deleted_at")
        .eq("id", userId)
        .maybeSingle(),
      adminClient
        .from("profiles")
        .select("visibility")
        .eq("user_id", userId)
        .maybeSingle(),
    ]);
    if (
      accountError || profileStateError || !account ||
      account.is_banned === true ||
      account.deleted_at != null ||
      ["suspended", "deactivated"].includes(
        String(profileState?.visibility ?? ""),
      )
    ) {
      return errorResponse(403, "This account cannot access private media.");
    }

    const requestBody = await req.json() as {
      order_index?: number;
      file_extension?: string;
      purpose?:
        | "read_profile_photo"
        | "read_profile_photos"
        | "read_profile_gallery"
        | "delete_profile_photo"
        | "delete_replaced_profile_photo";
      owner_user_id?: string;
      owner_user_ids?: string[];
      storage_path?: string;
    };
    const purposeScope = requestBody.purpose?.startsWith("read_")
      ? "read"
      : requestBody.purpose?.startsWith("delete_")
      ? "delete"
      : "upload";

    // Rate limiting (anti-scraping)
    const rateLimit = await consumeDistributedRateLimit(adminClient, {
      scope: `signed_url_${purposeScope}`,
      subject: userId,
      maxRequests: PURPOSE_LIMITS[purposeScope],
      windowSeconds: RATE_LIMIT_WINDOW,
    });
    if (!rateLimit.allowed) {
      console.warn(`[get-signed-url] Rate limit exceeded for user ${userId}`);
      await flagSuspiciousUser(userId, "rate_limit_exceeded_signed_url");
      return new Response(
        JSON.stringify({ error: "Too many requests. Please try again later." }),
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

    // Parse request
    const {
      order_index,
      file_extension,
      purpose,
      owner_user_id,
      owner_user_ids,
      storage_path,
    } = requestBody;

    if (purpose === "read_profile_photo") {
      return await createAuthorizedProfilePhotoReadUrl(
        userId,
        owner_user_id,
        order_index ?? 0,
      );
    }
    if (purpose === "read_profile_photos") {
      return await createAuthorizedProfilePhotoReadUrls(
        userId,
        owner_user_ids,
        order_index ?? 0,
      );
    }
    if (purpose === "read_profile_gallery") {
      return await createAuthorizedProfilePhotoGalleryReadUrls(
        userId,
        owner_user_id,
      );
    }
    if (purpose === "delete_profile_photo") {
      return await deleteOwnProfilePhoto(userId, order_index);
    }
    if (purpose === "delete_replaced_profile_photo") {
      return await deleteReplacedProfilePhotoObject(userId, storage_path);
    }

    const ext = (file_extension ?? "webp").toLowerCase();
    const allowedTypes = ["jpg"];
    if (!allowedTypes.includes(ext)) {
      return errorResponse(400, "Unsupported image format.");
    }

    if (order_index === undefined || order_index < 0 || order_index > 3) {
      return errorResponse(400, "order_index must be 0, 1, 2, or 3.");
    }

    // Get user's profile ID
    const { data: profile, error: profileError } = await adminClient
      .from("profiles")
      .select("id")
      .eq("user_id", userId)
      .single();

    if (profileError || !profile) {
      return errorResponse(
        404,
        "Profile not found. Complete onboarding first.",
      );
    }
    const profileId = profile.id;

    const { data: existingPhoto, error: existingPhotoError } = await adminClient
      .from("photos")
      .select("id, storage_path")
      .eq("profile_id", profileId)
      .eq("order_index", order_index)
      .eq("status", "active")
      .maybeSingle();
    const { data: pendingPhoto, error: pendingPhotoError } = await adminClient
      .from("photos")
      .select("id, storage_path")
      .eq("profile_id", profileId)
      .eq("order_index", order_index)
      .eq("status", "pending_review")
      .maybeSingle();
    if (existingPhotoError || pendingPhotoError) {
      throw new Error(
        `Existing photo query failed: ${
          existingPhotoError?.message ?? pendingPhotoError?.message
        }`,
      );
    }

    // Finalization may have committed while the client lost the HTTP response.
    // Treat that retry as success instead of asking the member to upload the
    // same slot again or surfacing a misleading reservation error.
    if (pendingPhoto) {
      return new Response(
        JSON.stringify({
          action: "already_pending",
          photo_id: pendingPhoto.id,
          storage_path: pendingPhoto.storage_path,
          order_index,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Check photo quota (BEFORE generating URL)
    const { count: existingCount, error: countError } = await adminClient
      .from("photos")
      .select("id", { count: "exact", head: true })
      .eq("profile_id", profileId)
      .eq("status", "active"); // Only count successfully uploaded photos

    if (countError) {
      throw new Error(`Photo count query failed: ${countError.message}`);
    }

    if (!existingPhoto && (existingCount ?? 0) >= MAX_PHOTOS) {
      return errorResponse(
        403,
        `Maximum ${MAX_PHOTOS} photos allowed. Delete one before uploading.`,
      );
    }

    // Generate unique storage path
    const fileName = `${crypto.randomUUID()}.${ext}`;
    const storagePath = `${userId}/${fileName}`;

    // Insert 'pending_upload' placeholder (atomic gate)
    // This row is inserted BEFORE the URL is returned.
    // If the upload never completes, a cleanup job removes stale pending_upload rows.
    const { data: reservationRows, error: reservationError } = await adminClient
      .rpc("reserve_upload", {
        p_user_id: userId,
        p_bucket_id: BUCKET_NAME,
        p_purpose: "profile_photo",
        p_storage_path: storagePath,
        p_expected_mime: "image/jpeg",
        p_max_bytes: 5 * 1024 * 1024,
        p_order_index: order_index,
      });
    const reservation = Array.isArray(reservationRows)
      ? reservationRows[0]
      : reservationRows;
    if (reservationError || !reservation?.reservation_id) {
      return errorResponse(409, "The photo slot could not be reserved.");
    }

    // Generate the pre-signed upload URL
    const { data: signedUrlData, error: urlError } = await adminClient
      .storage
      .from(BUCKET_NAME)
      .createSignedUploadUrl(storagePath);

    if (urlError || !signedUrlData?.signedUrl) {
      return errorResponse(503, "A secure upload URL could not be issued.");
    }

    return new Response(
      JSON.stringify({
        signed_url: signedUrlData.signedUrl,
        storage_path: storagePath,
        reservation_id: reservation.reservation_id,
        token: signedUrlData.token,
        replaced_storage_path: existingPhoto?.storage_path ?? null,
        expires_in: UPLOAD_URL_EXPIRES_IN,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    const correlationId = crypto.randomUUID();
    console.error(`[get-signed-url] ${correlationId}`, err);
    return new Response(
      JSON.stringify({
        error: "The secure media request could not be completed.",
        correlation_id: correlationId,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});

async function deleteOwnProfilePhoto(
  userId: string,
  orderIndex: number | undefined,
): Promise<Response> {
  if (!Number.isInteger(orderIndex) || orderIndex! < 0 || orderIndex! > 3) {
    return errorResponse(400, "order_index must be 0, 1, 2, or 3.");
  }
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: queued, error } = await adminClient.rpc(
    "request_profile_photo_deletion",
    { p_user_id: userId, p_order_index: orderIndex! },
  );
  if (error) {
    throw new Error("photo_deletion_queue_failed");
  }
  return new Response(JSON.stringify({ deletion_queued: queued === true }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function deleteReplacedProfilePhotoObject(
  _userId: string,
  _storagePath: string | undefined,
): Response {
  return errorResponse(410, "Client-side replaced-photo cleanup is retired.");
}

async function createAuthorizedProfilePhotoReadUrl(
  viewerUserId: string,
  ownerUserId: string | undefined,
  orderIndex: number,
): Promise<Response> {
  if (!ownerUserId || !isUuid(ownerUserId)) {
    return errorResponse(400, "owner_user_id is required.");
  }
  if (!Number.isInteger(orderIndex) || orderIndex < 0 || orderIndex > 3) {
    return errorResponse(400, "order_index must be 0, 1, 2, or 3.");
  }

  // The service-only RPC enforces discovery/relationship authorization and
  // photo privacy before any private object path reaches this worker.
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: rows, error: photoError } = await adminClient.rpc(
    "get_authorized_photo_paths",
    {
      p_viewer_user_id: viewerUserId,
      p_owner_user_ids: [ownerUserId],
      p_order_index: orderIndex,
    },
  );
  const photo = Array.isArray(rows) ? rows[0] : null;

  if (photoError) {
    throw new Error(`Photo authorization failed: ${photoError.message}`);
  }
  if (!photo?.storage_path) {
    return errorResponse(403, "You do not have access to this photo.");
  }

  const { data, error } = await adminClient.storage
    .from(BUCKET_NAME)
    // Image transformations are not part of the Supabase Free plan. Uploads
    // are already bounded JPEG files, so serve the original private object.
    .createSignedUrl(photo.storage_path, READ_URL_EXPIRES_IN);

  if (error || !data?.signedUrl) {
    throw new Error(`Failed to generate read URL: ${error?.message}`);
  }

  return new Response(
    JSON.stringify({
      signed_url: data.signedUrl,
      expires_in: READ_URL_EXPIRES_IN,
    }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
}

async function createAuthorizedProfilePhotoReadUrls(
  viewerUserId: string,
  ownerUserIds: string[] | undefined,
  orderIndex: number,
): Promise<Response> {
  const uniqueOwnerIds = [
    ...new Set((ownerUserIds ?? []).filter((id) => isUuid(id))),
  ].slice(0, 50);
  if (uniqueOwnerIds.length === 0) {
    return errorResponse(400, "owner_user_ids is required.");
  }
  if (!Number.isInteger(orderIndex) || orderIndex < 0 || orderIndex > 3) {
    return errorResponse(400, "order_index must be 0, 1, 2, or 3.");
  }

  // The client supplies owner IDs only, never storage paths.
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: photos, error: photoError } = await adminClient.rpc(
    "get_authorized_photo_paths",
    {
      p_viewer_user_id: viewerUserId,
      p_owner_user_ids: uniqueOwnerIds,
      p_order_index: orderIndex,
    },
  );

  if (photoError) {
    throw new Error(`Photo authorization failed: ${photoError.message}`);
  }

  const pathToOwner = new Map<string, string>();
  for (const photo of photos ?? []) {
    const row = photo as unknown as {
      storage_path?: unknown;
      owner_user_id?: unknown;
    };
    const storagePath = String(row.storage_path ?? "");
    const ownerId = row.owner_user_id;
    if (storagePath && typeof ownerId === "string") {
      pathToOwner.set(storagePath, ownerId);
    }
  }

  if (pathToOwner.size === 0) {
    return new Response(
      JSON.stringify({ urls: {}, expires_in: READ_URL_EXPIRES_IN }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const storagePaths = [...pathToOwner.keys()];
  const { data, error } = await adminClient.storage
    .from(BUCKET_NAME)
    .createSignedUrls(storagePaths, READ_URL_EXPIRES_IN);

  if (error || !data) {
    throw new Error(`Failed to generate batch read URLs: ${error?.message}`);
  }

  const urls: Record<string, string> = {};
  for (const item of data) {
    const signedUrl = item.signedUrl;
    const path = item.path;
    const ownerId = path ? pathToOwner.get(path) : undefined;
    if (ownerId && signedUrl) {
      urls[ownerId] = signedUrl;
    }
  }

  return new Response(
    JSON.stringify({
      urls,
      expires_in: READ_URL_EXPIRES_IN,
    }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
}

async function createAuthorizedProfilePhotoGalleryReadUrls(
  viewerUserId: string,
  ownerUserId: string | undefined,
): Promise<Response> {
  if (!ownerUserId || !isUuid(ownerUserId)) {
    return errorResponse(400, "owner_user_id is required.");
  }

  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: photos, error: photoError } = viewerUserId === ownerUserId
    ? await adminClient.rpc("get_my_photo_management_paths", {
      p_user_id: viewerUserId,
    })
    : await adminClient.rpc("get_authorized_photo_gallery_paths", {
      p_viewer_user_id: viewerUserId,
      p_owner_user_id: ownerUserId,
    });
  if (photoError) {
    throw new Error(`Photo authorization failed: ${photoError.message}`);
  }

  const pathToSlot = new Map<string, number>();
  for (const photo of photos ?? []) {
    const row = photo as unknown as {
      order_index?: unknown;
      storage_path?: unknown;
    };
    const orderIndex = Number(row.order_index);
    const storagePath = String(row.storage_path ?? "");
    if (
      Number.isInteger(orderIndex) &&
      orderIndex >= 0 &&
      orderIndex <= 3 &&
      storagePath
    ) {
      pathToSlot.set(storagePath, orderIndex);
    }
  }

  if (pathToSlot.size === 0) {
    return new Response(
      JSON.stringify({ slots: {}, expires_in: READ_URL_EXPIRES_IN }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const { data, error } = await adminClient.storage
    .from(BUCKET_NAME)
    .createSignedUrls([...pathToSlot.keys()], READ_URL_EXPIRES_IN);
  if (error || !data) {
    throw new Error(`Failed to generate gallery URLs: ${error?.message}`);
  }

  const slots: Record<string, string> = {};
  for (const item of data) {
    const orderIndex = item.path ? pathToSlot.get(item.path) : undefined;
    if (orderIndex !== undefined && item.signedUrl) {
      slots[String(orderIndex)] = item.signedUrl;
    }
  }

  return new Response(
    JSON.stringify({ slots, expires_in: READ_URL_EXPIRES_IN }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

async function flagSuspiciousUser(
  userId: string,
  reason: string,
): Promise<void> {
  try {
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    // One alert per member per hour: a looping client used to add a staff
    // notification on every rejected request.
    const since = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const { data: recent } = await adminClient
      .from("admin_notifications")
      .select("id")
      .eq("type", "suspicious_activity")
      .eq("related_user_id", userId)
      .gte("created_at", since)
      .limit(1);
    if (recent && recent.length > 0) return;
    await adminClient.from("admin_notifications").insert({
      type: "suspicious_activity",
      message: `User ${userId} flagged: ${reason}`,
      related_user_id: userId,
    });
  } catch {
    // Keep the member request available, but make the failed security signal
    // observable without leaking the member identifier into provider logs.
    console.error("[get-signed-url] suspicious_activity_alert_failed");
  }
}

function errorResponse(status: number, message: string): Response {
  return new Response(
    JSON.stringify({ error: message }),
    { status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
}
