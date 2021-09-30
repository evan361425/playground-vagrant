#!/usr/bin/env sh

startAttempt()
{
  $CURL_BIN -s -X PUT $VAULT_API_ADDR/v1/sys/generate-root/attempt
}

restartAttempt()
{
  $CURL_BIN -s -X DELETE $VAULT_API_ADDR/v1/sys/generate-root/attempt
  startAttempt
}

attemptRecoverKey()
{
  $CURL_BIN -s -X PUT $VAULT_API_ADDR/v1/sys/generate-root/update \
    -H "Content-Type: application/json" \
    -d "{\"key\": \"$1\", \"nonce\": \"$2\"}"
}

printStatus() {
  >&2 echo "$(date +"%F %T") - $1"
}

# Using recovery keys to generate root token
RESPONSE=$(startAttempt)
# Reset progress if needed
if [ "$(echo $RESPONSE | $JQ_BIN -r '.errors[0]'))" = 'root generation already in progress' ]; then
  printStatus "Reattempt root token generate process"
  RESPONSE=$(restartAttempt)
fi

OTP=$(echo $RESPONSE | $JQ_BIN -r '.otp')
NONCE=$(echo $RESPONSE | $JQ_BIN -r '.nonce')
REQUIRED_COUNT=$(echo $RESPONSE | $JQ_BIN '.required')

# Check recovery keys count
COUNT=$(echo $VAULT_RECOVERY_KEYS | tr -cd ',' | wc -c)
COUNT=$((COUNT+1))
printStatus "Get $COUNT recovery key(s)"
if [ "$REQUIRED_COUNT" -gt $COUNT ]; then
  printStatus "Recovery keys need $REQUIRED_COUNT"
  exit 1
fi

# Enter keys one by one
KEYS_ARRAY=$(echo $VAULT_RECOVERY_KEYS | tr "," " ")
for KEY in $KEYS_ARRAY; do
  ENCODED_TOKEN=$(attemptRecoverKey $KEY $NONCE | $JQ_BIN -r '.encoded_token')

  if [ "$ENCODED_TOKEN" != "null" ] && [ ! -z "$ENCODED_TOKEN" ]; then
    VAULT_ROOT_TOKEN=$(VAULT_ADDR="$VAULT_API_ADDR" vault operator generate-root -decode=$ENCODED_TOKEN -otp=$OTP)
    break
  fi
done

if [ -z "$VAULT_ROOT_TOKEN" ]; then
  printStatus "Wrong recovery keys"
  exit 1
fi

printStatus "Generated root token"
echo $VAULT_ROOT_TOKEN
