#!/usr/bin/env sh

CURL_BIN=$(command -v curl)
JQ_BIN=$(command -v jq)

VAULT_TOKEN_HEADER="X-Vault-Token: $VAULT_TOKEN"
CONTENT_TYPE_HEADER="Content-Type: application/json"

generateKey() {
  result=$($CURL_BIN -s "$VAULT_ADDR/v1/transit/keys/$1" \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    | $JQ_BIN .errors)

  if [ "$result" = "[]" ]; then
    printf 'Create transit key "%s"... ' "$1"
    $CURL_BIN -s -X POST "$VAULT_ADDR/v1/transit/keys/$1" \
      -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
      -d "$2"
    echo 'done'
  fi
}

for key in $($JQ_BIN -r -c '.[]' '/etc/vault.d/secrets/transit-keys-setting.json'); do
  name=$(echo "$key" | $JQ_BIN -r '.name // "key"')
  generateKey "$name" "$key"
done
