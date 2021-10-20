#!/usr/bin/env sh

# Prepared env
# - VAULT_API_ADDR          - required
# - VAULT_TOKEN             - required if VAULT_RECOVERY_KEYS not set
# - VAULT_RECOVERY_KEYS     - required if VAULT_TOKEN not set, it will generate VAULT_TOKEN
# - PKI_ROOT_API_ADDR       - needed when renew certificate
# - PKI_ROOT_TOKEN          - needed when renew certificate
# - PEM_CSR                 - location of CSR
# - PEM_CERT                - location of certificate
# shellcheck source=/dev/null
. /etc/vault.d/.cron.env

# Needed files when initializing
MOUNT_SETTING="/etc/vault.d/mount-setting.json"
PKI_SETTING="/etc/vault.d/pki-setting.json"

# Clients for intermediate PKI
PKI_CLIENTS_FILE="/etc/vault.d/pki-clients.json"

CURL_BIN=$(command -v curl)
JQ_BIN=$(command -v jq)

VAULT_TOKEN_HEADER="X-Vault-Token: ${VAULT_TOKEN}"
CONTENT_TYPE_HEADER="Content-Type: application/json"

printStatus() {
  echo "$(date +"%F %T") - $1"
}

printProcess() {
  printf "%s - %s... " "$(date +"%F %T")" "$1"
}

mountPKIIfNeed() {
  PKI_RESULT=$($CURL_BIN -s -X GET "$VAULT_API_ADDR"/v1/sys/mounts \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    | $JQ_BIN '.data."pki/"')

  if [ "${PKI_RESULT}" = "null" ]; then
    $CURL_BIN -s -X POST "$VAULT_API_ADDR"/v1/sys/mounts/pki \
      -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
      -d "@$MOUNT_SETTING" > /dev/null
    printStatus "Mount PKI successfully"
  fi
}

shouldResignRootCert() {
  # If certificate file is empty or not found, renew cert
  if [ ! -f "$PEM_CERT" ] || [ ! -s "$PEM_CERT" ]; then
    printProcess "Certificate not found, start request now"
    return 0;
  fi

  if [ -z "$PKI_ROOT_TOKEN" ]; then
    printStatus "Root-PKI's token not found"
    return 1;
  fi

  TOKEN_NAME=$($CURL_BIN -s "$PKI_ROOT_API_ADDR"/v1/auth/token/lookup-self \
    -H "X-Vault-Token: $PKI_ROOT_TOKEN" -H "$CONTENT_TYPE_HEADER" \
    | $JQ_BIN -r '.data.display_name')
  if [ "$TOKEN_NAME" = "null" ] || [ -z "$TOKEN_NAME" ]; then
    printStatus "Wrong Root API Address $PKI_ROOT_API_ADDR or Wrong Token"
    return 1;
  fi
  # renew token
  $CURL_BIN -s -X POST "$PKI_ROOT_API_ADDR"/v1/auth/token/renew-self \
    -H "X-Vault-Token: $PKI_ROOT_TOKEN" -H "$CONTENT_TYPE_HEADER" > /dev/null

  # If unparsable, request new one
  if ! openssl x509 -in "$PEM_CERT" > /dev/null 2>&1; then
    printProcess "Certificate non-parsable, start request now"
    return 0;
  fi

  # If not expired in next 20 minutes (1200 s)
  if openssl x509 -in "$PEM_CERT" -noout -checkend 1200; then
    return 1;
  else
    printProcess "Certificate is going to expired, start renew now"
    return 0;
  fi
}

generateCSR() {
  $CURL_BIN -s -X POST "$VAULT_API_ADDR"/v1/pki/intermediate/generate/internal \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "@$PKI_SETTING" \
    | $JQ_BIN -r '.data.csr' > "$PEM_CSR"

  printStatus "CSR generated"
}

signCSRByRoot() {
  TTL=$($JQ_BIN -r '.ttl // "1h"' $PKI_SETTING)
  DATA=$($JQ_BIN -n \
    --arg csr "$(cat "$PEM_CSR")" \
    --arg ttl "$TTL" \
    "{\"csr\": \$csr,\"use_csr_values\":true,\"ttl\":\$ttl}")

  $CURL_BIN -s -X POST "$PKI_ROOT_API_ADDR"/v1/pki/root/sign-intermediate \
    -H "X-Vault-Token: $PKI_ROOT_TOKEN" -H "$CONTENT_TYPE_HEADER" \
    -d "$DATA" \
    | $JQ_BIN -r '.data.certificate' > "$PEM_CERT"

  CERT=$(cat "$PEM_CERT")
  if [ "$CERT" = "null" ] || [ -z "$CERT" ]; then
    echo "unauthorized"
    return 1;
  fi 

  return 0
}

setSignedCert() {
  DATA=$($JQ_BIN -n \
    --arg certificate "$(cat "$PEM_CERT")" \
    "{\"certificate\": \$certificate}")

  $CURL_BIN -s -X POST "$VAULT_API_ADDR"/v1/pki/intermediate/set-signed \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "$DATA"

  echo "done"
}

# Issue certificate by
# curl -X POST localhost:8200/v1/pki/issue/$role -H "X-Vault-Token: " -d '{"common_name": "$role"}'
generatePKIRole() {
  printStatus "Generate PKI Role $1"

  $CURL_BIN -s -X POST "$VAULT_API_ADDR/v1/pki/roles/$1" \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "$2"
}

# Generate token by
# curl -X POST localhost:8200/v1/auth/token/create/$role -H "X-Vault-Token: " -d '{"ttl":"15m"}'
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
  shouldResignRootCert && signCSRByRoot && setSignedCert

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
generateCSR
shouldResignRootCert && signCSRByRoot && setSignedCert

generatePolicy "resign-root-certificate" "{
  \"path\": {
    \"pki/intermediate/set-signed\": {
      \"capabilities\": [
        \"create\",
        \"update\"
      ]
    },
    \"pki/intermediate/generate/internal\": {
      \"capabilities\": [
        \"create\",
        \"update\"
      ]
    }
  }
}"

SERVICE_CHECKING_TOKEN_POLICIES='"resign-root-certificate"'
for client in $($JQ_BIN -r -c '.[]' $PKI_CLIENTS_FILE); do
  name=$(echo "$client" | $JQ_BIN -r '.name')

  if [ "$name" = "null" ]; then
    printStatus "Missing name of config $client"
  else
    generatePKIRole "$name" "$client"
    # this token role allow to issue certificate
    generateTokenRole "$name"
    generatePolicy "$name" "{\"path\":{\"pki/issue/$name\":{\"capabilities\":[\"create\",\"update\"]}}}"
    # generator to generate above token
    generatePolicy "$name-generator" "{\"path\":{\"auth/token/create/$name\":{\"capabilities\":[\"create\",\"update\"]}}}"
    SERVICE_CHECKING_TOKEN_POLICIES="$SERVICE_CHECKING_TOKEN_POLICIES,\"$name-generator\""
  fi
done

# ======================== Generate Self-checking token ========================
printStatus "Generate service checking token"
SERVICE_CHECKING_TOKEN=$($CURL_BIN -s -X POST "$VAULT_API_ADDR"/v1/auth/token/create \
  -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
  -d "{\"display_name\":\"service-checking\",\"ttl\":\"1h\",\"policies\":[$SERVICE_CHECKING_TOKEN_POLICIES]}" \
  | ${JQ_BIN} -r '.auth.client_token')

printf "\nVAULT_TOKEN=%s" "$SERVICE_CHECKING_TOKEN" >> /etc/vault.d/.cron.env
