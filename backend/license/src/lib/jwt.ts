import * as ed from "@noble/ed25519";
import { sha512 } from "@noble/hashes/sha512";

// Required by @noble/ed25519 v2 — wire SHA-512 once at module load.
ed.etc.sha512Sync = (...m) => sha512(ed.etc.concatBytes(...m));

export type Claims = {
  iss: string;
  sub: string;
  email: string;
  iat: number;
  tier: string;
};

const PREFIX = "DT1-";

const enc = new TextEncoder();
const dec = new TextDecoder();

function b64urlEncode(data: Uint8Array): string {
  return btoa(String.fromCharCode(...data))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function b64urlDecode(s: string): Uint8Array {
  const pad = s.length % 4 === 0 ? 0 : 4 - (s.length % 4);
  const padded = s + "=".repeat(pad);
  const std = padded.replaceAll("-", "+").replaceAll("_", "/");
  const bin = atob(std);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export async function signLicense(claims: Claims, privateKey: Uint8Array): Promise<string> {
  const header = b64urlEncode(enc.encode(JSON.stringify({ alg: "EdDSA", typ: "JWT" })));
  const payload = b64urlEncode(enc.encode(JSON.stringify(claims)));
  const signingInput = `${header}.${payload}`;
  const sig = await ed.signAsync(enc.encode(signingInput), privateKey);
  const sigB64 = b64urlEncode(sig);
  return `${PREFIX}${header}.${payload}.${sigB64}`;
}

export async function verifyLicense(token: string, publicKey: Uint8Array): Promise<Claims> {
  if (!token.startsWith(PREFIX)) throw new Error("unsupported schema");
  const jwt = token.slice(PREFIX.length);
  const segments = jwt.split(".");
  if (segments.length !== 3) throw new Error("malformed token");

  const [headerB64, payloadB64, sigB64] = segments;
  const header = JSON.parse(dec.decode(b64urlDecode(headerB64!))) as { alg?: string; typ?: string };
  if (header.alg !== "EdDSA" || header.typ !== "JWT") {
    throw new Error("invalid alg or typ");
  }

  const sig = b64urlDecode(sigB64!);
  const signingInput = enc.encode(`${headerB64}.${payloadB64}`);
  const ok = await ed.verifyAsync(sig, signingInput, publicKey);
  if (!ok) throw new Error("invalid signature");

  const claims = JSON.parse(dec.decode(b64urlDecode(payloadB64!))) as Claims;
  if (claims.tier !== "v1") throw new Error("unsupported tier");
  return claims;
}
