#!/usr/bin/env sh

which vault > /dev/null || exit 1

# shellcheck source=/dev/null
. "/etc/vault.d/.env"

CURL_BIN=$(command -v curl)
JQ_BIN=$(command -v jq)

vault status > /dev/null 2>&1
if [ "$?" -eq "1" ]; then
  echo "Vault server not found, VAULT_ADDR=$VAULT_ADDR"
  exit 1
fi

if [ "$(vault status --format=json | $JQ_BIN .initialized)" = "true" ]; then
  echo 'Vault is already initialized'
  exit 1
fi

echo 'Start initialize...'
RESULT="$(vault operator init -format=json -recovery-shares=5 -recovery-threshold=3)"
echo "$RESULT";

VAULT_TOKEN="$(echo "$RESULT" | $JQ_BIN -r .root_token)"

# Wait for initialize
sleep 3
echo 'Vault is ready now!'

if [ -f '/etc/vault.d/audit-setting.json' ] && [ -s '/etc/vault.d/audit-setting.json' ]; then
  printf 'Start enable audit... '
  $CURL_BIN -s -X PUT "$VAULT_ADDR/v1/sys/audit/log-file" -H "x-vault-token: $VAULT_TOKEN" -d '@/etc/vault.d/audit-setting.json'
  echo 'done'
fi

for script in $($JQ_BIN -r -c '.[]' '/etc/vault.d/extra-scripts.json'); do
  if [ -n "$script" ]; then
    echo "====== Start execute $script ======"
    # shellcheck source=/dev/null
    . "/etc/vault.d/$script.sh"
    echo "====== done ======"
  fi
done
