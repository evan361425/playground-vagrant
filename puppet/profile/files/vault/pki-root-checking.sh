#!/usr/bin/env sh

# Prepared env
# - VAULT_API_ADDR          - required
# - VAULT_TOKEN             - required if VAULT_RECOVERY_KEYS not set
# - VAULT_RECOVERY_KEYS     - required if VAULT_TOKEN not set, it will generate VAULT_TOKEN
. /etc/vault.d/.cron.env

# Needed files when initializing
MOUNT_SETTING="/etc/vault.d/mount-setting.json"
PKI_SETTING="/etc/vault.d/pki-setting.json"
# Policies
PKI_INTERMEDIATE_POLICY="/etc/vault.d/pki-intermediate-policy.json"

CAT_BIN=$(command -v cat)
CURL_BIN=$(command -v curl)
JQ_BIN=$(command -v jq)

VAULT_TOKEN_HEADER="X-Vault-Token: ${VAULT_TOKEN}"
CONTENT_TYPE_HEADER="Content-Type: application/json"

printStatus() {
  echo "$(date +"%F %T") - $1"
}

mountPKI() {
  $CURL_BIN -s -X POST $VAULT_API_ADDR/v1/sys/mounts/pki \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "@$MOUNT_SETTING" > /dev/null
}

generateCert() {
  $CURL_BIN -s -X POST $VAULT_API_ADDR/v1/pki/root/generate/internal \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "@$PKI_SETTING" \
    | $JQ_BIN '.data' > /etc/vault.d/CERTIFICATE.pem
}

checkPolicy() {
  echo $($CURL_BIN -s -X GET "$VAULT_API_ADDR/v1/sys/policy/$1" \
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
NEW_TOKEN=$(. /etc/vault.d/token-checking.sh) || exit 1;
if [ ! -z "$NEW_TOKEN"  ] && [ "$NEW_TOKEN" != "null" ]; then
  printStatus "Renew token successfully"
  exit 0;
fi

# Using recovery keys to generate root token
if [ -z "$VAULT_ROOT_TOKEN" ]; then
  VAULT_ROOT_TOKEN=$(. /etc/vault.d/generate-root-token.sh) || exit 1;
fi

VAULT_TOKEN_HEADER="X-Vault-Token: ${VAULT_ROOT_TOKEN}"

# ============================== Generate PKI Root =============================
PKI_RESULT=$($CURL_BIN -s -X GET $VAULT_API_ADDR/v1/sys/mounts \
  -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
  | $JQ_BIN '.data."pki/"')
if [ "${PKI_RESULT}" = "null" ]; then
  printStatus "Enable PKI"
  mountPKI

  generateCert
else
  printStatus "PKI enabled"
fi

# ============================= Generate Artifact ==============================
# generate intermediate policy
POLICY='pki-intermediate'
if [ $(checkPolicy $POLICY) = "null" ]; then
  generatePolicy $POLICY $PKI_INTERMEDIATE_POLICY
fi

# ======================== Generate Self-checking token ========================
printStatus "Generate service checking token"
SERVICE_CHECKING_TOKEN=$($CURL_BIN -s -X POST $VAULT_API_ADDR/v1/auth/token/create \
  -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
  -d '{"display_name":"service-checking","ttl":"1h","policies":["default","pki-intermediate"]}' \
  | ${JQ_BIN} -r '.auth.client_token')

echo "\nVAULT_TOKEN=$SERVICE_CHECKING_TOKEN" >> /etc/vault.d/.cron.env
