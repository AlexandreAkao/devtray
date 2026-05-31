import { describe, it, expect, beforeAll } from "vitest";
import { env } from "cloudflare:test";
import { putLicense } from "../../src/lib/kv";
import { handleAdminReleaseAll } from "../../src/routes/admin";
import type { LicenseRecord } from "../../src/types";

describe("routes/admin", () => {
  const licenseUuid = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
  const ADMIN_TOKEN = "secret-admin";

  beforeAll(async () => {
    (env as any).ADMIN_TOKEN = ADMIN_TOKEN;
    const rec: LicenseRecord = {
      user_email: "a@b.com", created_at: 1,
      activations: [
        { machine_hash: "h1", activated_at: 1 },
        { machine_hash: "h2", activated_at: 2 },
        { machine_hash: "h3", activated_at: 3 },
      ],
      revoked: false, test_mode: false, paddle_transaction_id: "o1",
    };
    await putLicense(env as any, licenseUuid, rec);
  });

  async function call(token: string | null, body: object): Promise<Response> {
    const headers: Record<string, string> = { "Content-Type": "application/json" };
    if (token !== null) headers["X-Admin-Token"] = token;
    return handleAdminReleaseAll(
      new Request("http://w/admin/release-all", {
        method: "POST", headers, body: JSON.stringify(body),
      }),
      env as any
    );
  }

  it("401 without admin token", async () => {
    const res = await call(null, { license_uuid: licenseUuid });
    expect(res.status).toBe(401);
  });

  it("401 with wrong admin token", async () => {
    const res = await call("wrong", { license_uuid: licenseUuid });
    expect(res.status).toBe(401);
  });

  it("200 + clears activations with correct token", async () => {
    const res = await call(ADMIN_TOKEN, { license_uuid: licenseUuid });
    expect(res.status).toBe(200);
    const rec = (await env.LICENSES.get(licenseUuid, "json")) as LicenseRecord;
    expect(rec.activations).toEqual([]);
  });

  it("404 for unknown license", async () => {
    const res = await call(ADMIN_TOKEN, { license_uuid: "00000000-0000-0000-0000-000000000000" });
    expect(res.status).toBe(404);
  });
});
