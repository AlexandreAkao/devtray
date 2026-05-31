import { describe, it, expect } from "vitest";
import { hmac } from "@noble/hashes/hmac";
import { sha256 } from "@noble/hashes/sha256";
import { parsePaddleSignature, verifyPaddleHmac } from "../../src/lib/hmac";

const SECRET = "pdl_ntfset_test";

function signPaddle(ts: number, body: string, secret: string): string {
  const tag = hmac(sha256, new TextEncoder().encode(secret), new TextEncoder().encode(`${ts}:${body}`));
  return Array.from(tag).map((b) => b.toString(16).padStart(2, "0")).join("");
}

describe("lib/hmac — Paddle", () => {
  describe("parsePaddleSignature", () => {
    it("parses valid header", () => {
      expect(parsePaddleSignature("ts=1717000000;h1=abc123")).toEqual({ ts: 1717000000, h1: "abc123" });
    });

    it("returns null on missing ts", () => {
      expect(parsePaddleSignature("h1=abc123")).toBeNull();
    });

    it("returns null on missing h1", () => {
      expect(parsePaddleSignature("ts=1717000000")).toBeNull();
    });

    it("returns null on empty header", () => {
      expect(parsePaddleSignature("")).toBeNull();
    });

    it("returns null on garbage", () => {
      expect(parsePaddleSignature("nonsense")).toBeNull();
    });

    it("ignores unknown keys but still parses ts/h1", () => {
      expect(parsePaddleSignature("ts=42;h1=ff;other=value")).toEqual({ ts: 42, h1: "ff" });
    });
  });

  describe("verifyPaddleHmac", () => {
    const body = JSON.stringify({ event_id: "evt_x", event_type: "transaction.completed" });
    const ts = 1717000000;
    const goodSig = signPaddle(ts, body, SECRET);

    it("accepts a valid signature", async () => {
      const header = `ts=${ts};h1=${goodSig}`;
      expect(await verifyPaddleHmac(body, header, SECRET)).toBe(true);
    });

    it("rejects tampered body", async () => {
      const header = `ts=${ts};h1=${goodSig}`;
      expect(await verifyPaddleHmac(body + "x", header, SECRET)).toBe(false);
    });

    it("rejects tampered ts", async () => {
      const header = `ts=${ts + 1};h1=${goodSig}`;
      expect(await verifyPaddleHmac(body, header, SECRET)).toBe(false);
    });

    it("rejects wrong secret", async () => {
      const header = `ts=${ts};h1=${goodSig}`;
      expect(await verifyPaddleHmac(body, header, "wrong-secret")).toBe(false);
    });

    it("rejects missing header", async () => {
      expect(await verifyPaddleHmac(body, "", SECRET)).toBe(false);
    });

    it("rejects malformed header", async () => {
      expect(await verifyPaddleHmac(body, "ts=foo;h1=bar", SECRET)).toBe(false);
    });
  });
});
