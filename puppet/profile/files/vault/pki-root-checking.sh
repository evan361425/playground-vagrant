#!/usr/bin/env sh

# shellcheck source=/dev/null
. "/etc/vault.d/$CRON_NAME.env"
# shellcheck source=/dev/null
. "/etc/vault.d/$CRON_NAME.token.env"

# Needed files when initializing
MOUNT_SETTING="/etc/vault.d/mount-setting.json"
PKI_SETTING="/etc/vault.d/pki-setting.json"

CURL_BIN=$(command -v curl)
JQ_BIN=$(command -v jq)

VAULT_TOKEN_HEADER="X-Vault-Token: ${VAULT_TOKEN}"
CONTENT_TYPE_HEADER="Content-Type: application/json"

printStatus() {
  echo "$(date +"%F %T") - $1"
}

mountPKIIfNeed() {
  PKI_RESULT=$($CURL_BIN -s -X GET "$VAULT_API_ADDR"/v1/sys/mounts \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    | $JQ_BIN '.data."pki/"')
  if [ "${PKI_RESULT}" = "null" ]; then
    printStatus "Enable PKI"
    $CURL_BIN -s -X POST "$VAULT_API_ADDR"/v1/sys/mounts/pki \
      -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
      -d "@$MOUNT_SETTING" > /dev/null
  fi
}

generateCert() {
  RESULT=$($CURL_BIN -s "$VAULT_API_ADDR"/v1/pki/ca/pem)

  if [ -n "$RESULT" ] && [ ! "$RESULT" = 'null' ]; then
    return 0;
  fi

  printStatus "Generate certificate"
  $CURL_BIN -s -X POST "$VAULT_API_ADDR"/v1/pki/root/generate/internal \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "@$PKI_SETTING" \
    | $JQ_BIN '.data' > /etc/vault.d/CERTIFICATE.pem
}

generatePolicy() {
  printStatus "Generate policy $1"

  $CURL_BIN -s -X POST "$VAULT_API_ADDR/v1/sys/policy/$1" \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "$($JQ_BIN -n --arg policy "$2" "{\"policy\": \$policy}")"
}

# ============================ Check and prepare env ===========================
if [ "$(. /etc/vault.d/renew-token.sh)" = 'success' ]; then
  exit 0;
fi

# Using recovery keys to generate root token
if [ -z "$VAULT_ROOT_TOKEN" ]; then
  VAULT_ROOT_TOKEN=$(. /etc/vault.d/generate-root-token.sh) || exit 1;
fi

VAULT_TOKEN_HEADER="X-Vault-Token: ${VAULT_ROOT_TOKEN}"

# ============================== Generate PKI Root =============================
mountPKIIfNeed

# ============================= Generate Artifact ==============================
generateCert
generatePolicy "pki-intermediate" '{"path":{"pki/root/sign-intermediate":{"capabilities":["create","update"]}}}'
# curl -X POST localhost:8200/v1/auth/token/create-orphan -d '{"ttl":"72h","no_parent":true,"policies":"pki-intermediate"}' -H "X-Vault-Token: " 
generatePolicy "pki-intermediate-generator" '{"path":{"auth/token/create-orphan":{"capabilities":["create","update","sudo"]}}}'

# ======================== Generate Self-checking token ========================
printStatus "Generate service checking token"
SERVICE_CHECKING_TOKEN=$($CURL_BIN -s -X POST "$VAULT_API_ADDR"/v1/auth/token/create-orphan \
  -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
  -d "{\"display_name\":\"$CRON_NAME-checking\",\"ttl\":\"1h\",\"policies\":[\"pki-intermediate-generator\"]}" \
  | ${JQ_BIN} -r '.auth.client_token')

echo "VAULT_TOKEN=$SERVICE_CHECKING_TOKEN" > "/etc/vault.d/$CRON_NAME.token.env"
