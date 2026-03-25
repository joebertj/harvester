#!/bin/bash
# utils/vault-check.sh — Helper script to verify and update Vault policies for ESO

set -e

POLICY_NAME="eso-policy"
ROLE_NAME="eso-role"
TEMP_POLICY="/tmp/eso-policy.hcl"

# Set VAULT_ADDR if not set
export VAULT_ADDR=${VAULT_ADDR:-"https://vault.home.kenchlightyear.com"}

echo "Using VAULT_ADDR: $VAULT_ADDR"
echo "Checking Vault policy: $POLICY_NAME..."

cat <<EOF > $TEMP_POLICY
path "homelab/data/cloudflare" { capabilities = ["read"] }
path "homelab/data/harbor" { capabilities = ["read"] }
path "homelab/data/monitoring/grafana" { capabilities = ["read"] }
path "homelab/data/cert-manager/config" { capabilities = ["read"] }
path "homelab/data/argocd/admin" { capabilities = ["read"] }
path "homelab/data/argocd/workflow" { capabilities = ["read"] }
path "homelab/data/headlamp" { capabilities = ["read"] }
path "homelab/data/k3os" { capabilities = ["read"] }
path "homelab/data/ssh" { capabilities = ["read"] }
path "homelab/data/github-webhook" { capabilities = ["read"] }
path "homelab/data/wireguard/*" { capabilities = ["read"] }
EOF

vault policy write $POLICY_NAME $TEMP_POLICY
rm $TEMP_POLICY

echo "Success! Policy $POLICY_NAME updated."

echo "Verifying role: $ROLE_NAME..."
vault read auth/kubernetes/role/$ROLE_NAME | grep -E "policies|bound_service_account"

echo "Done."
