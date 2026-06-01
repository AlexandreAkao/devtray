# DevTray License Backend

Cloudflare Worker that handles Paddle Billing v1 purchase webhooks, mints
EdDSA-signed JWT licenses, tracks activations (3 per license), exposes a
heartbeat endpoint for revoke detection, and 302-redirects buyers to the
Paddle checkout Magic Link.

## Routes

- `POST /webhook` — Paddle event ingestion (HMAC-verified via `Paddle-Signature`, idempotent via `event_id`). Handles `transaction.completed`, `adjustment.created`, and `adjustment.updated`. Refund revoke is gated on `data.action ∈ {refund, chargeback}` AND `data.status === "approved"`.
- `GET  /buy` — calls `POST /transactions` on the Paddle API with `PADDLE_PRICE_ID` and 302-redirects to the returned `checkout.url`; optional `?email=` is forwarded as `customer.email`
- `POST /activate` — App activates a license + machine_hash (quota-checked)
- `POST /deactivate` — App frees a slot
- `GET  /status?license=<uuid>&machine=<hash>` — Heartbeat (revoke detection)
- `POST /admin/release-all` — Author-only emergency release (X-Admin-Token gated)
- `POST /admin/reconcile` — Author-only manual refund reconciliation trigger (X-Admin-Token gated). Same logic as the 30-min cron.

## Scheduled jobs

- **Refund reconciliation (every 30 min)** — wrangler `[triggers] crons = ["*/30 * * * *"]`. The `scheduled` handler in `src/index.ts` invokes `reconcileRefunds()`, which lists all licenses in the `LICENSES` KV namespace, queries Paddle's `GET /transactions/{id}` for each non-revoked record (skipping records younger than 60s or older than 90d), and flips `revoked: true` for any whose transaction status is `refunded` or `partially_refunded`. Defense-in-depth against webhook delivery failures.

## Local development

```bash
npm install
npm run dev   # wrangler dev — local Worker on http://localhost:8787
npm test
```

## Deploy

See `docs/superpowers/plans/2026-05-31-devtray-v1.0-paddle-launch.md` task T19
(author-only manual steps): secret rotation + `wrangler deploy` after PR merge.
