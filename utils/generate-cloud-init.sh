#!/bin/bash
# Generates a real cloud-init file from a template by pulling secrets from Vault
# Usage: ./utils/generate-cloud-init.sh cloud-init/work-1.yaml > work-1-real.yaml
# The output file should NOT be committed to git.

set -e

TEMPLATE=${1:-work-1.yaml}
VAULT_ADDR=${VAULT_ADDR:-"http://192.168.2.123:8200"}  # or use kubectl port-forward

if ! command -v vault &>/dev/null; then
  echo "Error: vault CLI not found. Install from https://developer.hashicorp.com/vault/downloads"
  exit 1
fi

echo "==> Fetching k3os secrets from Vault..."

K3OS_PASSWORD=$(vault kv get -field=password homelab/k3os)
K3OS_TOKEN=$(vault kv get -field=token homelab/k3os)
SSH_AUTHORIZED_KEY=$(vault kv get -field=authorized_key homelab/ssh)

sed \
  -e "s|__K3OS_PASSWORD__|${K3OS_PASSWORD}|g" \
  -e "s|__K3OS_TOKEN__|${K3OS_TOKEN}|g" \
  -e "s|__SSH_AUTHORIZED_KEY__|${SSH_AUTHORIZED_KEY}|g" \
  "${TEMPLATE}"

echo "# Generated from ${TEMPLATE} — do not commit" >&2
