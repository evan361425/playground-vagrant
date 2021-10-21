#!/usr/bin/env sh

which vault || exit 1

if [ -z "$VAULT_ADDR" ]; then
  echo "Vault address (VAULT_ADDR) not set"
  exit 1;
fi

CURL_BIN=$(command -v curl)
JQ_BIN=$(command -v jq)

if [ "$(vault status --format=json | $JQ_BIN .initialized)" = "true" ]; then
  echo 'Vault is already initialized'
  exit 1
fi

echo 'Start initialize...'
RESULT="$(vault operator init -format=json -recovery-shares=5 -recovery-threshold=3)"
printf "\n%s\n" "$RESULT";

VAULT_TOKEN="$(echo "$RESULT" | $JQ_BIN .root_token)"

if [ -f '/etc/vault.d/audit-setting.json' ] && [ -s '/etc/vault.d/audit-setting.json' ]; then
  printf 'Start enable audit... '
  $CURL_BIN -s -X PUT "$VAULT_ADDR/v1/sys/audit/log-file" -H "x-vault-token: $VAULT_TOKEN" -d '@/etc/vault.d/audit-setting.json'
  echo 'done'
fi

for script in $($JQ_BIN -r -c '.[]' '/etc/vault.d/extra-scripts.json'); do
  if [ -n "$script" ]; then
    echo "====== Start execute $script ======"
    # shellcheck source=/dev/null
    . "/etc/vault.d/scripts/$script.sh"
    echo "====== done ======"
  fi
done
