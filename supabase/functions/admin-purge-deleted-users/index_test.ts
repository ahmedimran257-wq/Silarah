import { assertEquals } from "@std/assert";
import { type PurgeJob, runPurgeRounds } from "./index.ts";

// A fake queue with the same rules as checkout_account_purge_jobs and
// finish_account_purge_phase: an advanced job is due again at once, a failed
// phase backs off and is not handed out again in this run.
function fakeQueue(jobs: { user_id: string; phase: string; failAt?: string }[]) {
  const state = jobs.map((job) => ({ ...job, due: true, done: false }));
  const order = ["storage", "auth", "database", "completed"];
  return {
    state,
    checkout: (): Promise<PurgeJob[] | null> =>
      Promise.resolve(
        state.filter((job) => job.due && !job.done).map((job) => ({
          user_id: job.user_id,
          phase: job.phase as PurgeJob["phase"],
          lease_token: "t",
        })),
      ),
    process: (leased: PurgeJob): Promise<boolean> => {
      const job = state.find((item) => item.user_id === leased.user_id)!;
      if (job.failAt === job.phase) {
        job.due = false;
        return Promise.resolve(false);
      }
      job.phase = order[order.indexOf(job.phase) + 1];
      job.done = job.phase === "completed";
      return Promise.resolve(true);
    },
  };
}

Deno.test("a deletion goes through storage, auth and database in one run", async () => {
  const queue = fakeQueue([{ user_id: "a", phase: "storage" }]);
  const result = await runPurgeRounds(queue.checkout, queue.process);
  assertEquals(queue.state[0].phase, "completed");
  assertEquals(result.rounds, 3);
  assertEquals(result.advanced, 3);
  assertEquals(result.failed, 0);
});

Deno.test("a job left at a later phase finishes from there", async () => {
  const queue = fakeQueue([{ user_id: "a", phase: "database" }]);
  const result = await runPurgeRounds(queue.checkout, queue.process);
  assertEquals(queue.state[0].phase, "completed");
  assertEquals(result.rounds, 1);
});

Deno.test("a failing phase stops that job but not the others", async () => {
  const queue = fakeQueue([
    { user_id: "a", phase: "storage", failAt: "auth" },
    { user_id: "b", phase: "storage" },
  ]);
  const result = await runPurgeRounds(queue.checkout, queue.process);
  assertEquals(queue.state[0].phase, "auth");
  assertEquals(queue.state[1].phase, "completed");
  assertEquals(result.failed, 1);
});

Deno.test("rounds and time are bounded", async () => {
  const queue = fakeQueue([{ user_id: "a", phase: "storage" }]);
  const limited = await runPurgeRounds(queue.checkout, queue.process, { maxRounds: 2 });
  assertEquals(limited.rounds, 2);
  assertEquals(queue.state[0].phase, "database");

  let clock = 0;
  const slow = fakeQueue([{ user_id: "b", phase: "storage" }]);
  const timed = await runPurgeRounds(slow.checkout, async (job) => {
    clock += 40_000;
    return await slow.process(job);
  }, { now: () => clock });
  assertEquals(timed.rounds, 2);
});

Deno.test("the queue being unavailable is reported only before any work", async () => {
  const first = await runPurgeRounds(() => Promise.resolve(null), () => Promise.resolve(true));
  assertEquals(first.queueUnavailable, true);
  let calls = 0;
  const later = await runPurgeRounds(
    () => Promise.resolve(calls++ === 0 ? [{ user_id: "a", phase: "storage", lease_token: "t" }] : null),
    () => Promise.resolve(true),
  );
  assertEquals(later.queueUnavailable, false);
  assertEquals(later.rounds, 1);
});
