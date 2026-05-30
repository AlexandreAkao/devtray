import type { Env } from "../types";
import { verifyLicense } from "../lib/jwt";
import { getLicense, putLicense } from "../lib/kv";

export async function handleDeactivate(req: Request, env: Env): Promise<Response> {
  let body: { license_jwt?: string; machine_hash?: string };
  try { body = await req.json(); }
  catch { return Response.json({ ok: false, error: "malformed_json" }, { status: 400 }); }

  const jwt = body.license_jwt;
  const machineHash = body.machine_hash;
  if (typeof jwt !== "string" || typeof machineHash !== "string") {
    return Response.json({ ok: false, error: "missing_fields" }, { status: 400 });
  }

  const priv = decodeBase64(env.LICENSE_PRIVATE_KEY);
  const ed = await import("@noble/ed25519");
  const pub = await ed.getPublicKeyAsync(priv);

  let claims;
  try { claims = await verifyLicense(jwt, pub); }
  catch { return Response.json({ ok: false, error: "invalid_jwt" }, { status: 400 }); }

  const record = await getLicense(env, claims.sub);
  if (!record) return Response.json({ ok: false, error: "not_found" }, { status: 404 });

  const before = record.activations.length;
  record.activations = record.activations.filter((a) => a.machine_hash !== machineHash);
  await putLicense(env, claims.sub, record);

  console.log(`[deactivate] license=${claims.sub} machine=${machineHash.slice(0, 8)}… (was ${before}, now ${record.activations.length})`);
  return Response.json({ ok: true });
}

function decodeBase64(s: string): Uint8Array {
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
