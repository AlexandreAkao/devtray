import type { Env, LicenseRecord } from "../types";

type FetchImpl = typeof fetch;

const DEFAULT_API_BASE = "https://api.paddle.com";
const MIN_AGE_SEC = 60;             // skip just-minted (avoid mint vs poll race)
const MAX_AGE_SEC = 90 * 86400;     // skip past Paddle's refund window

export type ReconcileResult = {
  scanned: number;
  fetched: number;
  revoked: number;
  errors: number;
};

export async function reconcileRefunds(
  env: Env,
  fetchImpl: FetchImpl = fetch,
  nowMs: number = Date.now(),
): Promise<ReconcileResult> {
  const result: ReconcileResult = { scanned: 0, fetched: 0, revoked: 0, errors: 0 };
  const apiBase = env.PADDLE_API_BASE_URL || DEFAULT_API_BASE;
  const nowSec = nowMs / 1000;

  let list: Awaited<ReturnType<typeof env.LICENSES.list>>;
  try {
    list = await env.LICENSES.list();
  } catch (err) {
    console.error("[reconcile] KV list failed — aborting pass", err);
    result.errors = 1;
    return result;
  }
  if (list.list_complete === false) {
    console.warn("[reconcile] KV list truncated — some licenses skipped this pass");
  }

  for (const key of list.keys) {
    result.scanned++;
    const rec = (await env.LICENSES.get(key.name, "json")) as LicenseRecord | null;
    if (!rec) continue;
    if (rec.revoked) continue;
    if (!rec.paddle_transaction_id) continue;

    const age = nowSec - rec.created_at;
    if (age < MIN_AGE_SEC) continue;
    if (age > MAX_AGE_SEC) continue;

    result.fetched++;
    try {
      const url = `${apiBase}/adjustments?transaction_id=${encodeURIComponent(rec.paddle_transaction_id)}&status=approved&per_page=50`;
      const res = await fetchImpl(url, {
        headers: { Authorization: `Bearer ${env.PADDLE_API_KEY}` },
      });
      if (!res.ok) {
        result.errors++;
        const body = await res.text().catch(() => "<no body>");
        console.warn(`[reconcile] fetch failed license=${key.name} txn=${rec.paddle_transaction_id} status=${res.status} body=${body}`);
        continue;
      }
      const payload = (await res.json()) as { data?: Array<{ id?: string; action?: string }> };
      const items = payload?.data ?? [];
      const refundAdj = items.find((adj) => adj.action === "refund" || adj.action === "chargeback");
      if (refundAdj) {
        rec.revoked = true;
        await env.LICENSES.put(key.name, JSON.stringify(rec));
        result.revoked++;
        console.log(`[reconcile] revoked license=${key.name} txn=${rec.paddle_transaction_id} adjustment=${refundAdj.id} action=${refundAdj.action}`);
      }
    } catch (err) {
      result.errors++;
      console.error(`[reconcile] error license=${key.name} txn=${rec.paddle_transaction_id}`, err);
    }
  }

  return result;
}
