import type { Env } from "../types";

export async function handleBuy(req: Request, env: Env): Promise<Response> {
  const base = env.PADDLE_MAGIC_LINK_URL;
  if (!base) {
    console.error("[buy] PADDLE_MAGIC_LINK_URL is unset");
    return new Response("checkout unavailable", { status: 500 });
  }

  const reqUrl = new URL(req.url);
  const email = reqUrl.searchParams.get("email");
  let target = base;
  if (email) {
    const sep = base.includes("?") ? "&" : "?";
    target = `${base}${sep}customer_email=${encodeURIComponent(email)}`;
  }
  return Response.redirect(target, 302);
}
