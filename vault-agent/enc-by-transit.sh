#!/usr/bin/env sh

# shellcheck source=/dev/null
. ".env"

token=$(cat client/token.txt)
encoded_data=$( echo  "$1" | base64 )

curl -s -X POST "$VAULT_ADDR/v1/transit/encrypt/aes-key" \
  -H "x-vault-token: $token" --cacert root.crt \
  -d "{\"plaintext\":\"$encoded_data\"}" | jq '.data'
