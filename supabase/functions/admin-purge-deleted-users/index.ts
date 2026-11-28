import { createClient } from "@supabase/supabase-js";
import { isAuthorizedCronRequest } from "../_shared/cron_auth.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BUCKETS = [
  "profile-photos",
  "photo-verification-captures",
];
const CONCURRENCY = 3;

function createAdminClient() {
  return createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
type AdminClient = ReturnType<typeof createAdminClient>;

export type PurgeJob = {
  user_id: string;
  phase: "storage" | "auth" | "database";
  lease_token: string;
};

// A purge has three phases (storage, auth, database). Each checkout leases one
// phase per job, and this worker runs once a day, so a deletion used to take
// three days. It now checks out again after each round: a job that advanced
// is due again at once, so it moves through every phase in one run. A failed
// phase backs off (finish_account_purge_phase) and is not retried this run.
const MAX_ROUNDS = 4;
const ROUND_BUDGET_MS = 60_000;

export type PurgeRunResult = {
  rounds: number;
  processed: number;
  advanced: number;
  failed: number;
  queueUnavailable: boolean;
};

export async function runPurgeRounds(
  checkout: () => Promise<PurgeJob[] | null>,
  process: (job: PurgeJob) => Promise<boolean>,
  options: { maxRounds?: number; budgetMs?: number; now?: () => number } = {},
): Promise<PurgeRunResult> {
  const maxRounds = options.maxRounds ?? MAX_ROUNDS;
  const budgetMs = options.budgetMs ?? ROUND_BUDGET_MS;
  const now = options.now ?? Date.now;
  const started = now();
  const result: PurgeRunResult = {
    rounds: 0,
    processed: 0,
    advanced: 0,
    failed: 0,
    queueUnavailable: false,
  };
  while (result.rounds < maxRounds && now() - started < budgetMs) {
    const jobs = await checkout();
    if (jobs === null) {
      result.queueUnavailable = result.rounds === 0;
      break;
    }
    if (jobs.length === 0) break;
    result.rounds += 1;
    const outcomes = await mapWithConcurrency(jobs, CONCURRENCY, process);
    const advanced = outcomes.filter(Boolean).length;
    result.processed += jobs.length;
    result.advanced += advanced;
    result.failed += jobs.length - advanced;
    if (advanced === 0) break;
  }
  return result;
}

if (import.meta.main) {
  Deno.serve(async (req) => {
    if (req.method !== "POST") {
      return json(405, { error: "method_not_allowed" });
    }
    if (!(await isAuthorizedCronRequest(req))) {
      return json(401, { error: "unauthorized" });
    }
    const admin = createAdminClient();
    const result = await runPurgeRounds(
      async () => {
        const { data, error } = await admin.rpc("checkout_account_purge_jobs", {
          p_limit: 10,
        });
        return error ? null : (data ?? []) as PurgeJob[];
      },
      (job) => processJob(admin, job),
    );
    if (result.queueUnavailable) {
      return json(503, { error: "purge_queue_unavailable" });
    }
    return json(200, {
      rounds: result.rounds,
      processed: result.processed,
      advanced: result.advanced,
      failed: result.failed,
    });
  });
}

async function processJob(
  admin: AdminClient,
  job: PurgeJob,
): Promise<boolean> {
  try {
    if (job.phase === "storage") {
      for (const bucket of BUCKETS) {
        await purgeBucketPrefix(admin, bucket, job.user_id);
      }
      await finish(admin, job, true, "auth");
      return true;
    }
    if (job.phase === "auth") {
      const { error } = await admin.auth.admin.deleteUser(job.user_id);
      if (error && !error.message.toLowerCase().includes("not found")) {
        throw new Error("auth_delete_failed");
      }
      await finish(admin, job, true, "database");
      return true;
    }
    for (const bucket of BUCKETS) {
      await assertBucketPrefixEmpty(admin, bucket, job.user_id);
    }
    const { error: deleteError } = await admin.from("users")
      .delete().eq("id", job.user_id);
    if (deleteError) throw new Error("database_delete_failed");
    await finish(admin, job, true, "completed");
    return true;
  } catch (error) {
    console.error("[admin-purge]", {
      userId: job.user_id,
      phase: job.phase,
      error: error instanceof Error ? error.message : "unknown",
    });
    await finish(
      admin,
      job,
      false,
      null,
      error instanceof Error ? error.message : "purge_phase_failed",
    ).catch(() => undefined);
    return false;
  }
}

async function purgeBucketPrefix(
  admin: AdminClient,
  bucket: string,
  userId: string,
): Promise<void> {
  for (let page = 0; page < 100; page++) {
    const { data, error } = await admin.storage.from(bucket).list(userId, {
      limit: 100,
      offset: 0,
      sortBy: { column: "name", order: "asc" },
    });
    if (error) throw new Error(`storage_list_${bucket}`);
    if (!data || data.length === 0) return;
    const paths = data.map((item) => `${userId}/${item.name}`);
    const { error: removeError } = await admin.storage.from(bucket).remove(
      paths,
    );
    if (removeError) throw new Error(`storage_remove_${bucket}`);
  }
  throw new Error(`storage_pagination_limit_${bucket}`);
}

async function assertBucketPrefixEmpty(
  admin: AdminClient,
  bucket: string,
  userId: string,
): Promise<void> {
  const { data, error } = await admin.storage.from(bucket).list(userId, {
    limit: 1,
  });
  if (error || (data?.length ?? 0) > 0) {
    throw new Error(`storage_not_empty_${bucket}`);
  }
}

async function finish(
  admin: AdminClient,
  job: PurgeJob,
  success: boolean,
  nextPhase: string | null,
  errorCode: string | null = null,
) {
  const { error } = await admin.rpc("finish_account_purge_phase", {
    p_user_id: job.user_id,
    p_lease_token: job.lease_token,
    p_success: success,
    p_next_phase: nextPhase,
    p_error_code: errorCode,
  });
  if (error) throw new Error("purge_checkpoint_failed");
}

async function mapWithConcurrency<T, R>(
  items: T[],
  concurrency: number,
  task: (item: T) => Promise<R>,
): Promise<R[]> {
  const results = new Array<R>(items.length);
  let cursor = 0;
  const workers = Array.from(
    { length: Math.min(concurrency, items.length) },
    async () => {
      while (true) {
        const index = cursor++;
        if (index >= items.length) return;
        results[index] = await task(items[index]);
      }
    },
  );
  await Promise.all(workers);
  return results;
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}
