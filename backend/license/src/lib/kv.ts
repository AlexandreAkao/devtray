import type { Env, LicenseRecord, EventRecord } from "../types";

export function licenseNamespace(env: Env, testMode: boolean): KVNamespace {
  return testMode ? env.LICENSES_TEST : env.LICENSES;
}

/**
 * Normalize UUID to lowercase for KV key lookups. Backend mint uses
 * `crypto.randomUUID()` which is lowercase, but Swift clients send
 * `UUID.uuidString` which is uppercase — without normalization the heartbeat
 * GET /status query fails to find any license (returns revoked:true), causing
 * the app to silently clear the local license.
 */
function normalizeKey(uuid: string): string {
  return uuid.toLowerCase();
}

export async function getLicense(env: Env, licenseUuid: string): Promise<LicenseRecord | null> {
  const key = normalizeKey(licenseUuid);
  // We don't know test_mode yet; check live first, fall back to test.
  const live = await env.LICENSES.get(key, "json");
  if (live) return live as LicenseRecord;
  const test = await env.LICENSES_TEST.get(key, "json");
  return (test as LicenseRecord | null) ?? null;
}

export async function putLicense(env: Env, licenseUuid: string, record: LicenseRecord): Promise<void> {
  const ns = licenseNamespace(env, record.test_mode);
  await ns.put(normalizeKey(licenseUuid), JSON.stringify(record));
}

export async function wasEventProcessed(env: Env, eventId: string): Promise<boolean> {
  return (await env.EVENTS.get(eventId)) !== null;
}

export async function markEventProcessed(env: Env, eventId: string, outcome: EventRecord["outcome"]): Promise<void> {
  const rec: EventRecord = { processed_at: Math.floor(Date.now() / 1000), outcome };
  await env.EVENTS.put(eventId, JSON.stringify(rec), { expirationTtl: 7 * 86_400 });
}
