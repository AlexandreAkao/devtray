import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { env } from "cloudflare:test";
import { reconcileRefunds } from "../../src/lib/reconcile";
import type { LicenseRecord } from "../../src/types";

const API_KEY = "pdl_apikey_test";
const NOW_MS = 1_780_000_000 * 1000;
const SECS_60 = 60;
const SECS_90D = 90 * 86400;

type Recorded = { url: string; init?: RequestInit };

type AdjStub = { id?: string; action: "refund" | "chargeback" | "credit" | string };

function makePaddleStub(opts: {
  adjustmentsByTxn?: Record<string, AdjStub[]>;
  failOn?: Set<string>;        // txn_ids whose /adjustments query returns 500
  networkFail?: boolean;        // throw on any /adjustments query
} = {}) {
  const calls: Recorded[] = [];
  const adjustmentsByTxn = opts.adjustmentsByTxn ?? {};
  const fail = opts.failOn ?? new Set<string>();
  const impl = async (url: string | URL | Request, init?: RequestInit): Promise<Response> => {
    const urlStr = String(url);
    calls.push({ url: urlStr, init });
    if (opts.networkFail) throw new Error("network down");
    if (!urlStr.includes("/adjustments")) {
      return new Response("not-found", { status: 404 });
    }
    const u = new URL(urlStr);
    const txnId = u.searchParams.get("transaction_id") ?? "";
    if (fail.has(txnId)) {
      return new Response(JSON.stringify({ error: { code: "boom" } }), { status: 500 });
    }
    const items = adjustmentsByTxn[txnId] ?? [];
    return new Response(JSON.stringify({ data: items, meta: { pagination: { has_more: false } } }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  };
  return { calls, impl };
}

async function seedLicense(uuid: string, overrides: Partial<LicenseRecord>) {
  const rec: LicenseRecord = {
    user_email: "x@y.com",
    created_at: Math.floor(NOW_MS / 1000) - 3600, // default age: 1 hour old
    activations: [],
    revoked: false,
    test_mode: false,
    paddle_transaction_id: `txn_${uuid}`,
    ...overrides,
  };
  await env.LICENSES.put(uuid, JSON.stringify(rec));
}

describe("lib/reconcile", () => {
  beforeAll(() => {
    (env as any).PADDLE_API_KEY = API_KEY;
    (env as any).PADDLE_API_BASE_URL = "https://api.paddle.com";
  });

  beforeEach(async () => {
    // Clean the KV namespace before each test so seeded fixtures don't bleed.
    const list = await env.LICENSES.list();
    await Promise.all(list.keys.map((k) => env.LICENSES.delete(k.name)));
  });

  it("skips records younger than 60s", async () => {
    await seedLicense("u1", { created_at: Math.floor(NOW_MS / 1000) - 10 });
    const stub = makePaddleStub({ adjustmentsByTxn: { txn_u1: [{ id: "adj_u1", action: "refund" }] } });
    const result = await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
    expect(result.scanned).toBe(1);
    expect(result.fetched).toBe(0);
    expect(result.revoked).toBe(0);
    expect(stub.calls.length).toBe(0);
  });

  it("skips records older than 90 days", async () => {
    await seedLicense("u2", { created_at: Math.floor(NOW_MS / 1000) - (SECS_90D + 3600) });
    const stub = makePaddleStub({ adjustmentsByTxn: { txn_u2: [{ id: "adj_u2", action: "refund" }] } });
    const result = await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
    expect(result.fetched).toBe(0);
    expect(result.revoked).toBe(0);
  });

  it("skips records already revoked", async () => {
    await seedLicense("u3", { revoked: true });
    const stub = makePaddleStub({ adjustmentsByTxn: { txn_u3: [{ id: "adj_u3", action: "refund" }] } });
    const result = await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
    expect(result.fetched).toBe(0);
    expect(result.revoked).toBe(0);
  });

  it("skips records without paddle_transaction_id (legacy ls_order_id only)", async () => {
    await env.LICENSES.put("u4", JSON.stringify({
      user_email: "legacy@x.com",
      created_at: Math.floor(NOW_MS / 1000) - 3600,
      activations: [],
      revoked: false,
      test_mode: false,
      ls_order_id: "order_old",
    }));
    const stub = makePaddleStub();
    const result = await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
    expect(result.fetched).toBe(0);
    expect(stub.calls.length).toBe(0);
  });

  it("revokes when there is a refund adjustment", async () => {
    await seedLicense("u5", {});
    const stub = makePaddleStub({ adjustmentsByTxn: { txn_u5: [{ id: "adj_u5", action: "refund" }] } });
    const result = await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
    expect(result.fetched).toBe(1);
    expect(result.revoked).toBe(1);
    const rec = (await env.LICENSES.get("u5", "json")) as LicenseRecord;
    expect(rec.revoked).toBe(true);
  });

  // Paddle Adjustments do not have a separate "partial_refund" action — both partial
  // and full refunds carry action="refund"; the distinction lives in Adjustment totals,
  // not the action field. The test above covers that path; this test covers chargeback.
  it("revokes when there is a chargeback adjustment", async () => {
    await seedLicense("u6", {});
    const stub = makePaddleStub({ adjustmentsByTxn: { txn_u6: [{ id: "adj_u6", action: "chargeback" }] } });
    const result = await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
    expect(result.revoked).toBe(1);
    const rec = (await env.LICENSES.get("u6", "json")) as LicenseRecord;
    expect(rec.revoked).toBe(true);
  });

  it("does NOT revoke when there are no refund adjustments", async () => {
    await seedLicense("u7", {});
    const stub = makePaddleStub({ adjustmentsByTxn: {} });
    const result = await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
    expect(result.fetched).toBe(1);
    expect(result.revoked).toBe(0);
    const rec = (await env.LICENSES.get("u7", "json")) as LicenseRecord;
    expect(rec.revoked).toBe(false);
  });

  it("counts errors on non-2xx Paddle response without throwing", async () => {
    await seedLicense("u8", {});
    const stub = makePaddleStub({ failOn: new Set(["txn_u8"]) });
    const result = await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
    expect(result.errors).toBe(1);
    expect(result.revoked).toBe(0);
  });

  it("counts errors on fetch network error without throwing", async () => {
    await seedLicense("u9", {});
    const stub = makePaddleStub({ networkFail: true });
    const result = await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
    expect(result.errors).toBeGreaterThanOrEqual(1);
    expect(result.revoked).toBe(0);
  });

  it("sends Authorization Bearer with PADDLE_API_KEY", async () => {
    await seedLicense("u10", {});
    const stub = makePaddleStub({ adjustmentsByTxn: {} });
    await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
    expect(stub.calls.length).toBe(1);
    const headers = new Headers((stub.calls[0]!.init as RequestInit).headers as HeadersInit);
    expect(headers.get("Authorization")).toBe(`Bearer ${API_KEY}`);
  });

  it("hits the API base URL from PADDLE_API_BASE_URL (sandbox override)", async () => {
    (env as any).PADDLE_API_BASE_URL = "https://sandbox-api.paddle.com";
    await seedLicense("u11", {});
    const stub = makePaddleStub({ adjustmentsByTxn: {} });
    await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
    expect(stub.calls[0]!.url).toBe("https://sandbox-api.paddle.com/adjustments?transaction_id=txn_u11&status=approved&per_page=50");
    (env as any).PADDLE_API_BASE_URL = "https://api.paddle.com";
  });

  it("returns errors:1, scanned:0 when env.LICENSES.list() rejects (does not throw)", async () => {
    const original = env.LICENSES.list.bind(env.LICENSES);
    (env.LICENSES as any).list = () => Promise.reject(new Error("kv outage"));

    try {
      const stub = makePaddleStub();
      const result = await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
      expect(result.errors).toBe(1);
      expect(result.scanned).toBe(0);
      expect(result.fetched).toBe(0);
      expect(result.revoked).toBe(0);
    } finally {
      (env.LICENSES as any).list = original;
    }
  });
});
