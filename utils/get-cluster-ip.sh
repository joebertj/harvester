#!/bin/bash
# utils/get-cluster-ip.sh
# Identifies the outgoing NAT IP of the current Kubernetes cluster
# Useful for whitelisting Cloudflare API tokens.

set -e

POD_NAME="ip-check-$(date +%s)"

echo "🚀 Deploying temporary pod to check outgoing IP..."
kubectl run "$POD_NAME" --image=curlimages/curl --restart=Never --command -- curl -s https://ifconfig.me > /dev/null

echo "⏳ Waiting for pod to complete..."
kubectl wait --for=condition=Ready pod/"$POD_NAME" --timeout=30s > /dev/null

echo "✅ Outgoing Cluster IP:"
kubectl logs "$POD_NAME"
echo ""

echo "🧹 Cleaning up..."
kubectl delete pod "$POD_NAME" --wait=false > /dev/null
