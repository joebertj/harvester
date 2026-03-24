#!/usr/bin/env bash
# 🐒 utils/chaos-monkey.sh
# Demonstrates Argo CD Self-Healing by breaking things.

set -e

NAMESPACE="homelab"
KUBECONFIG_PATH="${KUBECONFIG:-~/.kube/harvester-k3s.yaml}"

echo "🐵 Welcome to Chaos Monkey Demo!"
echo "--------------------------------"

# Scenario 1: Kill the Homer Service
echo "🔨 Scenario 1: Deleting the 'homer' Service (Metadata Destruction)"
kubectl delete svc homer -n $NAMESPACE --kubeconfig $KUBECONFIG_PATH
echo "⏳ Wait 10 seconds for Argo CD to detect and RECREATE it..."
sleep 10
kubectl get svc homer -n $NAMESPACE --kubeconfig $KUBECONFIG_PATH

echo ""

# Scenario 2: Tamper with HPA Strategy
echo "🔨 Scenario 2: Changing HPA Simulation strategy manually (Live Patch)"
kubectl patch deployment fastapi-metrics-app -n harvester-autoscaling-sim \
  --kubeconfig $KUBECONFIG_PATH \
  --type='json' -p='[{"op": "replace", "path": "/spec/replicas", "value": 5}]'
echo "⏳ Watch Argo CD revert replicas back to '1' (from the Git Source of Truth)..."
sleep 15
kubectl get deployment fastapi-metrics-app -n harvester-autoscaling-sim --kubeconfig $KUBECONFIG_PATH

echo ""
echo "✅ Self-Healing Demo Complete! Argo CD ensured the cluster matches Git. 🥂"
