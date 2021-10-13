#!/usr/bin/env sh

# Prepared env
# - VAULT_API_ADDR          - required
# - VAULT_TOKEN             - required if VAULT_RECOVERY_KEYS not set
# - VAULT_RECOVERY_KEYS     - required if VAULT_TOKEN not set, it will generate VAULT_TOKEN
# - PKI_ROOT_API_ADDR       - needed when renew certificate
# - PKI_ROOT_TOKEN_FILE     - needed when renew certificate
. /etc/vault.d/.cron.env

# Needed files when initializing
MOUNT_SETTING="/etc/vault.d/mount-setting.json"
PKI_SETTING="/etc/vault.d/pki-setting.json"

# Using Token (policy bind with "C") to generate Client (policy bind with "B")
# Client is able to issue itself by PKI which already setup by "A"
# https://github.com/104corp/vault/issues/10
# A - PKI role setting
PKI_ENCRYPT_SERVICE="/etc/vault.d/pki-encrypt-service.json"
# B - Client policy
ENCRYPT_SERVICE_POLICY="/etc/vault.d/encrypt-service-policy.json"
# C - Generator policy
ENCRYPT_SERVICE_GENERATOR_POLICY="/etc/vault.d/encrypt-service-generator-policy.json"

CAT_BIN=$(command -v cat)
CURL_BIN=$(command -v curl)
JQ_BIN=$(command -v jq)

VAULT_TOKEN_HEADER="X-Vault-Token: ${VAULT_TOKEN}"
CONTENT_TYPE_HEADER="Content-Type: application/json"

printStatus() {
  echo "$(date +"%F %T") - $1"
}

mountPKIIfNeed() {
  PKI_RESULT=$($CURL_BIN -s -X GET $VAULT_API_ADDR/v1/sys/mounts \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    | $JQ_BIN '.data."pki/"')

  if [ "${PKI_RESULT}" = "null" ]; then
    $CURL_BIN -s -X POST $VAULT_API_ADDR/v1/sys/mounts/pki \
      -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
      -d "@$MOUNT_SETTING" > /dev/null
    printStatus "Mount PKI successfully"
  fi
}

shouldResignRootCert() {
  # If certificate file is empty or not found, renew cert
  if [ ! -f "$PEM_CERT" ] || [ ! -s "$PEM_CERT" ]; then
    printStatus "Certificate not found"
    return 0;
  fi

  # If unparsable, exit
  openssl x509 -in $PEM_CERT > /dev/null 2>&1
  if [ "$?" -ne "0" ]; then
    printStatus "Certificate non-parsable"
    return 0;
  fi

  # If not expired in next 60 seconds
  if openssl x509 -in $PEM_CERT -noout -checkend 60; then
    return 1;
  else
    printStatus "Certificate is going to expired, start renew"
    return 0;
  fi
}

generateCSR() {
  $CURL_BIN -s -X POST $VAULT_API_ADDR/v1/pki/intermediate/generate/internal \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "@$PKI_SETTING" \
    | $JQ_BIN -r '.data.csr' > $PEM_CSR

  printStatus "CSR generated"

  return 0;
}

