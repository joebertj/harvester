#!/usr/bin/env bash
# utils/stop-demo.sh
# Stops the HPA scaling simulation via GitOps (declarative removal).

set -e

# Get the absolute path to the repository root
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP_MANIFEST="$REPO_ROOT/argo/argocd/applications/hpa-simulation.yaml"

echo "========================================================="
echo "  STOPPING HPA SCALING SIMULATION (GITOPS)"
echo "========================================================="

if [ -f "$APP_MANIFEST" ]; then
    echo "⏳ Moving HPA Simulation manifest to 'disabled' folder..."
    mkdir -p "$(dirname "$APP_MANIFEST")/disabled"
    git mv "$APP_MANIFEST" "$(dirname "$APP_MANIFEST")/disabled/hpa-simulation.yaml.disabled"
    git commit -m "chore: disable HPA simulation demo by moving manifest"
    git push

    echo ""
    echo "✅ Teardown triggered via GitOps (Manifest moved to disabled/ folder)!"
    echo "👉 Argo CD will prune the resources in ~3 minutes."
else
    echo "ℹ️  HPA Simulation app manifest not found. It might already be stopped."
fi

echo "========================================================="
