#!/bin/bash
# utils/kube-config.sh
# Fetches the k3s kubeconfig from the control node and sets it up locally.
#
# Usage:
#   ./utils/kube-config.sh              # fetches and writes ~/.kube/harvester-k3s.yaml
#   source ./utils/kube-config.sh       # also exports KUBECONFIG in your current shell
#
# Prerequisites:
#   - SSH key at ~/.ssh/klti authorized on rancher@192.168.2.123
#   - kubectl installed locally

set -e

CONTROL_NODE="192.168.2.123"
SSH_KEY="~/.ssh/klti"
KUBECONFIG_PATH="$HOME/.kube/harvester-k3s.yaml"

echo "==> Fetching kubeconfig from $CONTROL_NODE..."
ssh -i ${SSH_KEY} rancher@${CONTROL_NODE} "sudo cat /etc/rancher/k3s/k3s.yaml" \
  | sed "s/127.0.0.1/${CONTROL_NODE}/g" \
  > "${KUBECONFIG_PATH}"

chmod 600 "${KUBECONFIG_PATH}"

export KUBECONFIG="${KUBECONFIG_PATH}"
echo "✅ KUBECONFIG set to ${KUBECONFIG_PATH}"
echo ""
echo "Verifying cluster access..."
kubectl get nodes
