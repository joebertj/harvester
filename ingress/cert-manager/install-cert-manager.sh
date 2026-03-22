#!/bin/bash
# Install cert-manager via Helm
# Run this from your k3s node or any machine with kubectl access

# Add the Jetstack Helm repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager with CRDs
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.14.4 \
  --set crds.enabled=true

# Wait for cert-manager to be ready
kubectl rollout status deployment/cert-manager -n cert-manager
kubectl rollout status deployment/cert-manager-webhook -n cert-manager

echo "cert-manager installed successfully!"
echo "Next: apply cloudflare-secret.yaml and clusterissuer.yaml"
