// The caller's photo for the ring screen on the callee's phones
// (docs/voice_calling_spec.md 12.1, 12.3): the native ring screen shows it
// before Silarah has started, so it cannot ask for the photo itself. The link
// follows exactly the rules of every photo the callee sees
// (get_authorized_photo_paths: photo privacy, blurring, matched status), is
// signed for a short time, and is never waited on for long: a ring never
// fails or waits because of a photo.

export const RING_PHOTO_SECONDS = 120;
export const RING_PHOTO_WAIT_MS = 800;
const BUCKET = "profile-photos";

type Result<T> = { data: T | null; error: { message: string } | null };

/** The parts of the admin client this needs (a test can stand in for it). */
export interface PhotoClient {
  rpc(fn: string, args: Record<string, unknown>): PromiseLike<Result<unknown>>;
  storage: {
    from(bucket: string): {
      createSignedUrl(path: string, seconds: number): PromiseLike<Result<{ signedUrl: string }>>;
    };
  };
}

async function signedPhoto(client: PhotoClient, calleeId: string, callerId: string): Promise<string | null> {
  const { data, error } = await client.rpc("get_authorized_photo_paths", {
    p_viewer_user_id: calleeId,
    p_owner_user_ids: [callerId],
    p_order_index: 0,
  });
  if (error || !Array.isArray(data)) return null;
  const row = data.find((entry) =>
    (entry as { owner_user_id?: unknown })?.owner_user_id === callerId
  ) as { storage_path?: unknown } | undefined;
  const path = typeof row?.storage_path === "string" ? row.storage_path : "";
  if (!path) return null;
  const signed = await client.storage.from(BUCKET).createSignedUrl(path, RING_PHOTO_SECONDS);
  return signed.error ? null : signed.data?.signedUrl ?? null;
}

/** A signed link to the caller's photo as the callee may see it, or null. */
export async function ringPhotoUrl(
  client: PhotoClient,
  calleeId: string,
  callerId: string,
  waitMs = RING_PHOTO_WAIT_MS,
): Promise<string | null> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<null>((resolve) => {
    timer = setTimeout(() => resolve(null), waitMs);
  });
  try {
    return await Promise.race([signedPhoto(client, calleeId, callerId).catch(() => null), timeout]);
  } finally {
    clearTimeout(timer);
  }
}
