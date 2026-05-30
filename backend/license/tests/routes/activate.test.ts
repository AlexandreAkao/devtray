import { describe, it, expect, beforeAll } from "vitest";
import { env } from "cloudflare:test";
import * as ed from "@noble/ed25519";
import { sha512 } from "@noble/hashes/sha512";
import { signLicense } from "../../src/lib/jwt";
import { handleActivate } from "../../src/routes/activate";
import { putLicense } from "../../src/lib/kv";
import type { LicenseRecord } from "../../src/types";

ed.etc.sha512Sync = (...m) => sha512(ed.etc.concatBytes(...m));

describe("routes/activate", () => {
  let priv: Uint8Array;
  let token: string;
  const licenseUuid = "55555555-5555-5555-5555-555555555555";

  beforeAll(async () => {
    priv = ed.utils.randomPrivateKey();
    (env as any).LICENSE_PRIVATE_KEY = btoa(String.fromCharCode(...priv));
    (env as any).LICENSE_ISS = "api.devtray.app";
    token = await signLicense({
      iss: "api.devtray.app", sub: licenseUuid,
      email: "a@b.com", iat: 1, tier: "v1"
    }, priv);

    const record: LicenseRecord = {
      user_email: "a@b.com",
      created_at: 1,
      activations: [],
      revoked: false,
      test_mode: false,
      ls_order_id: "o1",
    };
    await putLicense(env as any, licenseUuid, record);
  });

  async function callActivate(body: object): Promise<Response> {
    const req = new Request("http://w/activate", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    return handleActivate(req, env as any);
  }

  it("200 on first activation", async () => {
    const res = await callActivate({ license_jwt: token, machine_hash: "h1" });
    expect(res.status).toBe(200);
    const json = await res.json() as any;
    expect(json.ok).toBe(true);
    expect(json.activations_remaining).toBe(2);
  });

  it("200 no-op on re-activation of same machine", async () => {
    await callActivate({ license_jwt: token, machine_hash: "h1" });
    const res = await callActivate({ license_jwt: token, machine_hash: "h1" });
    expect(res.status).toBe(200);
    const json = await res.json() as any;
    expect(json.activations_remaining).toBe(2);  // unchanged
  });

  it("403 too_many_activations after 3 distinct machines", async () => {
    await callActivate({ license_jwt: token, machine_hash: "ma" });
    await callActivate({ license_jwt: token, machine_hash: "mb" });
    await callActivate({ license_jwt: token, machine_hash: "mc" });
    const res = await callActivate({ license_jwt: token, machine_hash: "md" });
    expect(res.status).toBe(403);
    const json = await res.json() as any;
    expect(json.error).toBe("too_many_activations");
  });

  it("404 on unknown license_jwt sub", async () => {
    const otherToken = await signLicense({
      iss: "api.devtray.app", sub: "99999999-9999-9999-9999-999999999999",
      email: "x@x.com", iat: 1, tier: "v1"
    }, priv);
    const res = await callActivate({ license_jwt: otherToken, machine_hash: "z" });
    expect(res.status).toBe(404);
  });

  it("400 on malformed jwt", async () => {
    const res = await callActivate({ license_jwt: "garbage", machine_hash: "z" });
    expect(res.status).toBe(400);
  });

  it("403 revoked when record.revoked=true", async () => {
    // mutate KV directly:
    const rec = (await env.LICENSES.get(licenseUuid, "json")) as LicenseRecord;
    rec.revoked = true;
    await env.LICENSES.put(licenseUuid, JSON.stringify(rec));
    const res = await callActivate({ license_jwt: token, machine_hash: "new" });
    expect(res.status).toBe(403);
    const json = await res.json() as any;
    expect(json.error).toBe("revoked");
  });
});
