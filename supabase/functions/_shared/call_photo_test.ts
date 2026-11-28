import { assertEquals } from "jsr:@std/assert@1";
import { type PhotoClient, RING_PHOTO_SECONDS, ringPhotoUrl } from "./call_photo.ts";

const CALLER = "11111111-1111-4111-8111-111111111111";
const CALLEE = "22222222-2222-4222-8222-222222222222";

function client(rows: unknown[] | null, opts: { delayMs?: number; rpcError?: boolean } = {}) {
  const calls: { fn: string; args: Record<string, unknown> }[] = [];
  const signed: { path: string; seconds: number }[] = [];
  const stub: PhotoClient = {
    rpc: async (fn, args) => {
      calls.push({ fn, args });
      if (opts.delayMs) await new Promise((resolve) => setTimeout(resolve, opts.delayMs));
      return opts.rpcError ? { data: null, error: { message: "boom" } } : { data: rows, error: null };
    },
    storage: {
      from: () => ({
        createSignedUrl: (path, seconds) => {
          signed.push({ path, seconds });
          return Promise.resolve({ data: { signedUrl: `https://signed/${path}` }, error: null });
        },
      }),
    },
  };
  return { stub, calls, signed };
}

Deno.test("the photo follows the callee's rights to see the caller", async () => {
  const { stub, calls, signed } = client([{ owner_user_id: CALLER, storage_path: "caller/1.jpg" }]);
  assertEquals(await ringPhotoUrl(stub, CALLEE, CALLER), "https://signed/caller/1.jpg");
  assertEquals(calls, [{
    fn: "get_authorized_photo_paths",
    args: { p_viewer_user_id: CALLEE, p_owner_user_ids: [CALLER], p_order_index: 0 },
  }]);
  assertEquals(signed, [{ path: "caller/1.jpg", seconds: RING_PHOTO_SECONDS }]);
});

Deno.test("no photo the callee may not see, and no photo on errors", async () => {
  assertEquals(await ringPhotoUrl(client([]).stub, CALLEE, CALLER), null);
  assertEquals(await ringPhotoUrl(client([{ owner_user_id: "someone-else", storage_path: "x.jpg" }]).stub, CALLEE, CALLER), null);
  assertEquals(await ringPhotoUrl(client(null, { rpcError: true }).stub, CALLEE, CALLER), null);
});

Deno.test("a slow photo never holds up the ring", async () => {
  const { stub } = client([{ owner_user_id: CALLER, storage_path: "caller/1.jpg" }], { delayMs: 200 });
  const started = Date.now();
  assertEquals(await ringPhotoUrl(stub, CALLEE, CALLER, 50), null);
  assertEquals(Date.now() - started < 190, true);
});
