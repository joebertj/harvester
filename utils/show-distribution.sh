#!/bin/bash
# utils/show-distribution.sh
# Comprehensive check for HPA scaling, pod distribution, and scheduling events.

NAMESPACE=${1:-"harvester-autoscaling-sim"}
HPA_NAME="fastapi-metrics-hpa"

echo "========================================================="
echo "  KUBERNETES SCALING & DISTRIBUTION REPORT"
echo "  Namespace: ${NAMESPACE}"
echo "========================================================="

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "❌ Error: Namespace '$NAMESPACE' not found."
    exit 1
fi

# 1. HPA Status Summary
echo "--- HPA STATUS ---"
if kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
    kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" \
      -o custom-columns="NAME:.metadata.name,REPLICAS:.status.currentReplicas,TARGET-REPLICAS:.status.desiredReplicas,METRIC-VALUE:.containers[0].resources.requests.cpu,MIN:.spec.minReplicas,MAX:.spec.maxReplicas" \
      --no-headers 2>/dev/null || \
    kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" --no-headers
else
    echo "⚠️ HPA '$HPA_NAME' not found in namespace '$NAMESPACE'."
fi
echo ""

# 2. Node Distribution
echo "--- POD DISTRIBUTION (Pods per Node) ---"
PODS_LIST=$(kubectl get pods -n "$NAMESPACE" -o wide --no-headers)
if [ -z "$PODS_LIST" ]; then
    echo "ℹ️ No pods found."
else
    echo "$PODS_LIST" | awk '{print $7}' | sort | uniq -c | \
      awk '{printf "  Node: %-15s | Pods: %s\n", $2, $1}'
fi
echo ""

# 3. Diagnosis for Pending Pods
PENDING_COUNT=$(echo "$PODS_LIST" | grep -c "Pending" || true)
if [ "$PENDING_COUNT" -gt 0 ]; then
    echo "--- 🔴 PENDING PODS DETECTED ($PENDING_COUNT) ---"
    FIRST_PENDING=$(echo "$PODS_LIST" | grep "Pending" | awk '{print $1}' | head -n 1)
    echo "Diagnosing first pending pod: $FIRST_PENDING"
    echo "Latest Scheduler Events:"
    kubectl describe pod "$FIRST_PENDING" -n "$NAMESPACE" | \
      sed -n '/Events:/,$p' | tail -n 5
    echo ""
    echo "💡 Recommendation: Check node taints or topologyStretchConstraints."
fi

# 4. Success Events for HPA
echo "--- RECENT HPA EVENTS ---"
kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$HPA_NAME" \
  --sort-by='.lastTimestamp' | tail -n 5 || echo "No recent HPA events found."

echo "========================================================="