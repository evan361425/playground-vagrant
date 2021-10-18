#!/usr/bin/env sh

EXPECT_TOKEN_NAME="${CRON_NAME:-service-checking}"
ENV_NAME="${CRON_NAME:-.cron}"

printStatus() {
  >&2 echo "$(date +"%F %T") - $1"
}

removeTokenInEnv() {
  sed '/VAULT_TOKEN/d' "/etc/vault.d/$ENV_NAME.env" > /etc/vault.d/.temp
  sed '/^$/d' /etc/vault.d/.temp > "/etc/vault.d/$ENV_NAME.env"
  rm /etc/vault.d/.temp
}

if [ -z "$VAULT_API_ADDR" ]; then
  printStatus "Missing VAULT_API_ADDR"
  exit 1
fi
if [ -z "$VAULT_TOKEN_HEADER" ]; then
  printStatus "Missing VAULT_TOKEN_HEADER"
  exit 1
fi

INIT_RESULT=$($CURL_BIN -s -X GET "$VAULT_API_ADDR"/v1/sys/init | $JQ_BIN .initialized)
if [ "${INIT_RESULT}" = "false" ]; then
  printStatus "Vault was not initialized"
  exit 1
fi

# Check token presenting
TOKEN_NAME=$($CURL_BIN -s -X GET "$VAULT_API_ADDR"/v1/auth/token/lookup-self \
  -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
  | $JQ_BIN -r '.data.display_name')
if [ "$TOKEN_NAME" = "token-$EXPECT_TOKEN_NAME" ]; then
  >&2 printf "%s - Using wanted token, start renew token..." "$(date +"%F %T")"

  $CURL_BIN -s -X POST "$VAULT_API_ADDR"/v1/auth/token/renew-self \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" > /dev/null

  >&2 echo " done"

  echo 'success'
elif [ -n "$TOKEN_NAME" ] && [ "$TOKEN_NAME" != "null" ]; then
  printStatus "Using $TOKEN_NAME token is not support"
  removeTokenInEnv
else
  printStatus "Not finding token"
  removeTokenInEnv
fi
