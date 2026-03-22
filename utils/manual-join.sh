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

# Token pulled from Vault at runtime (run this on your Mac, not the worker)
# TOKEN=$(vault kv get -field=token homelab/k3os)
# ssh rancher@<worker-ip> "sudo k3s agent --token $TOKEN --server $CONTROL_NODE"

# Fallback: if running directly on the worker with the token provided
TOKEN="${K3S_TOKEN:-__K3OS_TOKEN__}"

if [[ "$TOKEN" == "__K3OS_TOKEN__" ]]; then
  echo "Error: set K3S_TOKEN env var or run via Vault."
  echo "  export K3S_TOKEN=\$(vault kv get -field=token homelab/k3os)"
  echo "  sudo -E bash utils/manual-join.sh"
  exit 1
fi

echo "==> Joining worker to $CONTROL_NODE ..."
sudo k3s agent --token "${TOKEN}" --server "${CONTROL_NODE}"
