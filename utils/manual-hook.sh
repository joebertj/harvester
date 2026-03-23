#!/bin/bash

# Usage: ./utils/manual-hook.sh [branch_name]
# Default branch is 'main'

BRANCH=${1:-main}
WEBHOOK_URL="https://webhook.home.kenchlightyear.com/push"

echo "🚀 Triggering Argo Webhook for hpa-app (branch: $BRANCH)..."

RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"ref\": \"refs/heads/$BRANCH\"}")

if [[ "$RESPONSE" == *"success"* ]]; then
    echo "✅ Webhook accepted by Argo Events!"
    echo "⏳ Waiting for workflow to appear..."
    sleep 3
    kubectl get workflow -n argo --sort-by='.metadata.creationTimestamp' | tail -n 5
else
    echo "❌ Webhook failed: $RESPONSE"
    exit 1
fi
