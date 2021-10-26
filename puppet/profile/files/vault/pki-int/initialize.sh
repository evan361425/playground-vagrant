#!/usr/bin/env sh

# - MOUNT_SETTING
# - PKI_SETTING
# - CSR_FILE
# - CERT_FILE
# - PKI_CLIENTS_FILE
# - PKI_ROOT_TOKEN_FILE
# - PKI_ROOT_API_ADDR
# shellcheck source=/dev/null
. "/etc/vault.d/pki-int/.env"

. "$PKI_ROOT_TOKEN_FILE"

CURL_BIN=$(command -v curl)
JQ_BIN=$(command -v jq)

VAULT_TOKEN_HEADER="X-Vault-Token: $VAULT_TOKEN"
CONTENT_TYPE_HEADER="Content-Type: application/json"

mountPKIIfNeed() {
  RESULT=$($CURL_BIN -s -X GET "$VAULT_ADDR"/v1/sys/mounts \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    | $JQ_BIN '.data."pki/"')

  if [ "$RESULT" = "null" ]; then
    printf 'Start enable intermediate PKI... '
    $CURL_BIN -s -X POST "$VAULT_ADDR"/v1/sys/mounts/pki \
      -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
      -d "@$MOUNT_SETTING" > /dev/null
    echo 'done'
  fi
}

shouldSignRootCert() {
  if [ -z "$PKI_ROOT_TOKEN" ]; then
    echo "Root-PKI's token(PKI_ROOT_TOKEN) not found"
    return 1;
  fi

  TOKEN_NAME=$($CURL_BIN -s "$PKI_ROOT_API_ADDR"/v1/auth/token/lookup-self \
    -H "X-Vault-Token: $PKI_ROOT_TOKEN" -H "$CONTENT_TYPE_HEADER" \
    | $JQ_BIN -r '.data.display_name')
  if [ "$TOKEN_NAME" = "null" ] || [ -z "$TOKEN_NAME" ]; then
    echo "Wrong Root API Address $PKI_ROOT_API_ADDR or Wrong Token"
    return 1;
  fi
  echo "====== Start setting certificate ======="
}

generateCSR() {
  printf 'Generate CSR... '
  $CURL_BIN -s -X POST "$VAULT_ADDR"/v1/pki/intermediate/generate/internal \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "@$PKI_SETTING" \
    | $JQ_BIN -r '.data.csr' > "$CSR_FILE"

  echo 'done'
}

signCSRByRoot() {
  printf 'Send CSR to root PKI... '
  TTL=$($JQ_BIN -r '.ttl // "1h"' "$PKI_SETTING")
  DATA=$($JQ_BIN -n \
    --arg csr "$(cat "$CSR_FILE")" \
    --arg ttl "$TTL" \
    "{\"csr\": \$csr,\"use_csr_values\":true,\"ttl\":\$ttl}")

  $CURL_BIN -s -X POST "$PKI_ROOT_API_ADDR"/v1/pki/root/sign-intermediate \
    -H "X-Vault-Token: $PKI_ROOT_TOKEN" -H "$CONTENT_TYPE_HEADER" \
    -d "$DATA" \
    | $JQ_BIN -r '.data.certificate' > "$CERT_FILE"

  CERT=$(cat "$CERT_FILE")
  if [ "$CERT" = "null" ] || [ -z "$CERT" ]; then
    echo "token unauthorized"
    return 1;
  fi

  echo 'done'
  return 0
}

setSignedCert() {
  printf 'Set signed certificate to PKI... '
  DATA=$($JQ_BIN -n \
    --arg certificate "$(cat "$CERT_FILE")" \
    "{\"certificate\": \$certificate}")

  $CURL_BIN -s -X POST "$VAULT_ADDR"/v1/pki/intermediate/set-signed \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "$DATA"

  echo "done"
}

generatePKIRole() {
  $CURL_BIN -s -X POST "$VAULT_ADDR/v1/pki/roles/$1" \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "$2"
}

generatePolicy() {
  $CURL_BIN -s -X POST "$VAULT_ADDR/v1/sys/policy/$1" \
    -H "$VAULT_TOKEN_HEADER" \
    -d "$($JQ_BIN -n --arg policy "$2" "{\"policy\": \$policy}")"
}

mountPKIIfNeed
shouldSignRootCert && generateCSR && signCSRByRoot && setSignedCert

echo "====== Start setting clients ======="
for client in $($JQ_BIN -r -c '.[]' "$PKI_CLIENTS_FILE"); do
  name=$(echo "$client" | $JQ_BIN -r '.name')

  if [ "$name" = "null" ]; then
    echo "Missing name of config $client"
  else
    printf "Client \"%s\"... " "$name"

    generatePKIRole "$name" "$client"
    # this token role allow to issue certificate
    generatePolicy "pki-issue-$name" "{\"path\":{\"pki/issue/$name\":{\"capabilities\":[\"create\",\"update\"]}}}"

    echo 'done'
  fi
done
