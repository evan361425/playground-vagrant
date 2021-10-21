#!/usr/bin/env sh

CURL_BIN=$(command -v curl)
JQ_BIN=$(command -v jq)

VAULT_TOKEN_HEADER="X-Vault-Token: $VAULT_TOKEN"
CONTENT_TYPE_HEADER="Content-Type: application/json"

MOUNT_FILE="/etc/vault.d/kv/mount-setting.json"
POLICY_FILE="/etc/vault.d/kv/policy-setting.json"

mountKVIfNeed() {
  name=$(echo "$1" | $JQ_BIN -r '.path // "secret"')

  result=$($CURL_BIN -s "$VAULT_ADDR"/v1/sys/mounts \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    | $JQ_BIN ".data.\"$name/\"")

  if [ "$result" = "null" ]; then
    printf 'Start enable KV engine %s... ' "$name"
    $CURL_BIN -s -X POST "$VAULT_ADDR"/v1/sys/mounts/"$name" \
      -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
      -d "$1" > /dev/null
    echo 'done'
  fi
}

generateTokenRole() {
  $CURL_BIN -s -X POST "$VAULT_ADDR/v1/auth/token/roles/$1" \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "{\"allowed_policies\":[\"$1\"]}"
}

generatePolicy() {
  $CURL_BIN -s -X POST "$VAULT_ADDR/v1/sys/policy/$1" \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "{\"policy\": $2}"
}

for mount in $($JQ_BIN -r -c '.[]' $MOUNT_FILE); do
  mountKVIfNeed "$mount"
done

for policy in $($JQ_BIN -r -c '.[]' $POLICY_FILE); do
  name=$(echo "$policy" | $JQ_BIN -r '.name // "policy"')
  printf 'Start generate %s role/policy... ' "$name"
  # this token role allow to issue certificate
  generateTokenRole "$name"
  generatePolicy "$name" "$policy"
  echo "done"
done