signCSRByRoot() {
  if [ ! -f "$PKI_ROOT_TOKEN_FILE" ]; then
    return 1;
  fi

  PKI_ROOT_TOKEN=$($CAT_BIN $PKI_ROOT_TOKEN_FILE)
  TOKEN_NAME=$($CURL_BIN -s -X GET $PKI_ROOT_API_ADDR/v1/auth/token/lookup-self \
    -H "X-Vault-Token: $PKI_ROOT_TOKEN" -H "$CONTENT_TYPE_HEADER" \
    | $JQ_BIN -r '.data.display_name')
  if [ "$TOKEN_NAME" = "null" ] || [ -z "$TOKEN_NAME" ]; then
    printStatus "Wrong Root API Address $PKI_ROOT_API_ADDR or Wrong Token"
    return 1;
  fi

  TTL=$($JQ_BIN -r '.ttl // "1h"' $PKI_SETTING)
  DATA=$($JQ_BIN -n \
    --arg csr "$($CAT_BIN $PEM_CSR)" \
    --arg ttl "$TTL" \
    '{"csr": $csr,"use_csr_values":true,"ttl":$ttl}')

  $CURL_BIN -s -X POST $PKI_ROOT_API_ADDR/v1/pki/root/sign-intermediate \
    -H "X-Vault-Token: $PKI_ROOT_TOKEN" -H "$CONTENT_TYPE_HEADER" \
    -d "$DATA" \
    | $JQ_BIN -r '.data.certificate' > $PEM_CERT

  CERT=$($CAT_BIN $PEM_CERT)
  if [ "$CERT" = "null" ] || [ -z "$CERT" ]; then
    printStatus "Token cannot generate certificate"
    return 1;
  fi 

  printStatus "Generate certificate from root PKI successfully"
  return 0
}

setSignedCert() {
  DATA=$($JQ_BIN -n \
    --arg certificate "$($CAT_BIN $PEM_CERT)" \
    '{"certificate": $certificate}')

  $CURL_BIN -s -X POST $VAULT_API_ADDR/v1/pki/intermediate/set-signed \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "$DATA"
  printStatus "Finish set intermediate PKI signed"
}

# Issue certificate by
# curl -X POST localhost:8200/v1/pki/issue/encrypt-service -H "X-Vault-Token: " -d '{"common_name": "example.encrypt-service.com"}'
generatePKIRole() {
  $CURL_BIN -s -X POST $VAULT_API_ADDR/v1/pki/roles/encrypt-service \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "@$PKI_ENCRYPT_SERVICE"
}

# Generate token by
# curl -X POST localhost:8200/v1/auth/token/create/encrypt-service -H "X-Vault-Token: " -d '{"ttl":"15m"}'
generateTokenRole() {
  $CURL_BIN -s -X POST $VAULT_API_ADDR/v1/auth/token/roles/encrypt-service \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d '{"allowed_policies":["encrypt-service"],"token_ttl":"15m"}'
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
if [ -f "$PKI_ROOT_TOKEN_FILE" ]; then
  printStatus "The file $PKI_ROOT_TOKEN_FILE exist, please remove it as soon as possible"
fi

NEW_TOKEN=$(. /etc/vault.d/renew-token.sh) || exit 1;
if [ ! -z "$NEW_TOKEN"  ] && [ "$NEW_TOKEN" != "null" ]; then
  shouldResignRootCert && generateCSR && signCSRByRoot && setSignedCert

  exit 0;
fi

# Using recovery keys to generate root token
if [ -z "$VAULT_ROOT_TOKEN" ]; then
  VAULT_ROOT_TOKEN=$(. /etc/vault.d/generate-root-token.sh) || exit 1;
fi

VAULT_TOKEN_HEADER="X-Vault-Token: ${VAULT_ROOT_TOKEN}"

# ========================== Generate PKI Intermediate =========================
mountPKIIfNeed

# ============================= Generate Artifact ==============================
generatePKIRole
generateTokenRole
generateCSR && signCSRByRoot && setSignedCert
generatePolicy 'encrypt-service' $ENCRYPT_SERVICE_POLICY
generatePolicy 'encrypt-service-generator' $ENCRYPT_SERVICE_GENERATOR_POLICY

# ======================== Generate Self-checking token ========================
printStatus "Generate service checking token"
SERVICE_CHECKING_TOKEN=$($CURL_BIN -s -X POST $VAULT_API_ADDR/v1/auth/token/create \
  -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
  -d '{"display_name":"service-checking","ttl":"1h","policies":["default","encrypt-service-generator"]}' \
  | ${JQ_BIN} -r '.auth.client_token')

echo "\nVAULT_TOKEN=$SERVICE_CHECKING_TOKEN" >> /etc/vault.d/.cron.env
