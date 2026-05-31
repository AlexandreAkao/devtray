import { describe, it, expect, beforeAll } from "vitest";
import { env } from "cloudflare:test";
import { handleBuy } from "../../src/routes/buy";

const BASE_MAGIC = "https://pay.paddle.com/checkout/?_ptxn=ptxn_x&price_id=pri_test";

describe("routes/buy", () => {
  beforeAll(() => {
    (env as any).PADDLE_MAGIC_LINK_URL = BASE_MAGIC;
  });

  it("302 to PADDLE_MAGIC_LINK_URL on bare /buy", async () => {
    const res = await handleBuy(new Request("http://w/buy"), env as any);
    expect(res.status).toBe(302);
    expect(res.headers.get("Location")).toBe(BASE_MAGIC);
  });

  it("appends customer_email when ?email= present", async () => {
    const res = await handleBuy(new Request("http://w/buy?email=buyer%40example.com"), env as any);
    expect(res.status).toBe(302);
    const loc = res.headers.get("Location")!;
    expect(loc).toContain(BASE_MAGIC);
    expect(loc).toContain("customer_email=buyer%40example.com");
  });

  it("uses & separator when base URL already has a query string", async () => {
    const res = await handleBuy(new Request("http://w/buy?email=x%40y.com"), env as any);
    const loc = res.headers.get("Location")!;
    // Base has ?_ptxn=…; appended must use &, not ?
    expect(loc.endsWith("&customer_email=x%40y.com")).toBe(true);
  });

  it("uses ? separator when base URL has no query string", async () => {
    (env as any).PADDLE_MAGIC_LINK_URL = "https://pay.paddle.com/checkout/abc";
    const res = await handleBuy(new Request("http://w/buy?email=z%40q.com"), env as any);
    const loc = res.headers.get("Location")!;
    expect(loc).toBe("https://pay.paddle.com/checkout/abc?customer_email=z%40q.com");
    // Restore for sibling tests:
    (env as any).PADDLE_MAGIC_LINK_URL = BASE_MAGIC;
  });

  it("500 when PADDLE_MAGIC_LINK_URL is unset", async () => {
    (env as any).PADDLE_MAGIC_LINK_URL = "";
    const res = await handleBuy(new Request("http://w/buy"), env as any);
    expect(res.status).toBe(500);
    // Restore:
    (env as any).PADDLE_MAGIC_LINK_URL = BASE_MAGIC;
  });
});
