import type { Env, LicenseRecord } from "../types";
import { verifyHmac } from "../lib/hmac";
import { wasEventProcessed, markEventProcessed, putLicense, licenseNamespace } from "../lib/kv";
import { signLicense } from "../lib/jwt";
import { sendLicenseEmail } from "../lib/email";

type FetchImpl = typeof fetch;

type LSEvent = {
  meta: {
    event_name: "order_created" | "order_refunded" | string;
    // LS payloads use `webhook_id` (per-delivery, not stable across retries). Some
    // synthetic tests still pass `event_id`; we prefer it when present, otherwise
    // derive a stable idempotency key from event_name + data.id.
    event_id?: string;
    webhook_id?: string;
    test_mode: boolean;
  };
  data: {
    id: string;  // order_id
    attributes: {
      user_email?: string;
      [k: string]: unknown;
    };
  };
};

export async function handleWebhook(req: Request, env: Env, fetchImpl: FetchImpl = fetch): Promise<Response> {
  const rawBody = await req.text();
  const sig = req.headers.get("X-Signature") ?? "";

  const valid = await verifyHmac(rawBody, sig, env.LEMONSQUEEZY_WEBHOOK_SECRET);
  if (!valid) {
    return new Response("unauthorized", { status: 401 });
  }

  let event: LSEvent;
  try {
    event = JSON.parse(rawBody) as LSEvent;
  } catch {
    return new Response("malformed json", { status: 400 });
  }

  // Derive a stable idempotency key. LS retries reuse the same event_name + data.id
  // but get a fresh webhook_id per attempt, so webhook_id is NOT safe for idempotency.
  const eventId = event.meta?.event_id
    ?? (event.meta?.event_name && event.data?.id
        ? `${event.meta.event_name}:${event.data.id}`
        : null);
  if (!eventId) return new Response("missing event identifier", { status: 400 });

  if (await wasEventProcessed(env, eventId)) {
    console.log(`[webhook] skip duplicate event_id=${eventId}`);
    return new Response("ok (duplicate)", { status: 200 });
  }

  switch (event.meta.event_name) {
    case "order_created":
      return mintLicense(event, env, eventId, fetchImpl);
    case "order_refunded":
      return revokeByOrderId(event, env, eventId);
    default:
      // Unknown event: mark processed (idempotent) and return 200.
      await markEventProcessed(env, eventId, "skipped");
      return new Response("ok (ignored)", { status: 200 });
  }
}

async function mintLicense(event: LSEvent, env: Env, eventId: string, fetchImpl: FetchImpl): Promise<Response> {
  const email = event.data.attributes.user_email;
  if (typeof email !== "string") {
    return new Response("missing user_email", { status: 400 });
  }
  const orderId = event.data.id;
  const testMode = event.meta.test_mode === true;
  const licenseUuid = crypto.randomUUID();
  const now = Math.floor(Date.now() / 1000);

  const priv = decodeBase64(env.LICENSE_PRIVATE_KEY);
  const token = await signLicense(
    { iss: env.LICENSE_ISS, sub: licenseUuid, email, iat: now, tier: "v1" },
    priv
  );

  const record: LicenseRecord = {
    user_email: email,
    created_at: now,
    activations: [],
    revoked: false,
    test_mode: testMode,
    ls_order_id: orderId,
  };
  await putLicense(env, licenseUuid, record);
  await markEventProcessed(env, eventId, "minted");

  await sendLicenseEmail({ apiKey: env.RESEND_API_KEY, to: email, licenseKey: token, fetchImpl });

  console.log(`[webhook] minted license=${licenseUuid} order=${orderId} test_mode=${testMode}`);
  return new Response("ok", { status: 200 });
}

async function revokeByOrderId(event: LSEvent, env: Env, eventId: string): Promise<Response> {
  const orderId = event.data.id;
  const testMode = event.meta.test_mode === true;
  const ns = licenseNamespace(env, testMode);

  // KV has no secondary index; we list + scan. License count is low (≤100s for v0.11) so this is fine.
  const list = await ns.list();
  for (const key of list.keys) {
    const rec = (await ns.get(key.name, "json")) as LicenseRecord | null;
    if (rec && rec.ls_order_id === orderId) {
      rec.revoked = true;
      await ns.put(key.name, JSON.stringify(rec));
      console.log(`[webhook] revoked license=${key.name} order=${orderId}`);
    }
  }
  await markEventProcessed(env, eventId, "revoked");
  return new Response("ok", { status: 200 });
}

function decodeBase64(s: string): Uint8Array {
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
