#!/bin/bash
# utils/show-distribution.sh
# Quickly check pod distribution for HPA simulation across nodes.

NAMESPACE=${1:-"harvester-autoscaling-sim"}

echo "---------------------------------------------------------"
echo " POD DISTRIBUTION SUMMARY: ${NAMESPACE}"
echo "---------------------------------------------------------"

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "❌ Error: Namespace '$NAMESPACE' not found."
    exit 1
fi

kubectl get pods -n "$NAMESPACE" -o wide --no-headers | \
  awk '{print $7}' | sort | uniq -c | \
  awk '{printf "  Node: %-15s | Pods: %s\n", $2, $1}'

echo "---------------------------------------------------------"