import type { Env } from "./types";
import app from "./app";
import { reconcileRefunds } from "./lib/reconcile";

export default {
  fetch: app.fetch,
  scheduled: async (_event: ScheduledController, env: Env, _ctx: ExecutionContext) => {
    const result = await reconcileRefunds(env);
    console.log(
      `[cron] reconcile result scanned=${result.scanned} fetched=${result.fetched} revoked=${result.revoked} errors=${result.errors}`,
    );
  },
};
