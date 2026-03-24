#!/bin/bash
# utils/taint-control.sh
# Taints the control node to repel and evict non-system workloads.
# Uses 'NoExecute' to force immediate eviction of untolerated pods.

set -e

NODE_NAME="control"
TAINT_KEY="node-role.kubernetes.io/control-plane"
EFFECT="NoExecute"

echo "==> Tainting node '${NODE_NAME}' with ${TAINT_KEY}:${EFFECT}..."

if kubectl taint nodes "$NODE_NAME" "${TAINT_KEY}:${EFFECT}" --overwrite; then
    echo "✅ Successfully tainted '${NODE_NAME}'."
    echo "    (Existing pods will be evicted unless they have a matching toleration)."
else
    echo "❌ Failed to taint node '${NODE_NAME}'."
    exit 1
fi

echo ""
echo "Verifying Taints:"
kubectl describe node "$NODE_NAME" | grep Taints

echo ""
echo "Showing current distribution after re-scheduling..."
"$(dirname "$0")/show-distribution.sh"
