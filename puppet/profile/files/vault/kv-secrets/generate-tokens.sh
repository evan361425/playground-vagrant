#!/usr/bin/env sh

# - CLIENT_SETTING
# shellcheck source=/dev/null
. "$(dirname "$0")/.env"

CURL_BIN=$(command -v curl)
JQ_BIN=$(command -v jq)

for client in $($JQ_BIN -r -c '.[]' "$CLIENT_SETTING"); do
  name=$(echo "$client" | $JQ_BIN -r '.name')
  ttl=$(echo "$client" | $JQ_BIN -r '.ttl') 
  policies=$(echo "$client" | $JQ_BIN -r -c '.policies') 

  if [ "$ttl" = "null" ] || [ -z "$ttl" ]; then
    ttl='72h'
  fi

  if [ "$policies" = "null" ] || [ -z "$policies" ]; then
    policies="[\"$name\"]"
  fi

  if [ ! "$name" = "null" ]; then
    token="$($CURL_BIN -s -X POST "$VAULT_ADDR/v1/auth/token/create-orphan" \
      -H "x-vault-token: $VAULT_TOKEN" \
      -d "{\"policies\":$policies,\"display_name\":\"$name\",\"ttl\":\"$ttl\"}" \
      | $JQ_BIN -r '.auth.client_token')"

    echo "$name=$token"
  fi
done
