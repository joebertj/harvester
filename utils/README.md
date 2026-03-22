# utils/

Helper scripts for managing the homelab k3s cluster.

---

## `kube-config.sh` — Fetch kubeconfig from control node

Pulls the kubeconfig from the k3s control node (`192.168.2.123`) and writes it to `~/.kube/harvester-k3s.yaml`.

```bash
# Fetch and write the kubeconfig file
./utils/kube-config.sh

# Fetch AND export KUBECONFIG in your current shell (use source)
source ./utils/kube-config.sh

# Make it permanent — add to ~/.zshrc:
export KUBECONFIG=~/.kube/harvester-k3s.yaml
```

**Prerequisites:** SSH key at `~/.ssh/klti` authorized on `rancher@192.168.2.123`

---

## `generate-cloud-init.sh` — Render cloud-init templates with secrets from Vault

Replaces `__PLACEHOLDERS__` in cloud-init templates with real values pulled from Vault.
Output files contain secrets — **never commit them to git** (they are gitignored via `*-real.yaml`).

```bash
# Generate a worker cloud-init file
./utils/generate-cloud-init.sh cloud-init/work-1.yaml > work-1-real.yaml

# Generate the control node cloud-init file
./utils/generate-cloud-init.sh cloud-init/control.yaml > control-real.yaml

# Use the rendered file in Harvester VM creation, then delete it
rm work-1-real.yaml
```

**Prerequisites:**
- `vault` CLI installed and authenticated (`vault login`)
- `VAULT_ADDR` set to `http://192.168.2.123:8200` (or use a port-forward)
- Secrets populated in Vault via `ingress/vault/init-vault.sh`

**Secrets pulled from Vault:**
| Vault path | Field | Used for |
|---|---|---|
| `homelab/k3os` | `password` | Node login password |
| `homelab/k3os` | `token` | k3s cluster join token |
| `homelab/ssh` | `authorized_key` | SSH public key |

---

## `manual-join.sh` — Re-join a worker node to the cluster

Use this when a worker loses its join config after a hard shutdown (cloud-init `k3os:` section doesn't persist without a clean reboot).

```bash
# On your Mac — fetch token from Vault and inject it into the worker
TOKEN=$(vault kv get -field=token homelab/k3os)
ssh -i ~/.ssh/klti rancher@<worker-ip> "sudo k3s agent --token $TOKEN --server https://192.168.2.123:6443"

# OR copy the script to the worker and run with token from env
export K3S_TOKEN=$(vault kv get -field=token homelab/k3os)
scp utils/manual-join.sh rancher@<worker-ip>:~/manual-join.sh
ssh -i ~/.ssh/klti rancher@<worker-ip> "sudo -E bash ~/manual-join.sh"
```

**Note:** This runs `k3s agent` in the foreground. For a permanent fix, write the join config to `/var/lib/rancher/k3os/config.yaml` and reboot the node instead.
