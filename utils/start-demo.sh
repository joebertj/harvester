#!/usr/bin/env bash
# utils/start-demo.sh
# Starts the HPA scaling simulation via GitOps (declarative creation).

set -e

# Get the absolute path to the repository root
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP_MANIFEST="$REPO_ROOT/argo/argocd/applications/hpa-simulation.yaml"

echo "========================================================="
echo "  STARTING HPA SCALING SIMULATION (GITOPS)"
echo "========================================================="

DISABLED_MANIFEST="$(dirname "$APP_MANIFEST")/disabled/hpa-simulation.yaml.disabled"

if [ -f "$DISABLED_MANIFEST" ]; then
    echo "⏳ Restoring manifest from 'disabled' folder..."
    git mv "$DISABLED_MANIFEST" "$APP_MANIFEST"
else
    echo "⏳ Creating HPA Simulation manifest from inline template..."
    # Recreate the application manifest
    cat <<EOF > "$APP_MANIFEST"
---
# hpa-simulation-app.yaml — Argo CD Application for the HPA Scale Demo
# Strategy can be switched by changing the 'path' below

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hpa-simulation
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/joebertj/harvester.git
    targetRevision: main
    path: scaling/base
  destination:
    server: https://kubernetes.default.svc
    namespace: harvester-autoscaling-sim
  syncPolicy:
    automated:
      prune: true
      selfHeal: true # Production Standard: Safe now that replicas are omitted from Git
    syncOptions:
      - CreateNamespace=true
  ignoreDifferences:
    - group: apps
      kind: Deployment
      name: fastapi-metrics-app
      jsonPointers:
        - /spec/replicas
EOF

echo "🚀 Pushing HPA Simulation manifest to Git..."
git add "$APP_MANIFEST"
git commit -m "chore: start HPA simulation demo by creating application manifest"
git push

echo ""
echo "✅ Demo started via GitOps!"
echo "👉 Argo CD will create the resources in ~1-2 minutes."
echo "========================================================="
