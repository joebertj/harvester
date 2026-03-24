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

# 1. Real-time Metrics (Sum of all pods)
echo "--- REAL-TIME METRICS PER POD ---"
TOTAL_SUM=0
RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=fastapi-metrics --field-selector=status.phase=Running --no-headers | awk '{print $1}')

if [ -z "$RUNNING_PODS" ]; then
    echo "  ⚠️ No running pods found to query metrics."
else
    for POD in $RUNNING_PODS; do
        VAL=$(kubectl logs -n "$NAMESPACE" "$POD" --tail=10 2>/dev/null | grep "simulated_user_load:" | tail -n 1 | awk '{print $2}' || echo 0)
        # Ensure VAL is a number
        [[ $VAL =~ ^[0-9]+$ ]] || VAL=0
        
        printf "  Pod: %-40s | Value: %s\n" "$POD" "$VAL"
        TOTAL_SUM=$((TOTAL_SUM + VAL))
    done

    echo ""
    echo "  >> TOTAL SUM: $TOTAL_SUM"
    # Basic math check for expected replicas (Every 10,000 is 1 replica)
    EXPECTED=$((TOTAL_SUM / 10000))
    if [ $EXPECTED -lt 1 ]; then EXPECTED=1; fi
    echo "  >> ESTIMATED REPLICAS (Sum / 10,000): $EXPECTED"
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