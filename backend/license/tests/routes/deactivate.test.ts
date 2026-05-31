import { describe, it, expect, beforeAll } from "vitest";
import { env } from "cloudflare:test";
import * as ed from "@noble/ed25519";
import { sha512 } from "@noble/hashes/sha512";
import { signLicense } from "../../src/lib/jwt";
import { putLicense } from "../../src/lib/kv";
import { handleDeactivate } from "../../src/routes/deactivate";
import type { LicenseRecord } from "../../src/types";

ed.etc.sha512Sync = (...m) => sha512(ed.etc.concatBytes(...m));

describe("routes/deactivate", () => {
  let priv: Uint8Array;
  let token: string;
  const licenseUuid = "66666666-6666-6666-6666-666666666666";

  beforeAll(async () => {
    priv = ed.utils.randomPrivateKey();
    (env as any).LICENSE_PRIVATE_KEY = btoa(String.fromCharCode(...priv));
    (env as any).LICENSE_ISS = "api.devtray.app";
    token = await signLicense({
      iss: "api.devtray.app", sub: licenseUuid,
      email: "a@b.com", iat: 1, tier: "v1"
    }, priv);
    const record: LicenseRecord = {
      user_email: "a@b.com", created_at: 1,
      activations: [
        { machine_hash: "hA", activated_at: 1 },
        { machine_hash: "hB", activated_at: 2 },
      ],
      revoked: false, test_mode: false, paddle_transaction_id: "o1",
    };
    await putLicense(env as any, licenseUuid, record);
  });

  async function call(body: object) {
    return handleDeactivate(new Request("http://w/deactivate", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    }), env as any);
  }

  it("200 + frees slot for known machine", async () => {
    const res = await call({ license_jwt: token, machine_hash: "hA" });
    expect(res.status).toBe(200);
    const rec = (await env.LICENSES.get(licenseUuid, "json")) as LicenseRecord;
    expect(rec.activations.map((a) => a.machine_hash)).toEqual(["hB"]);
  });

  it("404 for unknown license", async () => {
    const other = await signLicense({
      iss: "api.devtray.app", sub: "77777777-7777-7777-7777-777777777777",
      email: "x@x.com", iat: 1, tier: "v1"
    }, priv);
    const res = await call({ license_jwt: other, machine_hash: "z" });
    expect(res.status).toBe(404);
  });

  it("400 on malformed jwt", async () => {
    const res = await call({ license_jwt: "junk", machine_hash: "z" });
    expect(res.status).toBe(400);
  });
});
