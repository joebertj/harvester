#!/bin/bash
# utils/show-distribution.sh
# Comprehensive check for HPA scaling, pod distribution, and scheduling events.

NAMESPACE=${1:-"harvester-autoscaling-sim"}
HPA_NAME="fastapi-metrics-hpa"

echo "========================================================="
echo "  KUBERNETES SCALING & DISTRIBUTION REPORT"
echo "========================================================="

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "❌ Error: Namespace '$NAMESPACE' not found."
    exit 1
fi

# 1. Current Load Metric (On Top)
echo "--- CURRENT METRIC LOAD ---"
METRIC_DATA=$(kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" -o jsonpath='{.status.currentMetrics[0].pods.currentAverageValue}' 2>/dev/null || echo "N/A")
if [ "$METRIC_DATA" == "N/A" ]; then
    # Fallback for older HPA versions or annotations
    METRIC_DATA=$(kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.autoscaling\.alpha\.kubernetes\.io/current-metrics}' 2>/dev/null | jq -r '.[0].pods.currentAverageValue' 2>/dev/null || echo "Unknown")
fi
echo "  Metric: simulated_user_load | Current Value: ${METRIC_DATA}"
echo ""

# 2. HPA Status Summary
echo "--- HPA STATUS & TARGETS ---"
if kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
    printf "  %-20s %-10s %-10s %-10s %-10s\n" "NAME" "CURR" "DESIRED" "MIN" "MAX"
    kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" \
      -o custom-columns="NAME:.metadata.name,CURR:.status.currentReplicas,DESIRED:.status.desiredReplicas,MIN:.spec.minReplicas,MAX:.spec.maxReplicas" \
      --no-headers
else
    echo "⚠️ HPA '$HPA_NAME' not found in namespace '$NAMESPACE'."
fi
echo ""

# 3. Node Distribution
echo "--- POD DISTRIBUTION (Pods per Node) ---"
PODS_LIST=$(kubectl get pods -n "$NAMESPACE" -o wide --no-headers)
if [ -z "$PODS_LIST" ]; then
    echo "ℹ️ No pods found."
else
    echo "$PODS_LIST" | awk '{print $7}' | sort | uniq -c | \
      awk '{printf "  Node: %-15s | Pods: %s\n", $2, $1}'
fi
echo ""

# 4. Diagnosis for Pending Pods
PENDING_COUNT=$(echo "$PODS_LIST" | grep -c "Pending" || true)
if [ "$PENDING_COUNT" -gt 0 ]; then
    echo "--- 🔴 PENDING PODS DETECTED ($PENDING_COUNT) ---"
    FIRST_PENDING=$(echo "$PODS_LIST" | grep "Pending" | awk '{print $1}' | head -n 1)
    echo "Diagnosing first pending pod: $FIRST_PENDING"
    echo "Latest Scheduler Events:"
    kubectl describe pod "$FIRST_PENDING" -n "$NAMESPACE" | \
      sed -n '/Events:/,$p' | tail -n 5
    echo ""
fi

# 5. Recent HPA Events
echo "--- RECENT HPA EVENTS ---"
kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$HPA_NAME" \
  --sort-by='.lastTimestamp' | tail -n 5 || echo "No recent HPA events found."

echo "========================================================="