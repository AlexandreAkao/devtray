# DevTray License Backend

Cloudflare Worker that handles Paddle Billing v1 purchase webhooks, mints
EdDSA-signed JWT licenses, tracks activations (3 per license), exposes a
heartbeat endpoint for revoke detection, and 302-redirects buyers to the
Paddle checkout Magic Link.

## Routes

- `POST /webhook` — Paddle event ingestion (HMAC-verified via `Paddle-Signature`, idempotent via `event_id`)
- `GET  /buy` — 302 redirect to `PADDLE_MAGIC_LINK_URL`; optional `?email=` appended as `customer_email=`
- `POST /activate` — App activates a license + machine_hash (quota-checked)
- `POST /deactivate` — App frees a slot
- `GET  /status?license=<uuid>&machine=<hash>` — Heartbeat (revoke detection)
- `POST /admin/release-all` — Author-only emergency release (X-Admin-Token gated)

## Local development

```bash
npm install
npm run dev   # wrangler dev — local Worker on http://localhost:8787
npm test
```

## Deploy

See `docs/superpowers/plans/2026-05-31-devtray-v1.0-paddle-launch.md` task T19
(author-only manual steps): secret rotation + `wrangler deploy` after PR merge.
