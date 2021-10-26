#!/usr/bin/env sh

# - MOUNT_SETTING
# - PKI_SETTING
# shellcheck source=/dev/null
. "/etc/vault.d/pki-root/.env"

CURL_BIN=$(command -v curl)
JQ_BIN=$(command -v jq)

if [ -z "$VAULT_TOKEN" ]; then
  echo "Vault token (VAULT_TOKEN) not set"
  exit 1;
fi

VAULT_TOKEN_HEADER="X-Vault-Token: $VAULT_TOKEN"
CONTENT_TYPE_HEADER="Content-Type: application/json"

mountPKIIfNeed() {
  RESULT=$($CURL_BIN -s -X GET "$VAULT_ADDR"/v1/sys/mounts \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    | $JQ_BIN '.data."pki/"')

  if [ "$RESULT" = "null" ]; then
    printf 'Start enable root PKI... '
    $CURL_BIN -s -X POST "$VAULT_ADDR"/v1/sys/mounts/pki \
      -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
      -d "@$MOUNT_SETTING" > /dev/null
    echo 'done'
  fi
}

generateCertIfEmpty() {
  printf 'Start generate root certificate... '
  RESULT=$($CURL_BIN -s "$VAULT_ADDR"/v1/pki/ca/pem)

  if [ -n "$RESULT" ] && [ ! "$RESULT" = 'null' ]; then
    echo 'exist'
    return 0;
  fi

  $CURL_BIN -s -X POST "$VAULT_ADDR"/v1/pki/root/generate/internal \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "@$PKI_SETTING" \
    | $JQ_BIN '.data.certificate' > /etc/vault.d/pki-root/certificate.pem
  echo 'done'
}

generatePolicy() {
  printf "Start generate policy %s... " "$1"

  $CURL_BIN -s -X POST "$VAULT_ADDR/v1/sys/policy/$1" \
    -H "x-vault-token: $VAULT_TOKEN" \
    -d "$($JQ_BIN -n --arg policy "$2" "{\"policy\": \$policy}")"

  echo 'done'
}

mountPKIIfNeed
generateCertIfEmpty
generatePolicy "pki-intermediate" '{"path":{"pki/root/sign-intermediate":{"capabilities":["create","update"]}}}'
