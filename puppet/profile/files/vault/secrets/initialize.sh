#!/usr/bin/env sh

# - MOUNT_SETTING
# - POLICY_SETTING
# shellcheck source=/dev/null
. "/etc/vault.d/secrets/.env"

CURL_BIN=$(command -v curl)
JQ_BIN=$(command -v jq)

VAULT_TOKEN_HEADER="X-Vault-Token: $VAULT_TOKEN"
CONTENT_TYPE_HEADER="Content-Type: application/json"

mountKVIfNeed() {
  name=$(echo "$1" | $JQ_BIN -r '.path // "secret"')

  result=$($CURL_BIN -s "$VAULT_ADDR/v1/sys/mounts" \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    | $JQ_BIN ".data.\"$name/\"")

  if [ "$result" = "null" ]; then
    printf 'Start enable secrets "%s"... ' "$name"
    $CURL_BIN -s -X POST "$VAULT_ADDR/v1/sys/mounts/$name" \
      -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
      -d "$1" > /dev/null
    echo 'done'
  fi
}

generatePolicy() {
  $CURL_BIN -s -X POST "$VAULT_ADDR/v1/sys/policy/$1" \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "$($JQ_BIN -n --arg policy "$2" "{\"policy\": \$policy}")"
}

for mount in $($JQ_BIN -r -c '.[]' "$MOUNT_SETTING"); do
  mountKVIfNeed "$mount"
done

echo "====== Start setting policies ======="
for policy in $($JQ_BIN -r -c '.[]' "$POLICY_SETTING"); do
  name=$(echo "$policy" | $JQ_BIN -r '.name // "policy"')
  printf "Policy \"%s\"... " "$name"
  generatePolicy "$name" "$policy"
  echo "done"
done
