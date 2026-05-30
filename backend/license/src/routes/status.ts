import type { Env } from "../types";
import { getLicense } from "../lib/kv";

export async function handleStatus(req: Request, env: Env): Promise<Response> {
  const url = new URL(req.url);
  const license = url.searchParams.get("license");
  const machine = url.searchParams.get("machine");
  if (!license || !machine) {
    return Response.json({ error: "missing_params" }, { status: 400 });
  }

  const record = await getLicense(env, license);
  if (!record) return Response.json({ revoked: true });
  if (record.revoked) return Response.json({ revoked: true });

  const known = record.activations.some((a) => a.machine_hash === machine);
  return Response.json({ revoked: !known });
}
