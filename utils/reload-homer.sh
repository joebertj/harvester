#!/usr/bin/env bash
set -e

# Get the absolute path to the repository root so the script can be run from anywhere
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)


# Determine namespace (homelab for Harvester, dashboard for DO)
if kubectl get ns dashboard >/dev/null 2>&1; then
  NAMESPACE="dashboard"
  CONFIG_FILE="$REPO_ROOT/ingress/homer/homer-configmap.yaml"
elif kubectl get ns homelab >/dev/null 2>&1; then
  NAMESPACE="homelab"
  CONFIG_FILE="$REPO_ROOT/ingress/homer/homer-configmap.yaml"
else
  echo "❌ Error: Could not find 'homelab' or 'dashboard' namespace."
  exit 1
fi

echo "🚀 Reloading Homer in namespace: $NAMESPACE"

echo "Applying Homer ConfigMap..."
kubectl apply -f "$CONFIG_FILE" -n "$NAMESPACE"

echo "Applying Homer Assets ConfigMap..."
kubectl create configmap homer-assets \
  --from-file=index.html="$REPO_ROOT/ingress/homer/index.html" \
  --from-file=preview.png="$REPO_ROOT/ingress/homer/preview.png" \
  -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "Restarting Homer deployment..."
kubectl rollout restart deployment homer -n "$NAMESPACE"

echo "Waiting for Homer to be ready..."
kubectl rollout status deployment homer -n "$NAMESPACE"

echo "✅ Homer dashboard successfully reloaded in $NAMESPACE!"
