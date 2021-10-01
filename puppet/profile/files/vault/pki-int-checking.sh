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

mountPKI() {
  $CURL_BIN -s -X POST $VAULT_API_ADDR/v1/sys/mounts/pki \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "@$MOUNT_SETTING" > /dev/null
}

generateCSR() {
  $CURL_BIN -s -X POST $VAULT_API_ADDR/v1/pki/intermediate/generate/internal \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "@$PKI_SETTING" \
    | $JQ_BIN -r '.data.csr' > /etc/vault.d/INTERMEDIATE_CSR.pem

  return 0;
}

shouldResignRootCert() {
  # This is an unauthenticated endpoint.
  $CURL_BIN -s $VAULT_API_ADDR/v1/pki/ca_chain > /etc/vault.d/CA_CHAIN.pem

  # If unparsable, exit
  openssl x509 -in /etc/vault.d/CA_CHAIN.pem > /dev/null 2>&1 &
  if [ "$?" -ne "0" ]; then
   return 0;
  fi

  RESULT=$(openssl x509 -in /etc/vault.d/CA_CHAIN.pem -issuer -noout)
  # If already set up root
  if [ "$RESULT" = "issuer= /CN=Vault Root CA" ]; then
    return 1;
  fi

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

  DATA=$($JQ_BIN -n \
    --arg csr "$($CAT_BIN /etc/vault.d/INTERMEDIATE_CSR.pem)" \
    '{"csr": $csr,"use_csr_values":true}')

  CERT=$($CURL_BIN -s -X POST $PKI_ROOT_API_ADDR/v1/pki/root/sign-intermediate \
    -H "X-Vault-Token: $PKI_ROOT_TOKEN" -H "$CONTENT_TYPE_HEADER" \
    -d "$DATA" \
    | $JQ_BIN -r '.data.certificate')
  if [ "$CERT" = "null" ] || [ -z "$CERT" ]; then
    printStatus "Token cannot generate certificate"
    return 1;
  fi 

  printStatus "Generate certificate from root PKI successfully"
  printf "$CERT" > /etc/vault.d/INTERMEDIATE_CERT.pem
  return 0
}

setSignedCert() {
  DATA=$($JQ_BIN -n \
    --arg certificate "$($CAT_BIN /etc/vault.d/INTERMEDIATE_CERT.pem)" \
    '{"certificate": $certificate}')

  $CURL_BIN -s -X POST $VAULT_API_ADDR/v1/pki/intermediate/set-signed \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "$DATA"
  printStatus "Finish set intermediate PKI signed"
}

generatePKIRole() {
  $CURL_BIN -s -X POST $VAULT_API_ADDR/v1/pki/roles/encrypt-service \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "@$PKI_ENCRYPT_SERVICE"
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
if [ -f "$PKI_ROOT_TOKEN_FILE" ]; then
  printStatus "The file $PKI_ROOT_TOKEN_FILE exist, please remove it as soon as possible"
fi

NEW_TOKEN=$(. /etc/vault.d/token-checking.sh) || exit 1;
if [ ! -z "$NEW_TOKEN"  ] && [ "$NEW_TOKEN" != "null" ]; then
  printStatus "Renew token successfully"

  shouldResignRootCert && generateCSR && signCSRByRoot && setSignedCert

  exit 0;
fi

# Using recovery keys to generate root token
if [ -z "$VAULT_ROOT_TOKEN" ]; then
  VAULT_ROOT_TOKEN=$(. /etc/vault.d/generate-root-token.sh) || exit 1;
fi

VAULT_TOKEN_HEADER="X-Vault-Token: ${VAULT_ROOT_TOKEN}"

# ========================== Generate PKI Intermediate =========================
PKI_RESULT=$($CURL_BIN -s -X GET $VAULT_API_ADDR/v1/sys/mounts \
  -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
  | $JQ_BIN '.data."pki/"')
if [ "${PKI_RESULT}" = "null" ]; then
  printStatus "Enable PKI"
  mountPKI

  generatePKIRole

  generateCSR && signCSRByRoot && setSignedCert
else
  printStatus "PKI enabled"
fi

# ============================= Generate Artifact ==============================
# generate client policy
POLICY='encrypt-service'
if [ "$(checkPolicy $POLICY)" = "null" ]; then
  generatePolicy $POLICY $ENCRYPT_SERVICE_POLICY
fi

# generate role policy
POLICY='encrypt-service-generator'
if [ "$(checkPolicy $POLICY)" = "null" ]; then
  generatePolicy $POLICY $ENCRYPT_SERVICE_GENERATOR_POLICY
fi

# ======================== Generate Self-checking token ========================
printStatus "Generate service checking token"
SERVICE_CHECKING_TOKEN=$($CURL_BIN -s -X POST $VAULT_API_ADDR/v1/auth/token/create \
  -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
  -d '{"display_name":"service-checking","ttl":"1h","policies":["default","encrypt-service-generator"]}' \
  | ${JQ_BIN} -r '.auth.client_token')

echo "\nVAULT_TOKEN=$SERVICE_CHECKING_TOKEN" >> /etc/vault.d/.cron.env
