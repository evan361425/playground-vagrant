#!/usr/bin/env sh

TTL="${1:-72h}" 

vault token create -policy="pki-intermediate" -orphan=true -display-name="pki-intermediate" -ttl="$TTL"
