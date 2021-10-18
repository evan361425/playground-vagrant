#!/usr/bin/env sh

# Prepared env
# - VAULT_API_ADDR          - required
# - VAULT_TOKEN             - required if VAULT_RECOVERY_KEYS not set
# - VAULT_RECOVERY_KEYS     - required if VAULT_TOKEN not set, it will generate VAULT_TOKEN
# shellcheck source=/dev/null
. /etc/vault.d/.cron.env

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
  printStatus "Generate certificate"
  $CURL_BIN -s -X POST "$VAULT_API_ADDR"/v1/pki/root/generate/internal \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "@$PKI_SETTING" \
    | $JQ_BIN '.data' > /etc/vault.d/CERTIFICATE.pem
}

generateTokenRole() {
  $CURL_BIN -s -X POST "$VAULT_API_ADDR/v1/auth/token/roles/$1" \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "{\"allowed_policies\":[\"$1\"]}"
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
generateTokenRole "pki-intermediate"
generatePolicy "pki-intermediate" '{"path":{"pki/root/sign-intermediate":{"capabilities":["create","update"]}}}'
generatePolicy "pki-intermediate-generator" '{"path":{"auth/token/create/pki-intermediate":{"capabilities":["create","update"]}}}'

# ======================== Generate Self-checking token ========================
printStatus "Generate service checking token"
SERVICE_CHECKING_TOKEN=$($CURL_BIN -s -X POST "$VAULT_API_ADDR"/v1/auth/token/create \
  -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
  -d '{"display_name":"service-checking","ttl":"1h","policies":["pki-intermediate-generator"]}' \
  | ${JQ_BIN} -r '.auth.client_token')

printf "\nVAULT_TOKEN=%s" "$SERVICE_CHECKING_TOKEN" >> /etc/vault.d/.cron.env
