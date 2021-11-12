#!/usr/bin/env sh

# shellcheck source=/dev/null
. ".env"

token=$(cat client/token.txt)
encoded_data=$( echo  "$1" | base64 )

curl -s -X POST "localhost:8100/v1/transit/encrypt/aes-key" \
  -H "x-vault-token: $token" \
  -d "{\"plaintext\":\"$encoded_data\"}" | jq '.data'
