import type { Env } from "../src/types";

declare module "cloudflare:test" {
  // Makes env from cloudflare:test assignable to our Env type
  interface ProvidedEnv extends Env {}
}
