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
  echo "🚀 Triggering Argo Webhook for omada (branch: $BRANCH)..."
else
  WEBHOOK_URL="https://webhook.home.kenchlightyear.com/push"
  echo "🚀 Triggering Argo Webhook for hpa-app (branch: $BRANCH)..."
fi

RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"ref\": \"refs/heads/$BRANCH\"}")

if [[ "$RESPONSE" == *"success"* ]]; then
    echo "✅ Webhook accepted by Argo Events!"
    echo "⏳ Waiting for workflow to appear..."
    sleep 3
    if [[ "$TARGET" == "omada" ]]; then
      kubectl get workflow -n argo --sort-by='.metadata.creationTimestamp' | rg "omada-ci-" | tail -n 5 || true
    else
      # Preserve original behavior for hpa-app: show last workflows
      kubectl get workflow -n argo --sort-by='.metadata.creationTimestamp' | tail -n 5
    fi
else
    echo "❌ Webhook failed: $RESPONSE"
    exit 1
fi
