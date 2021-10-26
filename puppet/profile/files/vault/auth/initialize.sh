#!/usr/bin/env sh

# - MOUNT_SETTING
# - POLICY_SETTING
# shellcheck source=/dev/null
. "/etc/vault.d/auth/.env"

CURL_BIN=$(command -v curl)
JQ_BIN=$(command -v jq)

VAULT_TOKEN_HEADER="X-Vault-Token: $VAULT_TOKEN"
CONTENT_TYPE_HEADER="Content-Type: application/json"

listMounts() {
  $CURL_BIN -s "$VAULT_ADDR/v1/sys/auth" \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    | $JQ_BIN '.data'
}

mountAuth() {
  $CURL_BIN -s -X POST "$VAULT_ADDR/v1/sys/auth/$1" \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "$2"
}

configAuth() {
  $CURL_BIN -s -X POST "$VAULT_ADDR/v1/auth/$1/config" \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "$2"
}

certSetting() {
  for cert in $(echo "$2" | $JQ_BIN -r -c '.[]'); do
    name=$(echo "$cert" | $JQ_BIN -r '.name')
    certificate_file=$(echo "$cert" | $JQ_BIN -r '.certificate_file')
    if [ ! "$certificate_file" = "null" ]; then
      certificate=$(cat "$certificate_file")
      cert=$(echo "$cert" | $JQ_BIN -r -c ".certificate = \"$certificate\"")
    fi

    printf "Setting cert \"%s\"... " "$name"
    $CURL_BIN -s -X POST "$VAULT_ADDR/v1/auth/$1/certs/$name" \
      -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
      -d "$cert"
    echo "done"
  done
}

mounts=$(listMounts)
for mount in $($JQ_BIN -r -c '.[]' "$MOUNT_SETTING"); do
  path=$(echo "$mount" | $JQ_BIN -r '.path')
  if [ "$path" = "null" ]; then
    echo "Missing path value while mounting auth"
    continue
  fi

  printf 'Auth method "%s" ' "$path"

  exist=$(echo "$mounts" | $JQ_BIN -r ".\"$path/\"")
  if [ "$exist" = "null" ]; then
    printf 'mounting... '
    mountAuth "$path" "$mount"
  fi

  extra=$(echo "$mount" | $JQ_BIN -r -c '.extra')
  if [ ! "$extra" = "null" ]; then
    printf 'configuring... '
    configAuth "$path" "$extra"
  fi

  echo 'done'

  certs=$(echo "$extra" | $JQ_BIN -r -c '.certs')
  if [ ! "$certs" = "null" ]; then
    certSetting "$path" "$certs"
  fi
done

for policy in $($JQ_BIN -r -c '.[]' "$POLICY_SETTING"); do
  name=$(echo "$policy" | $JQ_BIN -r '.name // "policy"')
  printf "Policy \"%s\"... " "$name"
  $CURL_BIN -s -X POST "$VAULT_ADDR/v1/sys/policy/$name" \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
    -d "$($JQ_BIN -n --arg policy "$policy" "{\"policy\": \$policy}")"
  echo "done"
done
