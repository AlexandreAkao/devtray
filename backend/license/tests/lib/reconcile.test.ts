import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { env } from "cloudflare:test";
import { reconcileRefunds } from "../../src/lib/reconcile";
import type { LicenseRecord } from "../../src/types";

const API_KEY = "pdl_apikey_test";
const NOW_MS = 1_780_000_000 * 1000;
const SECS_60 = 60;
const SECS_90D = 90 * 86400;

type Recorded = { url: string; init?: RequestInit };

function makePaddleStub(opts: { txStatuses?: Record<string, string>; failOn?: Set<string>; networkFail?: boolean } = {}) {
  const calls: Recorded[] = [];
  const statuses = opts.txStatuses ?? {};
  const fail = opts.failOn ?? new Set<string>();
  const impl = async (url: string | URL | Request, init?: RequestInit): Promise<Response> => {
    const urlStr = String(url);
    calls.push({ url: urlStr, init });
    if (opts.networkFail) throw new Error("network down");
    const m = urlStr.match(/\/transactions\/([^/?]+)/);
    if (!m) return new Response("not-found", { status: 404 });
    const txnId = decodeURIComponent(m[1]!);
    if (fail.has(txnId)) return new Response(JSON.stringify({ error: { code: "boom" } }), { status: 500 });
    const status = statuses[txnId];
    if (!status) return new Response(JSON.stringify({ error: { code: "not_found" } }), { status: 404 });
    return new Response(JSON.stringify({ data: { id: txnId, status } }), {
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
    const stub = makePaddleStub({ txStatuses: { txn_u1: "refunded" } });
    const result = await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
    expect(result.scanned).toBe(1);
    expect(result.fetched).toBe(0);
    expect(result.revoked).toBe(0);
    expect(stub.calls.length).toBe(0);
  });

  it("skips records older than 90 days", async () => {
    await seedLicense("u2", { created_at: Math.floor(NOW_MS / 1000) - (SECS_90D + 3600) });
    const stub = makePaddleStub({ txStatuses: { txn_u2: "refunded" } });
    const result = await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
    expect(result.fetched).toBe(0);
    expect(result.revoked).toBe(0);
  });

  it("skips records already revoked", async () => {
    await seedLicense("u3", { revoked: true });
    const stub = makePaddleStub({ txStatuses: { txn_u3: "refunded" } });
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

  it("revokes when Paddle returns status=refunded", async () => {
    await seedLicense("u5", {});
    const stub = makePaddleStub({ txStatuses: { txn_u5: "refunded" } });
    const result = await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
    expect(result.fetched).toBe(1);
    expect(result.revoked).toBe(1);
    const rec = (await env.LICENSES.get("u5", "json")) as LicenseRecord;
    expect(rec.revoked).toBe(true);
  });

  it("revokes when Paddle returns status=partially_refunded", async () => {
    await seedLicense("u6", {});
    const stub = makePaddleStub({ txStatuses: { txn_u6: "partially_refunded" } });
    const result = await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
    expect(result.revoked).toBe(1);
    const rec = (await env.LICENSES.get("u6", "json")) as LicenseRecord;
    expect(rec.revoked).toBe(true);
  });

  it("does NOT revoke when Paddle returns status=completed", async () => {
    await seedLicense("u7", {});
    const stub = makePaddleStub({ txStatuses: { txn_u7: "completed" } });
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
    const stub = makePaddleStub({ txStatuses: { txn_u10: "completed" } });
    await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
    expect(stub.calls.length).toBe(1);
    const headers = new Headers((stub.calls[0]!.init as RequestInit).headers as HeadersInit);
    expect(headers.get("Authorization")).toBe(`Bearer ${API_KEY}`);
  });

  it("hits the API base URL from PADDLE_API_BASE_URL (sandbox override)", async () => {
    (env as any).PADDLE_API_BASE_URL = "https://sandbox-api.paddle.com";
    await seedLicense("u11", {});
    const stub = makePaddleStub({ txStatuses: { txn_u11: "completed" } });
    await reconcileRefunds(env as any, stub.impl as any, NOW_MS);
    expect(stub.calls[0]!.url).toBe("https://sandbox-api.paddle.com/transactions/txn_u11");
    (env as any).PADDLE_API_BASE_URL = "https://api.paddle.com";
  });
});
