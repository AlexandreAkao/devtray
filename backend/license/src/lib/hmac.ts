import { hmac } from "@noble/hashes/hmac";
import { sha256 } from "@noble/hashes/sha256";

export type PaddleSignature = { ts: number; h1: string };

/**
 * Parses a Paddle webhook `Paddle-Signature` header of the form `ts=<unix>;h1=<hex>`.
 * Returns null on any parse failure (missing fields, non-numeric ts, etc.) — caller
 * treats null as auth failure.
 */
export function parsePaddleSignature(header: string): PaddleSignature | null {
  if (!header) return null;
  let ts: number | null = null;
  let h1: string | null = null;
  for (const part of header.split(";")) {
    const [k, v] = part.split("=", 2);
    if (k === "ts" && v) {
      const n = Number.parseInt(v, 10);
      if (Number.isFinite(n)) ts = n;
    } else if (k === "h1" && v) {
      h1 = v;
    }
  }
  if (ts === null || h1 === null) return null;
  return { ts, h1 };
}

/**
 * Verifies a Paddle webhook signature in constant time.
 * Signed input is `${ts}:${rawBody}` per Paddle Billing v1 spec.
 * Returns false on any parse/format/length/comparison failure.
 */
export async function verifyPaddleHmac(rawBody: string, header: string, secret: string): Promise<boolean> {
  const parsed = parsePaddleSignature(header);
  if (!parsed) return false;
  if (!/^[0-9a-fA-F]+$/.test(parsed.h1)) return false;

  const signed = `${parsed.ts}:${rawBody}`;
  const expected = hmac(sha256, new TextEncoder().encode(secret), new TextEncoder().encode(signed));
  const expectedHex = Array.from(expected).map((b) => b.toString(16).padStart(2, "0")).join("");

  if (expectedHex.length !== parsed.h1.length) return false;

  let diff = 0;
  const a = expectedHex.toLowerCase();
  const b = parsed.h1.toLowerCase();
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
