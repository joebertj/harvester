#!/bin/bash
# utils/stop-demo.sh
# Stops the HPA scaling simulation and cleans up all resources.

NAMESPACE="harvester-autoscaling-sim"

echo "========================================================="
echo "  STOPPING HPA SCALING SIMULATION"
echo "========================================================="

if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "⏳ Deleting namespace: $NAMESPACE"
    echo "   (This will remove the Deployment, HPA, and Service)"
    kubectl delete namespace "$NAMESPACE" --wait=true
    echo ""
    echo "✅ Teardown complete."
else
    echo "ℹ️ Namespace '$NAMESPACE' not found. Simulation is not running."
fi

echo "========================================================="
