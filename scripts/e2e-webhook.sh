#!/usr/bin/env bash
# scripts/e2e-webhook.sh
# End-to-end test driver for the Paddle webhook handler. Drives a full
# mint → revoke cycle against a running `wrangler dev --remote` Worker,
# asserting that the txn_e2e_* prefix routes through LICENSES_TEST.
#
# Prerequisites:
#   - `cd backend/license && npx wrangler dev --remote` running in another
#     terminal (default port 8787).
#   - ~/devtray-secrets/paddle_notification_secret.txt readable.
#   - jq, openssl, curl, uuidgen available.
#
# Usage:
#   ./scripts/e2e-webhook.sh                # default endpoint
#   WORKER_URL=http://localhost:8788 ./scripts/e2e-webhook.sh   # override
#
# Exit codes:
#   0 — full cycle passed
#   1 — assertion failed (record not minted, wrong revoke state, etc.)
#   2 — setup error (Worker unreachable, secret missing, etc.)

set -euo pipefail

WORKER_URL="${WORKER_URL:-http://localhost:8787}"
SECRET_PATH="${HOME}/devtray-secrets/paddle_notification_secret.txt"

# --- setup ---

if [[ ! -r "$SECRET_PATH" ]]; then
  echo "[e2e] FATAL: cannot read $SECRET_PATH" >&2
  exit 2
fi
SECRET="$(cat "$SECRET_PATH")"

if ! curl -fsS -o /dev/null --max-time 2 "$WORKER_URL/" 2>/dev/null; then
  echo "[e2e] FATAL: Worker not reachable at $WORKER_URL — is 'wrangler dev --remote' running?" >&2
  exit 2
fi

TXN_ID="txn_e2e_$(uuidgen | tr 'A-Z' 'a-z' | tr -d '-' | head -c 16)"
EVENT_MINT="evt_e2e_$(uuidgen | tr 'A-Z' 'a-z' | tr -d '-' | head -c 16)"
EVENT_REFUND="evt_e2e_$(uuidgen | tr 'A-Z' 'a-z' | tr -d '-' | head -c 16)"
ADJ_ID="adj_e2e_$(uuidgen | tr 'A-Z' 'a-z' | tr -d '-' | head -c 16)"

echo "[e2e] txn=$TXN_ID mint_event=$EVENT_MINT refund_event=$EVENT_REFUND"

# --- helpers ---

sign_and_post() {
  local body="$1"
  local ts
  ts="$(date +%s)"
  local mac
  mac="$(printf '%s:%s' "$ts" "$body" | openssl dgst -sha256 -hmac "$SECRET" -hex | awk '{print $NF}')"
  curl -fsS -X POST "${WORKER_URL}/webhook" \
    -H "Content-Type: application/json" \
    -H "Paddle-Signature: ts=${ts};h1=${mac}" \
    --data "$body"
}

# Stub — implemented in Task 9.
mint_payload() { echo "TODO"; }
refund_payload() { echo "TODO"; }
find_license_uuid() { echo "TODO"; }
delete_license() { echo "TODO"; }
delete_event() { echo "TODO"; }
