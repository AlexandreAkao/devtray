// Minimal worker entry — full hono wiring lands in T29.
import type { Env } from "./types";

export default {
  async fetch(_req: Request, _env: Env): Promise<Response> {
    return new Response("devtray license backend — not yet wired", { status: 501 });
  },
};
