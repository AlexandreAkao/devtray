import type { Env } from "../types";
import { getLicense, putLicense } from "../lib/kv";

export async function handleAdminReleaseAll(req: Request, env: Env): Promise<Response> {
  const provided = req.headers.get("X-Admin-Token") ?? "";
  if (!constantTimeEqual(provided, env.ADMIN_TOKEN)) {
    return new Response("unauthorized", { status: 401 });
  }

  let body: { license_uuid?: string };
  try { body = await req.json(); }
  catch { return Response.json({ error: "malformed_json" }, { status: 400 }); }

  if (typeof body.license_uuid !== "string") {
    return Response.json({ error: "missing_license_uuid" }, { status: 400 });
  }

  const record = await getLicense(env, body.license_uuid);
  if (!record) return Response.json({ error: "not_found" }, { status: 404 });

  const before = record.activations.length;
  record.activations = [];
  await putLicense(env, body.license_uuid, record);

  console.log(`[admin] release-all license=${body.license_uuid} cleared=${before}`);
  return Response.json({ ok: true, cleared: before });
}

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
