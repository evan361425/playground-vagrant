#!/usr/bin/env sh

# Prepared env
# - VAULT_API_ADDR          - required
# - VAULT_TOKEN             - required if VAULT_RECOVERY_KEYS not set
# - VAULT_RECOVERY_KEYS     - required if VAULT_TOKEN not set, it will generate VAULT_TOKEN
. /etc/vault.d/.cron.env

CAT_BIN=$(command -v cat)
CURL_BIN=$(command -v curl)
JQ_BIN=$(command -v jq)

# Policies
SECRET_CLIENT_POLICY="/etc/vault.d/secret-client-policy.json"
SECRET_CLIENT_GENERATOR_POLICY="/etc/vault.d/secret-client-generator-policy.json"

VAULT_TOKEN_HEADER="X-Vault-Token: ${VAULT_TOKEN}"
CONTENT_TYPE_HEADER="Content-Type: application/json"

printStatus() {
  echo "$(date +"%F %T") - $1"
}

mountKV() {
  $CURL_BIN -s -X POST $VAULT_API_ADDR/v1/sys/mounts/develop \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "@$MOUNT_SETTING" > /dev/null
}

# Generate token by
# curl -X POST localhost:8200/v1/auth/token/create/secret-client -H "X-Vault-Token: "
generateSecretClientRole() {
  $CURL_BIN -s -X POST $VAULT_API_ADDR/v1/auth/token/roles/secret-client \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d '{"allowed_policies":["secret-client-policy"]}'
}

checkPolicy() {
  echo $($CURL_BIN -s "$VAULT_API_ADDR/v1/sys/policy/$1" \
    -H $VAULT_TOKEN_HEADER -H $CONTENT_TYPE_HEADER \
    | $JQ_BIN -r '.name')
}

generatePolicy() {
  printStatus "Generate $1 policy"
  POLICY=$($CAT_BIN $2)
  DATA=$($JQ_BIN -n --arg policy "$POLICY" '{"policy": $policy}')

  $CURL_BIN -s -X POST "$VAULT_API_ADDR/v1/sys/policy/$1" \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "$DATA"
}

# ============================ Check and prepare env ===========================
NEW_TOKEN=$(. /etc/vault.d/renew-token.sh) || exit 1;
if [ ! -z "$NEW_TOKEN"  ] && [ "$NEW_TOKEN" != "null" ]; then
  exit 0;
fi

# Using recovery keys to generate root token
if [ -z "$VAULT_ROOT_TOKEN" ]; then
  VAULT_ROOT_TOKEN=$(. /etc/vault.d/generate-root-token.sh) || exit 1;
fi

VAULT_TOKEN_HEADER="X-Vault-Token: ${VAULT_ROOT_TOKEN}"

# ========================== Generate KV Secret Engine =========================
PKI_RESULT=$($CURL_BIN -s $VAULT_API_ADDR/v1/sys/mounts \
  -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
  | $JQ_BIN '.data."develop/"')
if [ "${PKI_RESULT}" = "null" ]; then
  printStatus "Enable KV"
  mountKV

  generateSecretClientRole
else
  printStatus "KV enabled"
fi

# ============================= Generate Artifact ==============================
# generate client policy
POLICY='secret-client-policy'
if [ $(checkPolicy $POLICY) = "null" ]; then
  generatePolicy $POLICY $SECRET_CLIENT_POLICY
fi

# generate role policy
POLICY='secret-client-generator'
if [ "$(checkPolicy $POLICY)" = "null" ]; then
  generatePolicy $POLICY $SECRET_CLIENT_GENERATOR_POLICY
fi

# ======================== Generate Self-checking token ========================
printStatus "Generate service checking token"
SERVICE_CHECKING_TOKEN=$($CURL_BIN -s -X POST $VAULT_API_ADDR/v1/auth/token/create \
  -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
  -d '{"display_name":"service-checking","ttl":"1h","policies":["secret-client-generator"]}' \
  | $JQ_BIN -r '.auth.client_token')

echo "\nVAULT_TOKEN=$SERVICE_CHECKING_TOKEN" >> /etc/vault.d/.cron.env
