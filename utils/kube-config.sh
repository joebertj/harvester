#!/bin/bash
# utils/kube-config.sh
# Persistently switches your default ~/.kube/config to Harvester or DigitalOcean.

set -e

ENV=${1:-"harvester"}
KUBECONFIG_DIR="$HOME/.kube"
HARVESTER_IP="192.168.2.123"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Ensure directory exists
mkdir -p "${KUBECONFIG_DIR}"

if [ ! -f "${KUBECONFIG_DIR}/config.backup" ] && [ -f "${KUBECONFIG_DIR}/config" ]; then
    echo "==> Creating backup of ~/.kube/config..."
    cp "${KUBECONFIG_DIR}/config" "${KUBECONFIG_DIR}/config.backup"
fi

# 2. Perform the switch
if [ "$ENV" == "do" ]; then
    DO_KUBECONFIG_SRC="${REPO_ROOT}/ansible/do-k3s.yaml"
    if [ ! -f "$DO_KUBECONFIG_SRC" ]; then
        echo "❌ Error: DigitalOcean kubeconfig not found at $DO_KUBECONFIG_SRC"
        exit 1
    fi
    cp "$DO_KUBECONFIG_SRC" "${KUBECONFIG_DIR}/config"
    echo "==> Switched DEFAULT to DigitalOcean..."
else
    echo "==> Fetching Harvester kubeconfig from ${HARVESTER_IP}..."
    # Check for SSH key
    SSH_KEY="$HOME/.ssh/klti"
    if [ ! -f "$SSH_KEY" ]; then
        echo "⚠️  SSH Key $SSH_KEY not found. Attempting default SSH..."
        ssh rancher@${HARVESTER_IP} "sudo cat /etc/rancher/k3s/k3s.yaml" \
          | sed "s/127.0.0.1/${HARVESTER_IP}/g" \
          > "${KUBECONFIG_DIR}/harvester-k3s.yaml"
    else
        ssh -i "$SSH_KEY" rancher@${HARVESTER_IP} "sudo cat /etc/rancher/k3s/k3s.yaml" \
          | sed "s/127.0.0.1/${HARVESTER_IP}/g" \
          > "${KUBECONFIG_DIR}/harvester-k3s.yaml"
    fi
    cp "${KUBECONFIG_DIR}/harvester-k3s.yaml" "${KUBECONFIG_DIR}/config"
    echo "==> Switched DEFAULT to Harvester..."
fi

chmod 600 "${KUBECONFIG_DIR}/config"

# 3. Detect Shell Overrides
if [ -n "$KUBECONFIG" ] && [ "$KUBECONFIG" != "${KUBECONFIG_DIR}/config" ]; then
    echo ""
    echo "⚠️  WARNING: Your current shell has a KUBECONFIG variable set to:"
    echo "   $KUBECONFIG"
    echo "   This OVERRIDES the switch I just made."
    echo ""
    echo "👉 To fix this, run:  unset KUBECONFIG"
    echo "   (Or source this script:  source ./utils/kube-config.sh $ENV)"
    echo ""
fi

echo "✅ Default cluster is now: $ENV"
echo ""
echo "Verifying cluster access..."
kubectl get nodes
