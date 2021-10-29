#!/usr/bin/env sh

# shellcheck source=/dev/null
. ".env"

token=$(cat client/token.txt)

encoded_data=$(curl -s -X POST "$VAULT_ADDR/v1/transit/decrypt/aes-key" \
  -H "x-vault-token: $token" --cacert root.crt \
  -d "{\"ciphertext\":\"$1\"}" | jq -r '.data.plaintext')

echo  "$encoded_data" | base64 --decode
