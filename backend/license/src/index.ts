import { Hono } from "hono";
import type { Env } from "./types";
import { handleWebhook } from "./routes/webhook";
import { handleActivate } from "./routes/activate";
import { handleDeactivate } from "./routes/deactivate";
import { handleStatus } from "./routes/status";
import { handleAdminReleaseAll } from "./routes/admin";
import { handleBuy } from "./routes/buy";

const app = new Hono<{ Bindings: Env }>();

app.get("/", (c) => c.text("DevTray license backend OK"));

app.post("/webhook", (c) => handleWebhook(c.req.raw, c.env));
app.post("/activate", (c) => handleActivate(c.req.raw, c.env));
app.post("/deactivate", (c) => handleDeactivate(c.req.raw, c.env));
app.get("/status", (c) => handleStatus(c.req.raw, c.env));
app.get("/buy", (c) => handleBuy(c.req.raw, c.env));
app.post("/admin/release-all", (c) => handleAdminReleaseAll(c.req.raw, c.env));

export default app;
