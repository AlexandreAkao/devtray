import { hmac } from "@noble/hashes/hmac";
import { sha256 } from "@noble/hashes/sha256";

/** Verifies an LS webhook signature in constant time. */
export async function verifyHmac(rawBody: string, providedHex: string, secret: string): Promise<boolean> {
  if (!providedHex) return false;
  if (!/^[0-9a-fA-F]+$/.test(providedHex)) return false;

  const expected = hmac(sha256, new TextEncoder().encode(secret), new TextEncoder().encode(rawBody));
  const expectedHex = Array.from(expected).map((b) => b.toString(16).padStart(2, "0")).join("");

  if (expectedHex.length !== providedHex.length) return false;

  let diff = 0;
  const a = expectedHex.toLowerCase();
  const b = providedHex.toLowerCase();
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
