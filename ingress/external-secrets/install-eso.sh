#!/bin/bash
# Install External Secrets Operator (ESO) on k3s
# ESO syncs secrets from Vault → Kubernetes Secrets

set -e

echo "==> Adding External Secrets Helm repo..."
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

echo "==> Installing External Secrets Operator..."
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --set installCRDs=true \
  --wait

echo "==> Waiting for ESO to be ready..."
kubectl rollout status deployment/external-secrets -n external-secrets

echo "✅ External Secrets Operator installed!"
echo "Next: kubectl apply -f vault-secretstore.yaml && kubectl apply -f cloudflare-externalsecret.yaml"
