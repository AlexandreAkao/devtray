import { describe, it, expect, beforeAll } from "vitest";
import { env } from "cloudflare:test";
import { putLicense } from "../../src/lib/kv";
import { handleStatus } from "../../src/routes/status";
import type { LicenseRecord } from "../../src/types";

describe("routes/status", () => {
  const licenseUuid = "88888888-8888-8888-8888-888888888888";

  beforeAll(async () => {
    const rec: LicenseRecord = {
      user_email: "a@b.com", created_at: 1,
      activations: [{ machine_hash: "hX", activated_at: 1 }],
      revoked: false, test_mode: false, paddle_transaction_id: "o",
    };
    await putLicense(env as any, licenseUuid, rec);
  });

  async function call(license: string | null, machine: string | null): Promise<Response> {
    const qp = new URLSearchParams();
    if (license !== null) qp.set("license", license);
    if (machine !== null) qp.set("machine", machine);
    return handleStatus(new Request(`http://w/status?${qp}`), env as any);
  }

  it("revoked:false for known + machine in activations", async () => {
    const res = await call(licenseUuid, "hX");
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ revoked: false });
  });

  it("revoked:true for known + machine NOT in activations", async () => {
    const res = await call(licenseUuid, "hOther");
    expect(await res.json()).toEqual({ revoked: true });
  });

  it("revoked:true for unknown license", async () => {
    const res = await call("00000000-0000-0000-0000-000000000000", "h");
    expect(await res.json()).toEqual({ revoked: true });
  });

  it("revoked:true when record.revoked=true", async () => {
    const rec = (await env.LICENSES.get(licenseUuid, "json")) as LicenseRecord;
    rec.revoked = true;
    await env.LICENSES.put(licenseUuid, JSON.stringify(rec));
    const res = await call(licenseUuid, "hX");
    expect(await res.json()).toEqual({ revoked: true });
    // reset for other tests:
    rec.revoked = false;
    await env.LICENSES.put(licenseUuid, JSON.stringify(rec));
  });

  it("400 on missing params", async () => {
    const res = await call(null, "h");
    expect(res.status).toBe(400);
  });
});
