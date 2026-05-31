import { describe, it, expect, beforeAll } from "vitest";
import { env } from "cloudflare:test";
import { hmac } from "@noble/hashes/hmac";
import { sha256 } from "@noble/hashes/sha256";
import * as ed from "@noble/ed25519";
import { sha512 } from "@noble/hashes/sha512";
import { handleWebhook } from "../../src/routes/webhook";

ed.etc.sha512Sync = (...m) => sha512(ed.etc.concatBytes(...m));

const SECRET = "pdl_ntfset_test_secret";

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
  email: string;
  transaction_id: string;
  sandbox?: boolean;
}) {
  return JSON.stringify({
    event_id: opts.event_id,
    event_type: "transaction.completed",
    occurred_at: "2026-05-31T19:00:00Z",
    notification_id: `ntf_${opts.event_id}`,
    data: {
      id: opts.transaction_id,
      status: "completed",
      customer: { id: "ctm_x", email: opts.email },
      items: [{ price: { id: "pri_x", product_id: "pro_x" } }],
      details: { totals: { total: "1900", currency_code: "USD" } },
      origin: opts.sandbox ? "sandbox" : "production",
    },
  });
}

function transactionRefundedPayload(opts: {
  event_id: string;
  transaction_id: string;
  sandbox?: boolean;
}) {
  return JSON.stringify({
    event_id: opts.event_id,
    event_type: "transaction.refunded",
    occurred_at: "2026-05-31T19:30:00Z",
    notification_id: `ntf_${opts.event_id}`,
    data: {
      id: opts.transaction_id,
      status: "refunded",
      customer: { id: "ctm_x", email: "buyer@x.com" },
      items: [],
      details: { totals: { total: "1900", currency_code: "USD" } },
      origin: opts.sandbox ? "sandbox" : "production",
    },
  });
}

function makeStubFetch() {
  const calls: Array<{ url: string; init: RequestInit }> = [];
  const impl = async (url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), init: init! });
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
    (env as any).RESEND_API_KEY = "re_test";
    (env as any).LICENSE_ISS = "api.devtray.app";
  });

  it("401 on missing signature header", async () => {
    const body = transactionCompletedPayload({ event_id: "evt_1", email: "a@b.com", transaction_id: "txn_1" });
    const req = new Request("http://w/webhook", { method: "POST", body, headers: {} });
    const res = await handleWebhook(req, env as any, makeStubFetch().impl);
    expect(res.status).toBe(401);
  });

  it("401 on wrong signature", async () => {
    const body = transactionCompletedPayload({ event_id: "evt_2", email: "a@b.com", transaction_id: "txn_2" });
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
    const body = JSON.stringify({ event_type: "transaction.completed", data: { id: "x" } });
    const req = new Request("http://w/webhook", {
      method: "POST",
      body,
      headers: { "Paddle-Signature": paddleHeader(body, SECRET) },
    });
    const res = await handleWebhook(req, env as any, makeStubFetch().impl);
    expect(res.status).toBe(400);
  });

  it("400 on missing customer email", async () => {
    const body = JSON.stringify({
      event_id: "evt_no_email",
      event_type: "transaction.completed",
      data: { id: "txn_x", customer: {}, origin: "production" },
    });
    const req = new Request("http://w/webhook", {
      method: "POST",
      body,
      headers: { "Paddle-Signature": paddleHeader(body, SECRET) },
    });
    const res = await handleWebhook(req, env as any, makeStubFetch().impl);
    expect(res.status).toBe(400);
  });

  it("200 + mints license on transaction.completed (prod → LICENSES)", async () => {
    const body = transactionCompletedPayload({ event_id: "evt_3", email: "buyer@x.com", transaction_id: "txn_3" });
    const stub = makeStubFetch();
    const req = new Request("http://w/webhook", {
      method: "POST",
      body,
      headers: { "Paddle-Signature": paddleHeader(body, SECRET) },
    });
    const res = await handleWebhook(req, env as any, stub.impl);
    expect(res.status).toBe(200);
    expect(stub.calls.length).toBe(1);
    expect(stub.calls[0]!.url).toContain("resend.com");

    const keys = await env.LICENSES.list();
    expect(keys.keys.length).toBeGreaterThan(0);
  });

  it("idempotent — duplicate event_id is a no-op on second call", async () => {
    const body = transactionCompletedPayload({ event_id: "evt_dup", email: "x@x.com", transaction_id: "txn_dup" });
    const stub = makeStubFetch();
    const make = () =>
      new Request("http://w/webhook", {
        method: "POST",
        body,
        headers: { "Paddle-Signature": paddleHeader(body, SECRET) },
      });
    await handleWebhook(make(), env as any, stub.impl);
    await handleWebhook(make(), env as any, stub.impl);
    expect(stub.calls.length).toBe(1);
  });

  it("sandbox event routes to LICENSES_TEST", async () => {
    const body = transactionCompletedPayload({
      event_id: "evt_sandbox",
      email: "sandbox@x.com",
      transaction_id: "txn_sandbox",
      sandbox: true,
    });
    const stub = makeStubFetch();
    const req = new Request("http://w/webhook", {
      method: "POST",
      body,
      headers: { "Paddle-Signature": paddleHeader(body, SECRET) },
    });
    await handleWebhook(req, env as any, stub.impl);
    const testKeys = await env.LICENSES_TEST.list();
    expect(testKeys.keys.length).toBeGreaterThan(0);
  });

  it("transaction.refunded marks matching record revoked=true", async () => {
    const txnId = "txn_refund_1";
    const createBody = transactionCompletedPayload({ event_id: "evt_mint", email: "r@b.com", transaction_id: txnId });
    const stub = makeStubFetch();
    await handleWebhook(
      new Request("http://w/webhook", {
        method: "POST",
        body: createBody,
        headers: { "Paddle-Signature": paddleHeader(createBody, SECRET) },
      }),
      env as any,
      stub.impl,
    );

    const refundBody = transactionRefundedPayload({ event_id: "evt_refund", transaction_id: txnId });
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
      keys.keys.map((k) => env.LICENSES.get(k.name, "json") as Promise<{ paddle_transaction_id?: string; ls_order_id?: string; revoked: boolean }>),
    );
    const refunded = records.find((r) => r?.paddle_transaction_id === txnId);
    expect(refunded?.revoked).toBe(true);
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

    const refundBody = transactionRefundedPayload({ event_id: "evt_refund_legacy", transaction_id: orderId });
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

    const got = await env.LICENSES.get(legacyUuid, "json") as { revoked: boolean } | null;
    expect(got?.revoked).toBe(true);
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
