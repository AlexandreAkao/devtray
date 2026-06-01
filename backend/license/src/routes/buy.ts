import type { Env } from "../types";

type FetchImpl = typeof fetch;

const DEFAULT_API_BASE = "https://api.paddle.com";

/**
 * Creates a Paddle transaction for the configured price and 302-redirects the
 * buyer to the returned checkout URL.
 *
 * Paddle Billing v1 has no permanent "magic link" URL — every checkout flow is
 * initiated by creating a transaction, which yields a one-shot checkout.url
 * that survives ~24h before expiring.
 */
export async function handleBuy(req: Request, env: Env, fetchImpl: FetchImpl = fetch): Promise<Response> {
  if (!env.PADDLE_API_KEY) {
    console.error("[buy] PADDLE_API_KEY is unset");
    return new Response("checkout unavailable", { status: 500 });
  }
  if (!env.PADDLE_PRICE_ID) {
    console.error("[buy] PADDLE_PRICE_ID is unset");
    return new Response("checkout unavailable", { status: 500 });
  }

  const reqUrl = new URL(req.url);
  const email = reqUrl.searchParams.get("email");
  const apiBase = env.PADDLE_API_BASE_URL || DEFAULT_API_BASE;

  const body: Record<string, unknown> = {
    items: [{ price_id: env.PADDLE_PRICE_ID, quantity: 1 }],
    collection_mode: "automatic",
  };
  if (email) {
    body.customer = { email };
  }

  let res: Response;
  try {
    res = await fetchImpl(`${apiBase}/transactions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.PADDLE_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });
  } catch (err) {
    console.error("[buy] Paddle API network error", err);
    return new Response("checkout unavailable", { status: 502 });
  }

  if (!res.ok) {
    const errBody = await res.text().catch(() => "<no body>");
    console.error(`[buy] Paddle API error status=${res.status} body=${errBody}`);
    return new Response("checkout unavailable", { status: 502 });
  }

  let payload: { data?: { id?: string; checkout?: { url?: string } } };
  try {
    payload = (await res.json()) as typeof payload;
  } catch (err) {
    console.error("[buy] Paddle API response not JSON", err);
    return new Response("checkout unavailable", { status: 502 });
  }

  const checkoutUrl = payload?.data?.checkout?.url;
  if (!checkoutUrl) {
    console.error("[buy] Paddle response missing data.checkout.url", JSON.stringify(payload));
    return new Response("checkout unavailable", { status: 502 });
  }

  console.log(`[buy] redirect txn=${payload?.data?.id ?? "?"} → checkout`);
  return Response.redirect(checkoutUrl, 302);
}
