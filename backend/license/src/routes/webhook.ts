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
    // Paddle Billing v1 webhooks carry the customer id at top level, NOT an
    // embedded customer object. We resolve the email by GETting /customers/{id}.
    customer_id?: string;
    items?: Array<{ price?: { id?: string; product_id?: string } }>;
    details?: { totals?: { total?: string; currency_code?: string } };
    // Present on adjustment.* events:
    action?: "refund" | "chargeback" | "credit" | "chargeback_warning" | "chargeback_reverse" | "credit_reverse" | string;
    transaction_id?: string;
    // Paddle's `data.origin` is the creation channel (api/web/subscription_renewal),
    // NOT a sandbox-vs-prod flag. Sandbox/prod is determined by which endpoint and
    // notification secret was used. We only configure prod here; sandbox would
    // require a parallel deployment or a second secret. So new mints are always
    // production-track in v1.0.
    origin?: string;
    [k: string]: unknown;
  };
};

const DEFAULT_API_BASE = "https://api.paddle.com";

async function fetchCustomerEmail(
  customerId: string,
  env: Env,
  fetchImpl: FetchImpl,
): Promise<string | null> {
  const apiBase = env.PADDLE_API_BASE_URL || DEFAULT_API_BASE;
  try {
    const res = await fetchImpl(`${apiBase}/customers/${encodeURIComponent(customerId)}`, {
      method: "GET",
      headers: { Authorization: `Bearer ${env.PADDLE_API_KEY}` },
    });
    if (!res.ok) {
      const body = await res.text().catch(() => "<no body>");
      console.error(`[webhook] customer fetch failed status=${res.status} customer_id=${customerId} body=${body}`);
      return null;
    }
    const payload = (await res.json()) as { data?: { email?: string } };
    return payload?.data?.email ?? null;
  } catch (err) {
    console.error(`[webhook] customer fetch error customer_id=${customerId}`, err);
    return null;
  }
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
  const customerId = event.data?.customer_id;
  if (typeof customerId !== "string" || customerId === "") {
    return new Response("missing customer_id", { status: 400 });
  }

  const email = await fetchCustomerEmail(customerId, env, fetchImpl);
  if (!email) {
    return new Response("could not resolve customer email", { status: 502 });
  }

  const transactionId = event.data.id;
  const licenseUuid = crypto.randomUUID();
  const now = Math.floor(Date.now() / 1000);

  const priv = decodeBase64(env.LICENSE_PRIVATE_KEY);
  const token = await signLicense(
    { iss: env.LICENSE_ISS, sub: licenseUuid, email, iat: now, tier: "v1" },
    priv,
  );

  // v1.0 has no sandbox routing — we only configured prod webhook + prod
  // secrets. test_mode stays false for all mints. If sandbox parallel-deploy
  // is added later, distinguish via env var (e.g. PADDLE_ENV === "sandbox").
  const record: LicenseRecord = {
    user_email: email,
    created_at: now,
    activations: [],
    revoked: false,
    test_mode: false,
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

  console.log(`[webhook] minted license=${licenseUuid} txn=${transactionId} customer=${customerId}`);
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

  // v1.0: prod-only routing (see mintLicense note above).
  const ns = licenseNamespace(env, false);

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
