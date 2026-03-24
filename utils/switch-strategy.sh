#!/bin/bash

# -----------------------------------------------------------------------------
# Utility: switch-strategy.sh
# 
# Usage: ./utils/switch-strategy.sh [strategy-name]
# Example: ./utils/switch-strategy.sh node-affinity
#
# This script switches the HPA deployment strategy while preserving the 
# current image tag (preventing manual applies from reverting to old images).
# -----------------------------------------------------------------------------

STRATEGY=$1
NAMESPACE="harvester-autoscaling-sim"
DEPLOYMENT="fastapi-metrics-app"

if [ -z "$STRATEGY" ]; then
    echo "Usage: ./utils/switch-strategy.sh [topology-spread | node-affinity | pod-anti-affinity]"
    exit 1
fi

YAML_FILE="scaling/hpa-$STRATEGY.yaml"

if [ ! -f "$YAML_FILE" ]; then
    echo "❌ Error: Strategy file not found: $YAML_FILE"
    exit 1
fi

# 1. Get the CURRENTLY ACTIVE image from the cluster
CURRENT_IMAGE=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)

# Fallback if deployment doesn't exist yet (use a default)
if [ -z "$CURRENT_IMAGE" ]; then
    CURRENT_IMAGE="registry.home.kenchlightyear.com/library/scaling-fastapi:latest"
fi

echo "🚀 Switching to strategy: $STRATEGY"
echo "📦 Preserving current image: $CURRENT_IMAGE"

# 2. Apply the YAML while injecting the current image
# We use a temporary file to avoid altering the source YAML
cat "$YAML_FILE" | sed "s|image: .*|image: $CURRENT_IMAGE|g" | kubectl apply -f -

echo "✅ Strategy applied successfully!"
