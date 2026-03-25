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
    echo "⏳ Removing Argo CD Application manifest: $APP_MANIFEST"
    
    # We remove the file from Git to stop the managed app
    git rm "$APP_MANIFEST"
    git commit -m "chore: stop HPA simulation demo by removing app manifest"
    git push

    echo ""
    echo "✅ Teardown triggered via GitOps!"
    echo "👉 Argo CD will prune the resources in ~3 minutes."
else
    echo "ℹ️  HPA Simulation app manifest not found. It might already be stopped."
fi

echo "========================================================="
