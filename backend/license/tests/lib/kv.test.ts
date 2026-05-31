import { describe, it, expect } from "vitest";
import { env } from "cloudflare:test";
import {
  getLicense,
  putLicense,
  wasEventProcessed,
  markEventProcessed,
  licenseNamespace,
} from "../../src/lib/kv";
import type { LicenseRecord } from "../../src/types";

const fixture = (overrides: Partial<LicenseRecord> = {}): LicenseRecord => ({
  user_email: "buyer@example.com",
  created_at: 1_748_560_000,
  activations: [],
  revoked: false,
  test_mode: false,
  paddle_transaction_id: "order_xxx",
  ...overrides,
});

describe("lib/kv", () => {
  it("put then get roundtrips", async () => {
    const id = "uuid-1";
    await putLicense(env, id, fixture());
    const got = await getLicense(env, id);
    expect(got).toEqual(fixture());
  });

  it("routes to LICENSES_TEST when test_mode", async () => {
    const id = "uuid-2";
    const rec = fixture({ test_mode: true });
    await putLicense(env, id, rec);
    // Live namespace should be empty:
    expect(await env.LICENSES.get(id)).toBeNull();
    // Test namespace should have it:
    expect(await env.LICENSES_TEST.get(id)).not.toBeNull();
  });

  it("getLicense returns null for unknown", async () => {
    expect(await getLicense(env, "nope")).toBeNull();
  });

  it("wasEventProcessed false on first call", async () => {
    expect(await wasEventProcessed(env, "ev-1")).toBe(false);
  });

  it("wasEventProcessed true after markEventProcessed", async () => {
    await markEventProcessed(env, "ev-2", "minted");
    expect(await wasEventProcessed(env, "ev-2")).toBe(true);
  });

  it("licenseNamespace selects test correctly", () => {
    expect(licenseNamespace(env, true)).toBe(env.LICENSES_TEST);
    expect(licenseNamespace(env, false)).toBe(env.LICENSES);
  });
});
