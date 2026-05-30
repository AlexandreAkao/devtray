import { describe, it, expect } from "vitest";
import { hmac } from "@noble/hashes/hmac";
import { sha256 } from "@noble/hashes/sha256";
import { verifyHmac } from "../../src/lib/hmac";

function makeSig(body: string, secret: string): string {
  const tag = hmac(sha256, new TextEncoder().encode(secret), new TextEncoder().encode(body));
  return Array.from(tag).map((b) => b.toString(16).padStart(2, "0")).join("");
}

describe("lib/hmac", () => {
  const secret = "shhh";
  const body = '{"meta":{"event_name":"order_created"}}';

  it("accepts a correct signature", async () => {
    const sig = makeSig(body, secret);
    expect(await verifyHmac(body, sig, secret)).toBe(true);
  });

  it("rejects a wrong signature", async () => {
    const wrong = makeSig(body, "different-secret");
    expect(await verifyHmac(body, wrong, secret)).toBe(false);
  });

  it("rejects a malformed signature (not hex)", async () => {
    expect(await verifyHmac(body, "not-hex-zzzz", secret)).toBe(false);
  });

  it("rejects an empty signature", async () => {
    expect(await verifyHmac(body, "", secret)).toBe(false);
  });

  it("is body-sensitive (tampered body fails)", async () => {
    const sig = makeSig(body, secret);
    expect(await verifyHmac(body + "x", sig, secret)).toBe(false);
  });
});
