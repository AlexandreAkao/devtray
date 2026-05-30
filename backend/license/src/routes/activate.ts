import type { Env, LicenseRecord } from "../types";
import { verifyLicense } from "../lib/jwt";
import { getLicense, putLicense } from "../lib/kv";

const ACTIVATION_CAP = 3;

export async function handleActivate(req: Request, env: Env): Promise<Response> {
  let body: { license_jwt?: string; machine_hash?: string };
  try {
    body = await req.json();
  } catch {
    return jsonError(400, "malformed_json");
  }

  const jwt = body.license_jwt;
  const machineHash = body.machine_hash;
  if (typeof jwt !== "string" || typeof machineHash !== "string") {
    return jsonError(400, "missing_fields");
  }

  // Re-derive pubkey from private key (server-side double-check that this license was minted by us).
  const priv = decodeBase64(env.LICENSE_PRIVATE_KEY);
  const pub = await derivePublicKey(priv);

  let claims;
  try {
    claims = await verifyLicense(jwt, pub);
  } catch (e) {
    return jsonError(400, "invalid_jwt");
  }

  const record = await getLicense(env, claims.sub);
  if (!record) return jsonError(404, "not_found");

  if (record.revoked) return jsonError(403, "revoked");

  // Already activated for this machine? Silent no-op (same response shape).
  const existing = record.activations.find((a) => a.machine_hash === machineHash);
  if (existing) {
    return Response.json({
      ok: true,
      activations_remaining: ACTIVATION_CAP - record.activations.length,
    });
  }

  if (record.activations.length >= ACTIVATION_CAP) {
    return jsonError(403, "too_many_activations");
  }

  record.activations.push({ machine_hash: machineHash, activated_at: Math.floor(Date.now() / 1000) });
  await putLicense(env, claims.sub, record);

  console.log(`[activate] license=${claims.sub} machine=${machineHash.slice(0, 8)}… remaining=${ACTIVATION_CAP - record.activations.length}`);

  return Response.json({
    ok: true,
    activations_remaining: ACTIVATION_CAP - record.activations.length,
  });
}

function jsonError(status: number, error: string): Response {
  return Response.json({ ok: false, error }, { status });
}

function decodeBase64(s: string): Uint8Array {
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function derivePublicKey(priv: Uint8Array): Promise<Uint8Array> {
  const ed = await import("@noble/ed25519");
  return ed.getPublicKeyAsync(priv);
}
