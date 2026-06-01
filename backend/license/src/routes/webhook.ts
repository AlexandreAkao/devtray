import type { Env, LicenseRecord } from "../types";
import { verifyPaddleHmac } from "../lib/hmac";
import { wasEventProcessed, markEventProcessed, putLicense, licenseNamespace } from "../lib/kv";
import { signLicense } from "../lib/jwt";
import { sendLicenseEmail } from "../lib/email";

type FetchImpl = typeof fetch;

type PaddleEvent = {
  event_id: string;
  event_type: "transaction.completed" | "adjustment.created" | string;
  occurred_at?: string;
  notification_id?: string;
  data: {
    id: string;
    status?: string;
    // Present on transaction.* events
    customer?: { id?: string; email?: string };
    items?: Array<{ price?: { id?: string; product_id?: string } }>;
    details?: { totals?: { total?: string; currency_code?: string } };
    // Present on adjustment.* events
    action?: "refund" | "chargeback" | "credit" | "chargeback_warning" | "chargeback_reverse" | "credit_reverse" | string;
    transaction_id?: string;
    customer_id?: string;
    // Sandbox-vs-prod marker. Paddle sandbox events carry origin = "sandbox".
    // Confirmed against the sandbox smoke run (T20). Adjust here if the actual
    // field name differs in your sandbox event.
    origin?: string;
    [k: string]: unknown;
  };
};

function isSandboxEvent(event: PaddleEvent): boolean {
  return event.data?.origin === "sandbox";
}

export async function handleWebhook(req: Request, env: Env, fetchImpl: FetchImpl = fetch): Promise<Response> {
  const rawBody = await req.text();
  const sig = req.headers.get("Paddle-Signature") ?? "";

  const valid = await verifyPaddleHmac(rawBody, sig, env.PADDLE_NOTIFICATION_SECRET);
  if (!valid) {
    return new Response("unauthorized", { status: 401 });
  }

  let event: PaddleEvent;
  try {
    event = JSON.parse(rawBody) as PaddleEvent;
  } catch {
    return new Response("malformed json", { status: 400 });
  }

  const eventId = event.event_id;
  if (!eventId) return new Response("missing event_id", { status: 400 });

  if (await wasEventProcessed(env, eventId)) {
    console.log(`[webhook] skip duplicate event_id=${eventId}`);
    return new Response("ok (duplicate)", { status: 200 });
  }

  switch (event.event_type) {
    case "transaction.completed":
      return mintLicense(event, env, eventId, fetchImpl);
    case "adjustment.created":
      // Paddle models refunds, chargebacks, credits as Adjustments. Only "refund"
      // (and "chargeback" — money clawed back same way) should revoke a license.
      // Credits don't return money so the license stays valid.
      if (event.data?.action === "refund" || event.data?.action === "chargeback") {
        return revokeByAdjustment(event, env, eventId);
      }
      await markEventProcessed(env, eventId, "skipped");
      return new Response("ok (ignored: non-refund adjustment)", { status: 200 });
    default:
      await markEventProcessed(env, eventId, "skipped");
      return new Response("ok (ignored)", { status: 200 });
  }
}

async function mintLicense(event: PaddleEvent, env: Env, eventId: string, fetchImpl: FetchImpl): Promise<Response> {
  const email = event.data?.customer?.email;
  if (typeof email !== "string") {
    return new Response("missing customer email", { status: 400 });
  }
  const transactionId = event.data.id;
  const testMode = isSandboxEvent(event);
  const licenseUuid = crypto.randomUUID();
  const now = Math.floor(Date.now() / 1000);

  const priv = decodeBase64(env.LICENSE_PRIVATE_KEY);
  const token = await signLicense(
    { iss: env.LICENSE_ISS, sub: licenseUuid, email, iat: now, tier: "v1" },
    priv,
  );

  const record: LicenseRecord = {
    user_email: email,
    created_at: now,
    activations: [],
    revoked: false,
    test_mode: testMode,
    paddle_transaction_id: transactionId,
  };
  await putLicense(env, licenseUuid, record);
  await markEventProcessed(env, eventId, "minted");

  try {
    await sendLicenseEmail({ apiKey: env.RESEND_API_KEY, to: email, licenseKey: token, fetchImpl });
  } catch (err) {
    // markEventProcessed already fired above, so Paddle's retry hits the
    // duplicate guard and short-circuits — the email is NOT re-sent automatically.
    // The license IS persisted in KV; only delivery failed. Recovery requires
    // a manual re-send from the support@ inbox using the logged license uuid.
    console.error(`[webhook] email delivery failed license=${licenseUuid} txn=${transactionId} email=${email}`, err);
    throw err;
  }

  console.log(`[webhook] minted license=${licenseUuid} txn=${transactionId} test_mode=${testMode}`);
  return new Response("ok", { status: 200 });
}

async function revokeByAdjustment(event: PaddleEvent, env: Env, eventId: string): Promise<Response> {
  // Adjustment events carry the originating transaction id in data.transaction_id.
  // data.id is the adjustment id (adj_…), not the transaction (txn_…).
  const transactionId = event.data.transaction_id;
  if (!transactionId) {
    console.warn(`[webhook] adjustment missing transaction_id event_id=${eventId} adjustment_id=${event.data.id}`);
    await markEventProcessed(env, eventId, "skipped");
    return new Response("ok (missing transaction_id)", { status: 200 });
  }

  const testMode = isSandboxEvent(event);
  const ns = licenseNamespace(env, testMode);

  const list = await ns.list();
  // CF KV list() returns ≤1000 keys per call. At v1.0-era scale (hundreds of
  // licenses) this is safe. If the project scales past 1000 active licenses,
  // migrate to cursor-based pagination before this becomes a silent miss.
  if (list.list_complete === false) {
    console.warn(`[webhook] KV list truncated — refund scan may miss records txn=${transactionId}`);
  }
  for (const key of list.keys) {
    const rec = (await ns.get(key.name, "json")) as LicenseRecord | null;
    if (rec && (rec.paddle_transaction_id === transactionId || rec.ls_order_id === transactionId)) {
      rec.revoked = true;
      await ns.put(key.name, JSON.stringify(rec));
      console.log(`[webhook] revoked license=${key.name} txn=${transactionId} adjustment=${event.data.id} action=${event.data.action}`);
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
