import { describe, it, expect, beforeAll } from "vitest";
import { env } from "cloudflare:test";
import { hmac } from "@noble/hashes/hmac";
import { sha256 } from "@noble/hashes/sha256";
import * as ed from "@noble/ed25519";
import { sha512 } from "@noble/hashes/sha512";
import { handleWebhook } from "../../src/routes/webhook";

ed.etc.sha512Sync = (...m) => sha512(ed.etc.concatBytes(...m));

const WEBHOOK_SECRET = "ls-secret";

function sign(body: string, secret: string): string {
  const tag = hmac(sha256, new TextEncoder().encode(secret), new TextEncoder().encode(body));
  return Array.from(tag).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function orderCreatedPayload(opts: { event_id: string; email: string; order_id: string; test_mode?: boolean }) {
  return JSON.stringify({
    meta: {
      event_name: "order_created",
      event_id: opts.event_id,
      test_mode: opts.test_mode ?? false,
    },
    data: {
      id: opts.order_id,
      attributes: { user_email: opts.email },
    },
  });
}

function refundedPayload(opts: { event_id: string; order_id: string; test_mode?: boolean }) {
  return JSON.stringify({
    meta: { event_name: "order_refunded", event_id: opts.event_id, test_mode: opts.test_mode ?? false },
    data: { id: opts.order_id, attributes: {} },
  });
}

describe("routes/webhook", () => {
  let priv: Uint8Array;

  beforeAll(async () => {
    priv = ed.utils.randomPrivateKey();
    (env as any).LICENSE_PRIVATE_KEY = btoa(String.fromCharCode(...priv));
    (env as any).LEMONSQUEEZY_WEBHOOK_SECRET = WEBHOOK_SECRET;
    (env as any).RESEND_API_KEY = "re_test";
    (env as any).LICENSE_ISS = "api.devtray.app";
  });

  it("401 on missing signature", async () => {
    const body = orderCreatedPayload({ event_id: "ev1", email: "a@b.com", order_id: "o1" });
    const req = new Request("http://w/webhook", { method: "POST", body, headers: {} });
    const res = await handleWebhook(req, env as any, makeStubFetch().impl);
    expect(res.status).toBe(401);
  });

  it("401 on wrong signature", async () => {
    const body = orderCreatedPayload({ event_id: "ev2", email: "a@b.com", order_id: "o2" });
    const req = new Request("http://w/webhook", {
      method: "POST", body,
      headers: { "X-Signature": "deadbeef" }
    });
    const res = await handleWebhook(req, env as any, makeStubFetch().impl);
    expect(res.status).toBe(401);
  });

  it("200 + mints license on order_created", async () => {
    const body = orderCreatedPayload({ event_id: "ev3", email: "buyer@x.com", order_id: "o3" });
    const sig = sign(body, WEBHOOK_SECRET);
    const stubbed = makeStubFetch();
    const req = new Request("http://w/webhook", {
      method: "POST", body, headers: { "X-Signature": sig }
    });
    const res = await handleWebhook(req, env as any, stubbed.impl);
    expect(res.status).toBe(200);
    expect(stubbed.calls.length).toBe(1);
    expect(stubbed.calls[0]!.url).toContain("resend.com");

    // KV has a license now:
    const keys = await env.LICENSES.list();
    expect(keys.keys.length).toBeGreaterThan(0);
  });

  it("idempotent — same event_id is a no-op on second call", async () => {
    const body = orderCreatedPayload({ event_id: "ev-dup", email: "x@x.com", order_id: "o-dup" });
    const sig = sign(body, WEBHOOK_SECRET);
    const stubbed = makeStubFetch();
    const make = () => new Request("http://w/webhook", {
      method: "POST", body, headers: { "X-Signature": sig }
    });
    await handleWebhook(make(), env as any, stubbed.impl);
    await handleWebhook(make(), env as any, stubbed.impl);
    // Email sent only once:
    expect(stubbed.calls.length).toBe(1);
  });

  it("test_mode routes to LICENSES_TEST", async () => {
    const body = orderCreatedPayload({
      event_id: "ev-test", email: "test@x.com", order_id: "o-test", test_mode: true
    });
    const sig = sign(body, WEBHOOK_SECRET);
    const stubbed = makeStubFetch();
    const req = new Request("http://w/webhook", {
      method: "POST", body, headers: { "X-Signature": sig }
    });
    await handleWebhook(req, env as any, stubbed.impl);
    const testKeys = await env.LICENSES_TEST.list();
    expect(testKeys.keys.length).toBeGreaterThan(0);
  });

  it("order_refunded marks revoked=true", async () => {
    // First, mint a license:
    const orderId = "o-refund-1";
    const createBody = orderCreatedPayload({ event_id: "ev-mint", email: "a@b.com", order_id: orderId });
    const createSig = sign(createBody, WEBHOOK_SECRET);
    const stub = makeStubFetch();
    await handleWebhook(new Request("http://w/webhook", {
      method: "POST", body: createBody, headers: { "X-Signature": createSig }
    }), env as any, stub.impl);

    // Then refund it:
    const refundBody = refundedPayload({ event_id: "ev-refund", order_id: orderId });
    const refundSig = sign(refundBody, WEBHOOK_SECRET);
    await handleWebhook(new Request("http://w/webhook", {
      method: "POST", body: refundBody, headers: { "X-Signature": refundSig }
    }), env as any, stub.impl);

    const keys = await env.LICENSES.list();
    const matches = await Promise.all(
      keys.keys.map((k: { name: string }) => env.LICENSES.get(k.name, "json") as Promise<{ ls_order_id: string; revoked: boolean }>)
    );
    const refunded = matches.find((r: { ls_order_id: string; revoked: boolean }) => r.ls_order_id === orderId);
    expect(refunded?.revoked).toBe(true);
  });
});

function makeStubFetch() {
  const calls: Array<{ url: string; init: RequestInit }> = [];
  const impl = async (url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), init: init! });
    return new Response(JSON.stringify({ id: "msg_x" }), { status: 200 });
  };
  return { calls, impl };
}
