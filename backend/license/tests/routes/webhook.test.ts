import { describe, it, expect, beforeAll } from "vitest";
import { env } from "cloudflare:test";
import { hmac } from "@noble/hashes/hmac";
import { sha256 } from "@noble/hashes/sha256";
import * as ed from "@noble/ed25519";
import { sha512 } from "@noble/hashes/sha512";
import { handleWebhook } from "../../src/routes/webhook";

ed.etc.sha512Sync = (...m) => sha512(ed.etc.concatBytes(...m));

const SECRET = "pdl_ntfset_test_secret";
const API_KEY = "pdl_apikey_test";

function paddleSign(ts: number, body: string, secret: string): string {
  const tag = hmac(sha256, new TextEncoder().encode(secret), new TextEncoder().encode(`${ts}:${body}`));
  return Array.from(tag).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function paddleHeader(body: string, secret: string, tsOverride?: number): string {
  const ts = tsOverride ?? Math.floor(Date.now() / 1000);
  return `ts=${ts};h1=${paddleSign(ts, body, secret)}`;
}

function transactionCompletedPayload(opts: {
  event_id: string;
  customer_id?: string;
  transaction_id: string;
}) {
  return JSON.stringify({
    event_id: opts.event_id,
    event_type: "transaction.completed",
    occurred_at: "2026-05-31T19:00:00Z",
    notification_id: `ntf_${opts.event_id}`,
    data: {
      id: opts.transaction_id,
      status: "completed",
      // Paddle Billing v1: webhooks carry only customer_id, not an inline
      // customer object. The handler must fetch the email via API.
      customer_id: opts.customer_id ?? "ctm_default",
      items: [{ price: { id: "pri_x", product_id: "pro_x" } }],
      details: { totals: { total: "1900", currency_code: "USD" } },
      origin: "web",
    },
  });
}

function adjustmentPayload(opts: {
  event_id: string;
  event_type?: "adjustment.created" | "adjustment.updated";
  adjustment_id?: string;
  transaction_id: string;
  action?: "refund" | "chargeback" | "credit" | "chargeback_reverse";
  status?: "pending_approval" | "approved" | "rejected";
}) {
  return JSON.stringify({
    event_id: opts.event_id,
    event_type: opts.event_type ?? "adjustment.created",
    occurred_at: "2026-05-31T19:30:00Z",
    notification_id: `ntf_${opts.event_id}`,
    data: {
      id: opts.adjustment_id ?? `adj_${opts.event_id}`,
      action: opts.action ?? "refund",
      transaction_id: opts.transaction_id,
      customer_id: "ctm_x",
      status: opts.status ?? "approved",
      origin: "api",
    },
  });
}

type RecordedCall = { url: string; init?: RequestInit };

type AdjStub = { id?: string; action: "refund" | "chargeback" | "credit" | string; status?: string };

/**
 * Stub fetch that:
 *  - returns the configured adjustments for GET /adjustments?transaction_id=… (per txn_id → adjustment array map)
 *  - returns the configured email for GET /customers/{id} (per customer_id → email map)
 *  - returns a 200 OK for any other URL (Resend, etc.)
 */
function makeStubFetch(opts: {
  customerEmails?: Record<string, string>;
  customerStatus?: number;
  adjustmentsByTxn?: Record<string, AdjStub[]>;  // NEW: txn_id → adjustments array (only approved ones, since we filter status=approved upstream)
  adjFailOn?: Set<string>;                        // NEW: txn_ids whose /adjustments query returns 500
  adjNetworkFail?: boolean;                       // NEW: throw on any /adjustments query
} = {}) {
  const calls: RecordedCall[] = [];
  const emails = opts.customerEmails ?? { ctm_default: "buyer@example.com" };
  const adjustmentsByTxn = opts.adjustmentsByTxn ?? {};
  const adjFailOn = opts.adjFailOn ?? new Set<string>();
  const impl = async (url: string | URL | Request, init?: RequestInit): Promise<Response> => {
    const urlStr = String(url);
    calls.push({ url: urlStr, init });

    // NEW: GET /adjustments?transaction_id=X&status=approved → { data: [...] } or 500 or throw
    if (urlStr.includes("/adjustments")) {
      if (opts.adjNetworkFail) throw new Error("network down");
      const u = new URL(urlStr);
      const txnId = u.searchParams.get("transaction_id") ?? "";
      if (adjFailOn.has(txnId)) {
        return new Response(JSON.stringify({ error: { code: "boom" } }), { status: 500 });
      }
      const items = adjustmentsByTxn[txnId] ?? [];
      return new Response(JSON.stringify({ data: items, meta: { pagination: { has_more: false } } }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }

    // GET /customers/{customer_id} → return { data: { email } }
    const m = urlStr.match(/\/customers\/([^/?]+)/);
    if (m) {
      const customerId = decodeURIComponent(m[1]!);
      const email = emails[customerId];
      const status = opts.customerStatus ?? (email ? 200 : 404);
      const body = email ? { data: { id: customerId, email } } : { error: { code: "customer_not_found" } };
      return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
    }

    // Anything else (Resend) → generic ok
    return new Response(JSON.stringify({ id: "msg_x" }), { status: 200 });
  };
  return { calls, impl };
}

describe("routes/webhook (Paddle)", () => {
  let priv: Uint8Array;

  beforeAll(async () => {
    priv = ed.utils.randomPrivateKey();
    (env as any).LICENSE_PRIVATE_KEY = btoa(String.fromCharCode(...priv));
    (env as any).PADDLE_NOTIFICATION_SECRET = SECRET;
    (env as any).PADDLE_API_KEY = API_KEY;
    (env as any).PADDLE_API_BASE_URL = "https://api.paddle.com";
    (env as any).RESEND_API_KEY = "re_test";
    (env as any).LICENSE_ISS = "api.devtray.app";
  });

  it("401 on missing signature header", async () => {
    const body = transactionCompletedPayload({ event_id: "evt_1", transaction_id: "txn_1" });
    const req = new Request("http://w/webhook", { method: "POST", body, headers: {} });
    const res = await handleWebhook(req, env as any, makeStubFetch().impl);
    expect(res.status).toBe(401);
  });

  it("401 on wrong signature", async () => {
    const body = transactionCompletedPayload({ event_id: "evt_2", transaction_id: "txn_2" });
    const req = new Request("http://w/webhook", {
      method: "POST",
      body,
      headers: { "Paddle-Signature": "ts=1717000000;h1=deadbeef" },
    });
    const res = await handleWebhook(req, env as any, makeStubFetch().impl);
    expect(res.status).toBe(401);
  });

  it("400 on malformed JSON", async () => {
    const body = "not-json{";
    const req = new Request("http://w/webhook", {
      method: "POST",
      body,
      headers: { "Paddle-Signature": paddleHeader(body, SECRET) },
    });
    const res = await handleWebhook(req, env as any, makeStubFetch().impl);
    expect(res.status).toBe(400);
  });

  it("400 on missing event_id", async () => {
    const body = JSON.stringify({ event_type: "transaction.completed", data: { id: "x", customer_id: "ctm_x" } });
    const req = new Request("http://w/webhook", {
      method: "POST",
      body,
      headers: { "Paddle-Signature": paddleHeader(body, SECRET) },
    });
    const res = await handleWebhook(req, env as any, makeStubFetch().impl);
    expect(res.status).toBe(400);
  });

  it("400 on missing customer_id", async () => {
    const body = JSON.stringify({
      event_id: "evt_no_customer_id",
      event_type: "transaction.completed",
      data: { id: "txn_x" },
    });
    const req = new Request("http://w/webhook", {
      method: "POST",
      body,
      headers: { "Paddle-Signature": paddleHeader(body, SECRET) },
    });
    const res = await handleWebhook(req, env as any, makeStubFetch().impl);
    expect(res.status).toBe(400);
  });

  it("502 when Paddle customer fetch fails (e.g. 404)", async () => {
    const body = transactionCompletedPayload({ event_id: "evt_no_email", customer_id: "ctm_unknown", transaction_id: "txn_x" });
    const stub = makeStubFetch({ customerEmails: {} }); // empty map → 404 on customer GET
    const req = new Request("http://w/webhook", {
      method: "POST",
      body,
      headers: { "Paddle-Signature": paddleHeader(body, SECRET) },
    });
    const res = await handleWebhook(req, env as any, stub.impl);
    expect(res.status).toBe(502);
  });

  it("200 + mints license on transaction.completed (resolves customer email via API)", async () => {
    const body = transactionCompletedPayload({
      event_id: "evt_3",
      customer_id: "ctm_buyer3",
      transaction_id: "txn_3",
    });
    const stub = makeStubFetch({ customerEmails: { ctm_buyer3: "buyer3@x.com" } });
    const req = new Request("http://w/webhook", {
      method: "POST",
      body,
      headers: { "Paddle-Signature": paddleHeader(body, SECRET) },
    });
    const res = await handleWebhook(req, env as any, stub.impl);
    expect(res.status).toBe(200);
    // Three fetches: adjustments GET + customer GET + Resend email
    expect(stub.calls.length).toBe(3);
    expect(stub.calls[0]!.url).toContain("/adjustments");
    expect(stub.calls[1]!.url).toBe("https://api.paddle.com/customers/ctm_buyer3");
    const customerCall = stub.calls[1]!;
    expect(new Headers((customerCall.init as RequestInit).headers as HeadersInit).get("Authorization")).toBe(`Bearer ${API_KEY}`);
    expect(stub.calls[2]!.url).toContain("resend.com");

    const keys = await env.LICENSES.list();
    expect(keys.keys.length).toBeGreaterThan(0);
  });

  it("idempotent — duplicate event_id is a no-op on second call", async () => {
    const body = transactionCompletedPayload({ event_id: "evt_dup", customer_id: "ctm_dup", transaction_id: "txn_dup" });
    const stub = makeStubFetch({ customerEmails: { ctm_dup: "dup@x.com" } });
    const make = () =>
      new Request("http://w/webhook", {
        method: "POST",
        body,
        headers: { "Paddle-Signature": paddleHeader(body, SECRET) },
      });
    await handleWebhook(make(), env as any, stub.impl);
    await handleWebhook(make(), env as any, stub.impl);
    // First call: adjustments GET + customer GET + Resend = 3 fetches. Second call: short-circuited by idempotency = 0 fetches.
    expect(stub.calls.length).toBe(3);
    expect(stub.calls[2]!.url).toContain("resend.com");
  });

  it("adjustment.created with status=pending_approval does NOT revoke (waits for approval)", async () => {
    const txnId = "txn_pending_1";
    const createBody = transactionCompletedPayload({ event_id: "evt_mint_pending", customer_id: "ctm_pending", transaction_id: txnId });
    const stub = makeStubFetch({ customerEmails: { ctm_pending: "p@x.com" } });
    await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body: createBody,
        headers: { "Paddle-Signature": paddleHeader(createBody, SECRET) },
      }),
      env as any,
      stub.impl,
    );

    const pendingBody = adjustmentPayload({
      event_id: "evt_pending",
      transaction_id: txnId,
      action: "refund",
      status: "pending_approval",
    });
    const res = await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body: pendingBody,
        headers: { "Paddle-Signature": paddleHeader(pendingBody, SECRET) },
      }),
      env as any,
      stub.impl,
    );
    expect(res.status).toBe(200);

    const records = await Promise.all(
      (await env.LICENSES.list()).keys.map(
        (k) => env.LICENSES.get(k.name, "json") as Promise<{ paddle_transaction_id?: string; revoked: boolean }>,
      ),
    );
    expect(records.find((r) => r?.paddle_transaction_id === txnId)?.revoked).toBe(false);
  });

  it("adjustment.created action=refund marks matching record revoked=true", async () => {
    const txnId = "txn_refund_1";
    const createBody = transactionCompletedPayload({ event_id: "evt_mint", customer_id: "ctm_refund1", transaction_id: txnId });
    const stub = makeStubFetch({ customerEmails: { ctm_refund1: "r@b.com" } });
    await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body: createBody,
        headers: { "Paddle-Signature": paddleHeader(createBody, SECRET) },
      }),
      env as any,
      stub.impl,
    );

    const refundBody = adjustmentPayload({ event_id: "evt_refund", transaction_id: txnId, action: "refund" });
    await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body: refundBody,
        headers: { "Paddle-Signature": paddleHeader(refundBody, SECRET) },
      }),
      env as any,
      stub.impl,
    );

    const keys = await env.LICENSES.list();
    const records = await Promise.all(
      keys.keys.map(
        (k) =>
          env.LICENSES.get(k.name, "json") as Promise<{
            paddle_transaction_id?: string;
            ls_order_id?: string;
            revoked: boolean;
          }>,
      ),
    );
    const refunded = records.find((r) => r?.paddle_transaction_id === txnId);
    expect(refunded?.revoked).toBe(true);
  });

  it("adjustment.created action=chargeback also revokes (same money-out outcome)", async () => {
    const txnId = "txn_cb_1";
    const createBody = transactionCompletedPayload({ event_id: "evt_mint_cb", customer_id: "ctm_cb", transaction_id: txnId });
    const stub = makeStubFetch({ customerEmails: { ctm_cb: "cb@x.com" } });
    await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body: createBody,
        headers: { "Paddle-Signature": paddleHeader(createBody, SECRET) },
      }),
      env as any,
      stub.impl,
    );

    const cbBody = adjustmentPayload({ event_id: "evt_cb", transaction_id: txnId, action: "chargeback" });
    await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body: cbBody,
        headers: { "Paddle-Signature": paddleHeader(cbBody, SECRET) },
      }),
      env as any,
      stub.impl,
    );

    const records = await Promise.all(
      (await env.LICENSES.list()).keys.map(
        (k) => env.LICENSES.get(k.name, "json") as Promise<{ paddle_transaction_id?: string; revoked: boolean }>,
      ),
    );
    expect(records.find((r) => r?.paddle_transaction_id === txnId)?.revoked).toBe(true);
  });

  it("adjustment.updated with status=approved revokes (live-account flow after Paddle approval)", async () => {
    const txnId = "txn_live_approved_1";
    const createBody = transactionCompletedPayload({ event_id: "evt_mint_live", customer_id: "ctm_live", transaction_id: txnId });
    const stub = makeStubFetch({ customerEmails: { ctm_live: "live@x.com" } });
    await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body: createBody,
        headers: { "Paddle-Signature": paddleHeader(createBody, SECRET) },
      }),
      env as any,
      stub.impl,
    );

    // Simulate the live flow: created with pending_approval (no revoke), then
    // updated to approved (revoke).
    const pendingBody = adjustmentPayload({
      event_id: "evt_live_pending",
      transaction_id: txnId,
      action: "refund",
      status: "pending_approval",
    });
    await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body: pendingBody,
        headers: { "Paddle-Signature": paddleHeader(pendingBody, SECRET) },
      }),
      env as any,
      stub.impl,
    );

    const approvedBody = adjustmentPayload({
      event_id: "evt_live_approved",
      event_type: "adjustment.updated",
      transaction_id: txnId,
      action: "refund",
      status: "approved",
    });
    await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body: approvedBody,
        headers: { "Paddle-Signature": paddleHeader(approvedBody, SECRET) },
      }),
      env as any,
      stub.impl,
    );

    const records = await Promise.all(
      (await env.LICENSES.list()).keys.map(
        (k) => env.LICENSES.get(k.name, "json") as Promise<{ paddle_transaction_id?: string; revoked: boolean }>,
      ),
    );
    expect(records.find((r) => r?.paddle_transaction_id === txnId)?.revoked).toBe(true);
  });

  it("adjustment.updated with status=rejected does NOT revoke", async () => {
    const txnId = "txn_rejected_1";
    const createBody = transactionCompletedPayload({ event_id: "evt_mint_rej", customer_id: "ctm_rej", transaction_id: txnId });
    const stub = makeStubFetch({ customerEmails: { ctm_rej: "rej@x.com" } });
    await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body: createBody,
        headers: { "Paddle-Signature": paddleHeader(createBody, SECRET) },
      }),
      env as any,
      stub.impl,
    );

    const rejectedBody = adjustmentPayload({
      event_id: "evt_rej",
      event_type: "adjustment.updated",
      transaction_id: txnId,
      action: "refund",
      status: "rejected",
    });
    const res = await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body: rejectedBody,
        headers: { "Paddle-Signature": paddleHeader(rejectedBody, SECRET) },
      }),
      env as any,
      stub.impl,
    );
    expect(res.status).toBe(200);

    const records = await Promise.all(
      (await env.LICENSES.list()).keys.map(
        (k) => env.LICENSES.get(k.name, "json") as Promise<{ paddle_transaction_id?: string; revoked: boolean }>,
      ),
    );
    expect(records.find((r) => r?.paddle_transaction_id === txnId)?.revoked).toBe(false);
  });

  it("adjustment.created action=credit is ignored (no revoke)", async () => {
    const txnId = "txn_credit_1";
    const createBody = transactionCompletedPayload({ event_id: "evt_mint_credit", customer_id: "ctm_credit", transaction_id: txnId });
    const stub = makeStubFetch({ customerEmails: { ctm_credit: "credit@x.com" } });
    await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body: createBody,
        headers: { "Paddle-Signature": paddleHeader(createBody, SECRET) },
      }),
      env as any,
      stub.impl,
    );

    const creditBody = adjustmentPayload({ event_id: "evt_credit", transaction_id: txnId, action: "credit" });
    const res = await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body: creditBody,
        headers: { "Paddle-Signature": paddleHeader(creditBody, SECRET) },
      }),
      env as any,
      stub.impl,
    );
    expect(res.status).toBe(200);

    const records = await Promise.all(
      (await env.LICENSES.list()).keys.map(
        (k) => env.LICENSES.get(k.name, "json") as Promise<{ paddle_transaction_id?: string; revoked: boolean }>,
      ),
    );
    expect(records.find((r) => r?.paddle_transaction_id === txnId)?.revoked).toBe(false);
  });

  it("refund matches legacy ls_order_id records (one-cycle transition fallback)", async () => {
    const orderId = "ord_legacy_1";
    const legacyUuid = "uuid-legacy-1";
    await env.LICENSES.put(
      legacyUuid,
      JSON.stringify({
        user_email: "legacy@x.com",
        created_at: 1_748_500_000,
        activations: [],
        revoked: false,
        test_mode: false,
        ls_order_id: orderId,
      }),
    );

    const refundBody = adjustmentPayload({ event_id: "evt_refund_legacy", transaction_id: orderId, action: "refund" });
    const stub = makeStubFetch();
    await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body: refundBody,
        headers: { "Paddle-Signature": paddleHeader(refundBody, SECRET) },
      }),
      env as any,
      stub.impl,
    );

    const got = (await env.LICENSES.get(legacyUuid, "json")) as { revoked: boolean } | null;
    expect(got?.revoked).toBe(true);
  });

  it("pre-mint guard: persists record as revoked=true when an approved refund adjustment exists, skips email", async () => {
    const txnId = "txn_prerefund_1";
    const body = transactionCompletedPayload({
      event_id: "evt_prerefund",
      customer_id: "ctm_prerefund",
      transaction_id: txnId,
    });
    const stub = makeStubFetch({
      customerEmails: { ctm_prerefund: "pre@x.com" },
      adjustmentsByTxn: { [txnId]: [{ id: "adj_pre_1", action: "refund", status: "approved" }] },
    });
    const res = await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body,
        headers: { "Paddle-Signature": paddleHeader(body, SECRET) },
      }),
      env as any,
      stub.impl,
    );
    expect(res.status).toBe(200);

    // NO Resend call: refund was detected so email was suppressed.
    const resendCalls = stub.calls.filter((c) => c.url.includes("resend.com"));
    expect(resendCalls.length).toBe(0);

    // Adjustments query DID happen — confirm we hit the right URL with the right filters.
    const adjCalls = stub.calls.filter((c) => c.url.includes("/adjustments"));
    expect(adjCalls.length).toBe(1);
    expect(adjCalls[0]!.url).toContain(`transaction_id=${encodeURIComponent(txnId)}`);
    expect(adjCalls[0]!.url).toContain("status=approved");

    const records = await Promise.all(
      (await env.LICENSES.list()).keys.map(
        (k) => env.LICENSES.get(k.name, "json") as Promise<{ paddle_transaction_id?: string; revoked: boolean }>,
      ),
    );
    const minted = records.find((r) => r?.paddle_transaction_id === txnId);
    expect(minted).toBeDefined();
    expect(minted?.revoked).toBe(true);
  });

  it("pre-mint guard: persists record as revoked=true when an approved chargeback adjustment exists", async () => {
    const txnId = "txn_precb_1";
    const body = transactionCompletedPayload({
      event_id: "evt_precb",
      customer_id: "ctm_precb",
      transaction_id: txnId,
    });
    const stub = makeStubFetch({
      customerEmails: { ctm_precb: "cb@x.com" },
      adjustmentsByTxn: { [txnId]: [{ id: "adj_cb_1", action: "chargeback", status: "approved" }] },
    });
    await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body,
        headers: { "Paddle-Signature": paddleHeader(body, SECRET) },
      }),
      env as any,
      stub.impl,
    );
    const records = await Promise.all(
      (await env.LICENSES.list()).keys.map(
        (k) => env.LICENSES.get(k.name, "json") as Promise<{ paddle_transaction_id?: string; revoked: boolean }>,
      ),
    );
    expect(records.find((r) => r?.paddle_transaction_id === txnId)?.revoked).toBe(true);
  });

  it("pre-mint guard: fails OPEN when adjustments fetch errors (mint proceeds normally)", async () => {
    const txnId = "txn_fopen_1";
    const body = transactionCompletedPayload({
      event_id: "evt_fopen",
      customer_id: "ctm_fopen",
      transaction_id: txnId,
    });
    const stub = makeStubFetch({
      customerEmails: { ctm_fopen: "fo@x.com" },
      adjFailOn: new Set([txnId]),
    });
    const res = await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body,
        headers: { "Paddle-Signature": paddleHeader(body, SECRET) },
      }),
      env as any,
      stub.impl,
    );
    expect(res.status).toBe(200);

    // Resend was called — mint proceeded normally because we treat null as "unknown, fail open"
    const resendCalls = stub.calls.filter((c) => c.url.includes("resend.com"));
    expect(resendCalls.length).toBe(1);

    const records = await Promise.all(
      (await env.LICENSES.list()).keys.map(
        (k) => env.LICENSES.get(k.name, "json") as Promise<{ paddle_transaction_id?: string; revoked: boolean }>,
      ),
    );
    expect(records.find((r) => r?.paddle_transaction_id === txnId)?.revoked).toBe(false);
  });

  it("e2e routing: txn_e2e_* prefix lands the record in LICENSES_TEST + skips Paddle/email", async () => {
    const txnId = "txn_e2e_aaaaaaaaaaaaaaaa";
    const body = transactionCompletedPayload({
      event_id: "evt_e2e_mint",
      customer_id: "ctm_doesnt_matter",
      transaction_id: txnId,
    });
    const stub = makeStubFetch({});
    const res = await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body,
        headers: { "Paddle-Signature": paddleHeader(body, SECRET) },
      }),
      env as any,
      stub.impl,
    );
    expect(res.status).toBe(200);
    // No Paddle API calls, no Resend call: stub.calls is empty.
    expect(stub.calls.length).toBe(0);

    // Record landed in LICENSES_TEST, NOT LICENSES.
    const testKeys = await env.LICENSES_TEST.list();
    const liveKeys = await env.LICENSES.list();
    const testRecs = await Promise.all(
      testKeys.keys.map(
        (k) => env.LICENSES_TEST.get(k.name, "json") as Promise<{ paddle_transaction_id?: string; test_mode: boolean; user_email: string }>,
      ),
    );
    const matchTest = testRecs.find((r) => r?.paddle_transaction_id === txnId);
    expect(matchTest).toBeDefined();
    expect(matchTest?.test_mode).toBe(true);
    expect(matchTest?.user_email).toBe("e2e@devtray.app");
    const liveRecs = await Promise.all(
      liveKeys.keys.map(
        (k) => env.LICENSES.get(k.name, "json") as Promise<{ paddle_transaction_id?: string }>,
      ),
    );
    expect(liveRecs.find((r) => r?.paddle_transaction_id === txnId)).toBeUndefined();
  });

  it("e2e routing: adjustment.updated approved for txn_e2e_* revokes in LICENSES_TEST", async () => {
    const txnId = "txn_e2e_bbbbbbbbbbbbbbbb";
    const mintBody = transactionCompletedPayload({
      event_id: "evt_e2e_mint2",
      customer_id: "ctm_e2e_2",
      transaction_id: txnId,
    });
    const stub = makeStubFetch({});
    await handleWebhook(
      new Request("http://w/webhook", { method: "POST", body: mintBody, headers: { "Paddle-Signature": paddleHeader(mintBody, SECRET) } }),
      env as any,
      stub.impl,
    );

    const refundBody = adjustmentPayload({
      event_id: "evt_e2e_refund",
      event_type: "adjustment.updated",
      transaction_id: txnId,
      action: "refund",
      status: "approved",
    });
    await handleWebhook(
      new Request("http://w/webhook", { method: "POST", body: refundBody, headers: { "Paddle-Signature": paddleHeader(refundBody, SECRET) } }),
      env as any,
      stub.impl,
    );

    const testRecs = await Promise.all(
      (await env.LICENSES_TEST.list()).keys.map(
        (k) => env.LICENSES_TEST.get(k.name, "json") as Promise<{ paddle_transaction_id?: string; revoked: boolean }>,
      ),
    );
    expect(testRecs.find((r) => r?.paddle_transaction_id === txnId)?.revoked).toBe(true);
  });

  it("unknown event_type returns 200 (ignored) and marks event processed", async () => {
    const body = JSON.stringify({
      event_id: "evt_unknown",
      event_type: "subscription.created",
      data: { id: "sub_x" },
    });
    const stub = makeStubFetch();
    const req = new Request("http://w/webhook", {
      method: "POST",
      body,
      headers: { "Paddle-Signature": paddleHeader(body, SECRET) },
    });
    const res = await handleWebhook(req, env as any, stub.impl);
    expect(res.status).toBe(200);
    expect(stub.calls.length).toBe(0);
  });
});
