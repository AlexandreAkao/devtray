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

mint_payload() {
  jq -nc \
    --arg eid "$EVENT_MINT" \
    --arg txn "$TXN_ID" \
    --arg occ "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      event_id: $eid,
      event_type: "transaction.completed",
      occurred_at: $occ,
      notification_id: ("ntf_" + $eid),
      data: {
        id: $txn,
        status: "completed",
        customer_id: "ctm_e2e_stub",
        items: [{price: {id: "pri_e2e", product_id: "pro_e2e"}}],
        details: {totals: {total: "1499", currency_code: "USD"}},
        origin: "web"
      }
    }'
}

# Scans LICENSES_TEST for a record whose paddle_transaction_id matches $TXN_ID.
# Prints the UUID to stdout. Returns nonzero if not found.
find_license_uuid() {
  local target="$1"
  cd backend/license
  local keys
  keys=$(npx wrangler kv key list --binding LICENSES_TEST 2>/dev/null | jq -r '.[].name')
  cd - >/dev/null
  for key in $keys; do
    cd backend/license
    local val
    val=$(npx wrangler kv key get "$key" --binding LICENSES_TEST 2>/dev/null || echo "{}")
    cd - >/dev/null
    if echo "$val" | jq -e --arg t "$target" '.paddle_transaction_id == $t' >/dev/null 2>&1; then
      echo "$key"
      return 0
    fi
  done
  return 1
}

refund_payload() {
  jq -nc \
    --arg eid "$EVENT_REFUND" \
    --arg txn "$TXN_ID" \
    --arg adj "$ADJ_ID" \
    --arg occ "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      event_id: $eid,
      event_type: "adjustment.updated",
      occurred_at: $occ,
      notification_id: ("ntf_" + $eid),
      data: {
        id: $adj,
        action: "refund",
        status: "approved",
        transaction_id: $txn,
        customer_id: "ctm_e2e_stub",
        origin: "api"
      }
    }'
}

# Stubs — implemented in Task 11.
delete_license() { echo "TODO"; }
delete_event() { echo "TODO"; }

# --- mint ---

echo "[e2e] posting mint…"
mint_resp="$(sign_and_post "$(mint_payload)")"
echo "[e2e] mint response: $mint_resp"

echo "[e2e] scanning LICENSES_TEST for the minted record…"
MINTED_UUID="$(find_license_uuid "$TXN_ID")" || {
  echo "[e2e] FAIL: minted record not found in LICENSES_TEST for txn=$TXN_ID" >&2
  exit 1
}
echo "[e2e] minted license=$MINTED_UUID"

cd backend/license
mint_record="$(npx wrangler kv key get "$MINTED_UUID" --binding LICENSES_TEST 2>/dev/null)"
cd - >/dev/null

revoked_after_mint="$(echo "$mint_record" | jq -r '.revoked')"
test_mode="$(echo "$mint_record" | jq -r '.test_mode')"
email="$(echo "$mint_record" | jq -r '.user_email')"

if [[ "$revoked_after_mint" != "false" ]]; then
  echo "[e2e] FAIL: expected revoked=false after mint, got $revoked_after_mint" >&2
  exit 1
fi
if [[ "$test_mode" != "true" ]]; then
  echo "[e2e] FAIL: expected test_mode=true, got $test_mode" >&2
  exit 1
fi
if [[ "$email" != "e2e@devtray.app" ]]; then
  echo "[e2e] FAIL: expected user_email=e2e@devtray.app, got $email" >&2
  exit 1
fi
echo "[e2e] mint assertions passed"

# --- refund ---

echo "[e2e] posting refund…"
refund_resp="$(sign_and_post "$(refund_payload)")"
echo "[e2e] refund response: $refund_resp"

cd backend/license
refunded_record="$(npx wrangler kv key get "$MINTED_UUID" --binding LICENSES_TEST 2>/dev/null)"
cd - >/dev/null

revoked_after_refund="$(echo "$refunded_record" | jq -r '.revoked')"
if [[ "$revoked_after_refund" != "true" ]]; then
  echo "[e2e] FAIL: expected revoked=true after refund, got $revoked_after_refund" >&2
  exit 1
fi
echo "[e2e] refund assertions passed"
