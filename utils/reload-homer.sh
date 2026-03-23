#!/usr/bin/env bash
set -e

# Get the absolute path to the repository root so the script can be run from anywhere
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)

echo "Applying Homer ConfigMap..."
kubectl apply -f "$REPO_ROOT/ingress/homer/homer-configmap.yaml"

echo "Restarting Homer deployment to pick up the new configuration..."
kubectl rollout restart deployment homer -n homelab

echo "Waiting for Homer to be ready..."
kubectl rollout status deployment homer -n homelab

echo "✅ Homer dashboard successfully reloaded!"
