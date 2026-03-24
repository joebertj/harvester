#!/bin/bash
# utils/manual-join.sh
# Manually re-joins this k3os worker node to the k3s control plane.
# Use this when the node loses its join config (e.g. after a hard shutdown).
#
# Usage (run ON the worker node):
#   1. Copy this script to the worker:  scp utils/manual-join.sh rancher@<worker-ip>:~
#   2. SSH into the worker:             ssh rancher@<worker-ip>
#   3. Run:                             sudo bash ~/manual-join.sh
#
# OR: fetch the token inline from Vault on your Mac, then pass it to the worker.

CONTROL_NODE="https://192.168.2.123:6443"
WORKER_IP=$1

# If VAULT_TOKEN is set, try to fetch the token automatically from Vault
if [ -n "$VAULT_TOKEN" ]; then
    echo "🔐 VAULT_TOKEN detected. Fetching k3s token from Vault..."
    TOKEN=$(vault kv get -field=token homelab/k3os 2>/dev/null)
fi

# Fallback to env var if Vault fetch failed or wasn't attempted
TOKEN="${TOKEN:-$K3S_TOKEN}"

if [ -z "$TOKEN" ] || [ "$TOKEN" == "__K3OS_TOKEN__" ]; then
    echo "❌ Error: k3s token not found."
    echo "   Ensure VAULT_ADDR/VAULT_TOKEN are exported OR K3S_TOKEN is set."
    exit 1
fi

if [ -z "$WORKER_IP" ]; then
    echo "ℹ️  No worker IP provided. Run this ON the worker node:"
    echo "   sudo k3s agent --token $TOKEN --server $CONTROL_NODE"
    exit 0
fi

echo "🚀 Joining worker $WORKER_IP to $CONTROL_NODE via SSH..."
ssh -o StrictHostKeyChecking=no rancher@"$WORKER_IP" "sudo k3s agent --token $TOKEN --server $CONTROL_NODE"
