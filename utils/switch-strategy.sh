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

if [ "$STRATEGY" == "base" ]; then
    NEW_PATH="scaling/base"
else
    NEW_PATH="scaling/overlays/$STRATEGY"
fi

APP_MANIFEST="$REPO_ROOT/argo/argocd/applications/hpa-simulation.yaml"

if [ ! -d "$REPO_ROOT/$NEW_PATH" ]; then
    echo "❌ Error: Strategy directory not found: $NEW_PATH"
    echo "Usage: ./utils/switch-strategy.sh [base|topology-spread|node-affinity|pod-anti-affinity]"
    exit 1
fi

echo "🚀 Switching GitOps strategy to: $STRATEGY"
echo "📝 Updating manifest: $APP_MANIFEST"

# Update the path in the Argo CD Application manifest
sed -i.bak "s|path: .*|path: $NEW_PATH|g" "$APP_MANIFEST" && rm "$APP_MANIFEST.bak"

echo "💾 Committing and pushing changes..."
git add "$APP_MANIFEST"
git commit -m "chore: switch HPA strategy to $STRATEGY via GitOps"
git push

echo ""
echo "✅ GitOps manifest updated and pushed!"
echo "👉 Argo CD will sync the new strategy in ~3 minutes."
echo "   (Or click REFRESH in the Argo CD UI for instant application)"
