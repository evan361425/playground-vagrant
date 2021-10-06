#!/usr/bin/env sh

printStatus() {
  >&2 echo "$(date +"%F %T") - $1"
}

removeTokenInEnv() {
  sed '/VAULT_TOKEN/d' /etc/vault.d/.cron.env > .cron.env.temp
  sed '/^$/d' .cron.env.temp > /etc/vault.d/.cron.env
  rm .cron.env.temp
}

if [ -z "$VAULT_API_ADDR" ]; then
  printStatus "Missing VAULT_API_ADDR"
fi
if [ -z "$VAULT_TOKEN_HEADER" ]; then
  printStatus "Missing VAULT_TOKEN_HEADER"
fi

INIT_RESULT=$($CURL_BIN -s -X GET $VAULT_API_ADDR/v1/sys/init | $JQ_BIN .initialized)
if [ "${INIT_RESULT}" = "false" ]; then
  printStatus "Vault was not initialized"
  exit 1
fi

# Check token presenting
TOKEN_NAME=$($CURL_BIN -s -X GET $VAULT_API_ADDR/v1/auth/token/lookup-self \
  -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER" \
  | $JQ_BIN -r '.data.display_name')
if [ "$TOKEN_NAME" = "token-service-checking" ]; then
  >&2 echo -n "$(date +"%F %T") - Using wanted token, start renew token..."

  $CURL_BIN -s -X POST $VAULT_API_ADDR/v1/auth/token/renew-self \
    -H "$VAULT_TOKEN_HEADER" -H "$CONTENT_TYPE_HEADER"

  >&2 echo " done"
  exit 0;
elif [ "$TOKEN_NAME" != "null" ]; then
  printStatus "Using $TOKEN_NAME token is not support"
  removeTokenInEnv()

  exit 1;
fi
