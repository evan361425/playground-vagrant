#!/usr/bin/env sh

# Prepared env
# - VAULT_API_ADDR          - required
# - VAULT_TOKEN             - required if VAULT_RECOVERY_KEYS not set
# - VAULT_RECOVERY_KEYS     - required if VAULT_TOKEN not set, it will generate VAULT_TOKEN
# - MOUNT_FILE              - file name of mounting kv secret engine
# - POLICY_FILE             - file name of kv secret engine client policy
# shellcheck source=/dev/null
. "/etc/vault.d/$CRON_NAME.env"

CURL_BIN=$(command -v curl)
JQ_BIN=$(command -v jq)

VAULT_TOKEN_HEADER="X-Vault-Token: ${VAULT_TOKEN}"
CONTENT_TYPE_HEADER="Content-Type: application/json"

printStatus() {
  echo "$(date +"%F %T") - $1"
}

mountKVIfNeed() {
  MOUNT_PATH=$($JQ_BIN -r '.path // "secret"' "$MOUNT_FILE")
  PKI_RESULT=$($CURL_BIN -s "$VAULT_API_ADDR"/v1/sys/mounts \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    | $JQ_BIN ".data.\"$MOUNT_PATH/\"")

  if [ "$PKI_RESULT" = "null" ]; then
    $CURL_BIN -s -X POST "$VAULT_API_ADDR"/v1/sys/mounts/"$MOUNT_PATH" \
      -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
      -d "@$MOUNT_FILE" > /dev/null
  fi
}

# Generate token by
# curl -X POST localhost:8200/v1/auth/token/create/$CRON_NAME -H "X-Vault-Token: "
generateClientRole() {
  POLICY_NAME=$($JQ_BIN -r '.name // "kv-client-policy"' "$POLICY_FILE")
  $CURL_BIN -s -X POST "$VAULT_API_ADDR"/v1/auth/token/roles/"$CRON_NAME" \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "{\"allowed_policies\":[\"$POLICY_NAME\"]}"

  printStatus "Generate $CRON_NAME generator policy"
  GENERATOR_POLICY=$(printf '{
  "path": {
    "auth/token/create/%s": {
      "capabilities": ["create", "update"]
    },
    "auth/token/renew-self": {
      "capabilities": ["create", "update"]
    }
  }
}' "$CRON_NAME")
  GENERATOR_DATA=$($JQ_BIN -n --arg policy "$GENERATOR_POLICY" "{\"policy\": \$policy}")

  $CURL_BIN -s -X POST "$VAULT_API_ADDR/v1/sys/policy/$CRON_NAME-generator" \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "$GENERATOR_DATA"
}

generatePolicy() {
  POLICY_NAME=$($JQ_BIN -r '.name // "kv-client-policy"' "$POLICY_FILE")
  printStatus "Generate policy $POLICY_NAME"
  POLICY=$(cat "$POLICY_FILE")
  DATA=$($JQ_BIN -n --arg policy "$POLICY" "{\"policy\": \$policy}")

  $CURL_BIN -s -X POST "$VAULT_API_ADDR/v1/sys/policy/$POLICY_NAME" \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "$DATA"
}

# ============================== Setup if needed ===============================
NEW_TOKEN=$(. /etc/vault.d/renew-token.sh) || exit 1;
if [ -n "$NEW_TOKEN"  ] && [ "$NEW_TOKEN" != "null" ]; then
  exit 0;
fi

# Using recovery keys to generate root token
if [ -z "$VAULT_ROOT_TOKEN" ]; then
  VAULT_ROOT_TOKEN=$(. /etc/vault.d/generate-root-token.sh) || exit 1;
fi

VAULT_TOKEN_HEADER="X-Vault-Token: ${VAULT_ROOT_TOKEN}"

mountKVIfNeed
generateClientRole
generatePolicy

# ======================== Generate Self-checking token ========================
printStatus "Generate service checking token"
DATA=$(printf '{"display_name":"%s","ttl":"1h","policies":["default","%s-generator"]}' "$CRON_NAME" "$CRON_NAME")
SERVICE_CHECKING_TOKEN=$($CURL_BIN -s -X POST "$VAULT_API_ADDR"/v1/auth/token/create \
  -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
  -d "$DATA" \
  | ${JQ_BIN} -r '.auth.client_token')

printf "\nVAULT_TOKEN=%s" "$SERVICE_CHECKING_TOKEN" >> "/etc/vault.d/$CRON_NAME.env"
