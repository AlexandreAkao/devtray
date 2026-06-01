import { describe, it, expect, beforeAll } from "vitest";
import { env } from "cloudflare:test";
import { handleBuy } from "../../src/routes/buy";

const PRICE_ID = "pri_01kt0gmf65bwx3906ysnqe3w0c";
const API_KEY = "pdl_apikey_test";
const CHECKOUT_URL = "https://pay.paddle.com/checkout/txn_01h_test";

type Recorded = { url: string; init?: RequestInit };

function makePaddleStub(opts: {
  status?: number;
  body?: unknown;
  throwError?: boolean;
} = {}) {
  const calls: Recorded[] = [];
  const impl = async (url: string | URL | Request, init?: RequestInit): Promise<Response> => {
    calls.push({ url: String(url), init });
    if (opts.throwError) {
      throw new Error("network down");
    }
    const status = opts.status ?? 200;
    const body = opts.body ?? {
      data: { id: "txn_01h_test", checkout: { url: CHECKOUT_URL } },
    };
    return new Response(typeof body === "string" ? body : JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json" },
    });
  };
  return { calls, impl };
}

describe("routes/buy", () => {
  beforeAll(() => {
    (env as any).PADDLE_API_KEY = API_KEY;
    (env as any).PADDLE_PRICE_ID = PRICE_ID;
    (env as any).PADDLE_API_BASE_URL = "https://api.paddle.com";
  });

  it("302 to checkout.url from Paddle transaction response", async () => {
    const stub = makePaddleStub();
    const res = await handleBuy(new Request("http://w/buy"), env as any, stub.impl as any);
    expect(res.status).toBe(302);
    expect(res.headers.get("Location")).toBe(CHECKOUT_URL);
    expect(stub.calls.length).toBe(1);
    expect(stub.calls[0]!.url).toBe("https://api.paddle.com/transactions");
  });

  it("uses POST + Bearer auth + price_id in body", async () => {
    const stub = makePaddleStub();
    await handleBuy(new Request("http://w/buy"), env as any, stub.impl as any);
    const call = stub.calls[0]!;
    expect((call.init as RequestInit).method).toBe("POST");
    const headers = new Headers((call.init as RequestInit).headers as HeadersInit);
    expect(headers.get("Authorization")).toBe(`Bearer ${API_KEY}`);
    expect(headers.get("Content-Type")).toBe("application/json");
    const body = JSON.parse((call.init as RequestInit).body as string);
    expect(body.items).toEqual([{ price_id: PRICE_ID, quantity: 1 }]);
    expect(body.collection_mode).toBe("automatic");
  });

  it("includes customer.email when ?email= present", async () => {
    const stub = makePaddleStub();
    await handleBuy(new Request("http://w/buy?email=buyer%40example.com"), env as any, stub.impl as any);
    const body = JSON.parse((stub.calls[0]!.init as RequestInit).body as string);
    expect(body.customer).toEqual({ email: "buyer@example.com" });
  });

  it("omits customer when no ?email=", async () => {
    const stub = makePaddleStub();
    await handleBuy(new Request("http://w/buy"), env as any, stub.impl as any);
    const body = JSON.parse((stub.calls[0]!.init as RequestInit).body as string);
    expect(body.customer).toBeUndefined();
  });

  it("uses PADDLE_API_BASE_URL override (sandbox path)", async () => {
    (env as any).PADDLE_API_BASE_URL = "https://sandbox-api.paddle.com";
    const stub = makePaddleStub();
    await handleBuy(new Request("http://w/buy"), env as any, stub.impl as any);
    expect(stub.calls[0]!.url).toBe("https://sandbox-api.paddle.com/transactions");
    (env as any).PADDLE_API_BASE_URL = "https://api.paddle.com"; // restore
  });

  it("defaults to https://api.paddle.com when PADDLE_API_BASE_URL is unset", async () => {
    delete (env as any).PADDLE_API_BASE_URL;
    const stub = makePaddleStub();
    await handleBuy(new Request("http://w/buy"), env as any, stub.impl as any);
    expect(stub.calls[0]!.url).toBe("https://api.paddle.com/transactions");
    (env as any).PADDLE_API_BASE_URL = "https://api.paddle.com"; // restore
  });

  it("500 when PADDLE_API_KEY is unset", async () => {
    (env as any).PADDLE_API_KEY = "";
    const stub = makePaddleStub();
    const res = await handleBuy(new Request("http://w/buy"), env as any, stub.impl as any);
    expect(res.status).toBe(500);
    expect(stub.calls.length).toBe(0);
    (env as any).PADDLE_API_KEY = API_KEY;
  });

  it("500 when PADDLE_PRICE_ID is unset", async () => {
    (env as any).PADDLE_PRICE_ID = "";
    const stub = makePaddleStub();
    const res = await handleBuy(new Request("http://w/buy"), env as any, stub.impl as any);
    expect(res.status).toBe(500);
    expect(stub.calls.length).toBe(0);
    (env as any).PADDLE_PRICE_ID = PRICE_ID;
  });

  it("502 when Paddle API returns non-2xx", async () => {
    const stub = makePaddleStub({ status: 422, body: { error: { code: "validation_error" } } });
    const res = await handleBuy(new Request("http://w/buy"), env as any, stub.impl as any);
    expect(res.status).toBe(502);
  });

  it("502 when Paddle response is missing data.checkout.url", async () => {
    const stub = makePaddleStub({ status: 200, body: { data: { id: "txn_x" } } });
    const res = await handleBuy(new Request("http://w/buy"), env as any, stub.impl as any);
    expect(res.status).toBe(502);
  });

  it("502 on network error", async () => {
    const stub = makePaddleStub({ throwError: true });
    const res = await handleBuy(new Request("http://w/buy"), env as any, stub.impl as any);
    expect(res.status).toBe(502);
  });
});
