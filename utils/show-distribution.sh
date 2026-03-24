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

# 1. Real-time Metric Load (Direct from Pod)
echo "--- REAL-TIME METRIC LOAD (Direct from Pod) ---"
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=fastapi-metrics --field-selector=status.phase=Running -o name | head -n 1 | cut -d/ -f2)

if [ -n "$POD_NAME" ]; then
    # Pull the latest metric from the pod logs (requires the updated hpa-app image)
    RAW_METRIC=$(kubectl logs -n "$NAMESPACE" "$POD_NAME" --tail=10 2>/dev/null | grep "simulated_user_load:" | tail -n 1 | awk '{print $2}' || echo "N/A")
    echo "  Pod: ${POD_NAME} | simulated_user_load: ${RAW_METRIC}"
    if [ "$RAW_METRIC" == "N/A" ]; then
        echo "  (Note: If this is blank, the new image with logging may still be deploying via ArgoCD)."
    fi
else
    echo "  ⚠️ No running pods found to query metrics."
fi
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