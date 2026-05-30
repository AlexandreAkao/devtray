# DevTray License Backend

Cloudflare Worker that handles LemonSqueezy purchase webhooks, mints EdDSA-signed JWT
licenses, tracks activations (3 per license), and exposes a heartbeat endpoint for
revoke detection.

## Routes

- `POST /webhook` — LemonSqueezy event ingestion (HMAC-verified, idempotent)
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

See `docs/superpowers/plans/2026-05-30-devtray-v0.11-paywall.md` task T35
(author-only manual steps).
