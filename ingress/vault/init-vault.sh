#!/bin/bash
# Initialize Vault, set up Kubernetes auth, and store all secrets.
# Run this AFTER install-vault.sh completes.
#
# Secrets are read from environment variables if set (via secrets.env),
# otherwise you will be prompted interactively.
#
# Usage:
#   source ../../ansible/secrets.env && ./init-vault.sh
#   OR just: ./init-vault.sh  (will prompt for each value)

set -e

VAULT_NAMESPACE="vault"
VAULT_POD="vault-0"

# Helper: use env var if set, otherwise prompt
require_secret() {
  local var_name="$1"
  local prompt_text="$2"
  local silent="${3:-true}"

  if [[ -n "${!var_name}" ]]; then
    echo "  ✅ ${var_name} (from env)"
  else
    if [[ "$silent" == "true" ]]; then
      read -s -p "${prompt_text}: " value && echo ""
    else
      read -p "${prompt_text}: " value
    fi
    export "${var_name}"="${value}"
  fi
}

echo "==> Collecting secrets (using env vars from secrets.env if available)..."
require_secret "CF_API_TOKEN"       "Cloudflare API token"          true
require_secret "K3OS_PASSWORD"      "k3os node password"            true
require_secret "K3OS_TOKEN"         "k3s cluster join token"        true
require_secret "SSH_AUTHORIZED_KEY" "SSH public key (ssh-rsa ...)"  false
echo ""

echo "==> Step 1: Initialize Vault (only run once!)"
kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- vault operator init \
  -key-shares=1 \
  -key-threshold=1 \
  -format=json > vault-init.json

echo ""
echo "⚠️  IMPORTANT: vault-init.json contains your unseal key and root token."
echo "    Back this up to a password manager and do NOT commit it to git."
echo ""

UNSEAL_KEY=$(python3 -c "import sys,json; d=json.load(open('vault-init.json')); print(d['unseal_keys_b64'][0])")
ROOT_TOKEN=$(python3 -c "import sys,json; d=json.load(open('vault-init.json')); print(d['root_token'])")

echo "==> Step 2: Unseal Vault"
kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- vault operator unseal ${UNSEAL_KEY}

echo "==> Step 3: Log in with root token"
kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- vault login ${ROOT_TOKEN}

echo "==> Step 4: Enable KV v2 secrets engine"
kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- vault secrets enable -path=homelab kv-v2 || true

echo "==> Step 5a: Store Cloudflare API token"
kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- \
  vault kv put homelab/cloudflare api-token="${CF_API_TOKEN}"
echo "✅ homelab/cloudflare"

echo "==> Step 5b: Store k3os credentials"
kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- \
  vault kv put homelab/k3os \
    password="${K3OS_PASSWORD}" \
    token="${K3OS_TOKEN}"
echo "✅ homelab/k3os"

echo "==> Step 5c: Store SSH authorized key"
kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- \
  vault kv put homelab/ssh \
    authorized_key="${SSH_AUTHORIZED_KEY}"
echo "✅ homelab/ssh"

echo "==> Step 6: Create ESO policy"
kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- vault policy write eso-policy - <<EOF
path "homelab/data/cloudflare"   { capabilities = ["read"] }
path "homelab/data/k3os"         { capabilities = ["read"] }
path "homelab/data/ssh"          { capabilities = ["read"] }
path "homelab/data/wireguard/*"  { capabilities = ["read"] }
EOF

echo "==> Step 7: Enable Kubernetes auth"
kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- vault auth enable kubernetes || true

echo "==> Step 8: Configure Kubernetes auth"
KUBE_HOST=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}')
kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- vault write auth/kubernetes/config \
  kubernetes_host="${KUBE_HOST}"

echo "==> Step 9: Create ESO Kubernetes auth role"
kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- vault write auth/kubernetes/role/eso-role \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  policies=eso-policy \
  ttl=1h

echo ""
echo "✅ Vault initialized and configured!"
echo ""
echo "Next:"
echo "  1. Back up vault-init.json → password manager, then: rm vault-init.json"
echo "  2. cd ../external-secrets && ./install-eso.sh"
echo "  3. kubectl apply -f ../external-secrets/"
