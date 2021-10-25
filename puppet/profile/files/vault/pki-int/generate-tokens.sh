#!/usr/bin/env sh

# - PKI_CLIENTS_FILE
# shellcheck source=/dev/null
. "/etc/vault.d/pki-int/.env"

CURL_BIN=$(command -v curl)
JQ_BIN=$(command -v jq)

TTL="${1:-72h}" 

for client in $($JQ_BIN -r -c '.[]' "$PKI_CLIENTS_FILE"); do
  name=$(echo "$client" | $JQ_BIN -r '.name')

  if [ ! "$name" = "null" ]; then
    token="$($CURL_BIN -s -X POST "$VAULT_ADDR/v1/auth/token/create-orphan" \
      -H "x-vault-token: $VAULT_TOKEN" \
      -d "{\"policies\":[\"pki-issue-$name\"],\"display_name\":\"pki-issue-$name\",\"ttl\":\"$TTL\"}" \
      | $JQ_BIN -r '.auth.client_token')"

    echo "$name=$token"
  fi
done
