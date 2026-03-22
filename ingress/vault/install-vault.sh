#!/bin/bash
# Install HashiCorp Vault on k3s via Helm
# Run from your workstation or directly on 192.168.2.123

set -e

# --- Prerequisites check ---
echo "==> Checking prerequisites..."

if ! command -v helm &>/dev/null; then
  echo "❌ helm not found. Install it from https://helm.sh/docs/intro/install/"
  echo "   macOS:  brew install helm"
  echo "   Linux:  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
  exit 1
fi
echo "  ✅ helm $(helm version --short)"

if ! command -v kubectl &>/dev/null; then
  echo "❌ kubectl not found. Install it from https://kubernetes.io/docs/tasks/tools/"
  exit 1
fi
echo "  ✅ kubectl $(kubectl version --client --short 2>/dev/null || kubectl version --client)"

if ! kubectl cluster-info &>/dev/null; then
  echo "❌ Cannot reach k3s cluster. Run: source ../../../utils/kube-config.sh"
  exit 1
fi
echo "  ✅ cluster reachable"
echo ""

echo "==> Adding HashiCorp Helm repo..."
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

echo "==> Installing Vault..."
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --values vault-values.yaml \
  --wait

echo "==> Waiting for Vault pod to be Running..."
kubectl wait --namespace vault \
  --for=condition=Ready pod/vault-0 \
  --timeout=120s

echo ""
echo "Vault installed! Next step: run ./init-vault.sh to initialize and configure Vault."
