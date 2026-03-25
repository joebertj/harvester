#!/bin/bash

# Usage:
#   ./utils/manual-hook.sh [branch_name]
#   ./utils/manual-hook.sh omada [branch_name]
# Default branch is 'main'

ARG1=${1:-main}

if [[ "$ARG1" == "omada" ]]; then
  TARGET="omada"
  BRANCH=${2:-main}
else
  TARGET="hpa-app"
  BRANCH=$ARG1
fi

if [[ "$TARGET" == "omada" ]]; then
  WEBHOOK_URL="https://webhook.home.kenchlightyear.com/push-omada"
  WORKFLOW_PREFIX="omada-ci-"
  echo "🚀 Triggering Argo Webhook for omada (branch: $BRANCH)..."
else
  WEBHOOK_URL="https://webhook.home.kenchlightyear.com/push"
  WORKFLOW_PREFIX="hpa-app-ci-"
  echo "🚀 Triggering Argo Webhook for hpa-app (branch: $BRANCH)..."
fi

RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"ref\": \"refs/heads/$BRANCH\"}")

if [[ "$RESPONSE" == *"success"* ]]; then
    echo "✅ Webhook accepted by Argo Events!"
    echo "⏳ Waiting for workflow to appear..."
    sleep 3
    kubectl get workflow -n argo --sort-by='.metadata.creationTimestamp' | rg "${WORKFLOW_PREFIX}" | tail -n 5 || true
else
    echo "❌ Webhook failed: $RESPONSE"
    exit 1
fi
