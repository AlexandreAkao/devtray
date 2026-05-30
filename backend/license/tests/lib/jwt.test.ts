import { describe, it, expect, beforeAll } from "vitest";
import * as ed from "@noble/ed25519";
import { sha512 } from "@noble/hashes/sha512";
import { signLicense, verifyLicense, type Claims } from "../../src/lib/jwt";

// noble-ed25519 requires sha512 wiring on certain environments.
ed.etc.sha512Sync = (...m) => sha512(ed.etc.concatBytes(...m));

describe("lib/jwt", () => {
  let priv: Uint8Array;
  let pub: Uint8Array;
  const claims: Claims = {
    iss: "api.devtray.app",
    sub: "11111111-1111-1111-1111-111111111111",
    email: "buyer@example.com",
    iat: 1_748_560_000,
    tier: "v1",
  };

  beforeAll(async () => {
    priv = ed.utils.randomPrivateKey();
    pub = await ed.getPublicKeyAsync(priv);
  });

  it("signs + verifies round-trip", async () => {
    const token = await signLicense(claims, priv);
    expect(token.startsWith("DT1-")).toBe(true);
    const result = await verifyLicense(token, pub);
    expect(result).toEqual(claims);
  });

  it("rejects token without DT1- prefix", async () => {
    const token = await signLicense(claims, priv);
    const stripped = token.replace(/^DT1-/, "");
    await expect(verifyLicense(stripped, pub)).rejects.toThrow(/schema/i);
  });

  it("rejects token with alg=none", async () => {
    // Build a malicious token with alg=none + empty signature.
    const header = btoa(JSON.stringify({ alg: "none", typ: "JWT" }))
      .replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
    const payload = btoa(JSON.stringify(claims))
      .replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
    const bad = `DT1-${header}.${payload}.`;
    await expect(verifyLicense(bad, pub)).rejects.toThrow(/alg/i);
  });

  it("rejects token signed with different key", async () => {
    const otherPriv = ed.utils.randomPrivateKey();
    const token = await signLicense(claims, otherPriv);
    await expect(verifyLicense(token, pub)).rejects.toThrow(/signature/i);
  });

  it("rejects token with tier!=v1", async () => {
    const token = await signLicense({ ...claims, tier: "v2" }, priv);
    await expect(verifyLicense(token, pub)).rejects.toThrow(/tier/i);
  });
});
