# Ansible — Homelab Ingress Stack

Repeatable, idempotent setup of the full homelab ingress stack on k3s.

## Prerequisites

On your local machine (Mac):
```bash
pip3 install ansible
```

## Run the Full Setup

```bash
cd ansible/
ansible-playbook -i inventory.yml site.yml
```

You will be prompted interactively for:
- Email (Let's Encrypt)
- Cloudflare API token
- k3os node password
- k3s cluster join token
- SSH public key

## Run Individual Steps

```bash
# 1. Check/install helm + kubectl + vault
ansible-playbook -i inventory.yml playbooks/01-prereqs.yml

# 2. Fetch kubeconfig from control node
ansible-playbook -i inventory.yml playbooks/02-kubeconfig.yml

# 3. Install cert-manager
ansible-playbook -i inventory.yml playbooks/03-cert-manager.yml

# 4. Deploy + initialize Vault (interactive)
ansible-playbook -i inventory.yml playbooks/04-vault.yml

# 5. Install External Secrets Operator
ansible-playbook -i inventory.yml playbooks/05-external-secrets.yml

# 6. Deploy Traefik + TLS + services + Homer
ansible-playbook -i inventory.yml playbooks/06-ingress-stack.yml

# 7. Deploy Harbor Enterprise Registry
ansible-playbook -i inventory.yml playbooks/07-registry.yml

# 8. Deploy Headlamp Dashboard (pinned to v0.35.0 for compatibility)
ansible-playbook -i inventory.yml playbooks/08-headlamp.yml

# 20a. Replace Flannel with Cilium CNI (run LAST — disrupts cluster networking)
ansible-playbook -i inventory.yml playbooks/20a-install-cilium.yml

# 20b. Revert from Cilium back to Flannel
ansible-playbook -i inventory.yml playbooks/20b-revert-flannel.yml

# 09. Deploy Argo Workflows CI/CD Stack
ansible-playbook -i inventory.yml playbooks/09-argo-workflows.yml

# 09a. Deploy Argo Events
ansible-playbook -i inventory.yml playbooks/09a-argo-events.yml

# 15. Deploy HPA Shared Common Resources
ansible-playbook -i inventory.yml playbooks/15-hpa-common.yml

# 15a. HPA Variant A — topologySpreadConstraints
ansible-playbook -i inventory.yml playbooks/15a-hpa-topology-spread.yml

# 15b. HPA Variant B — podAntiAffinity
ansible-playbook -i inventory.yml playbooks/15b-hpa-pod-anti-affinity.yml

# 15c. HPA Variant C — Taints & Tolerations (pass dedicated node name)
ansible-playbook -i inventory.yml playbooks/15c-hpa-taints-tolerations.yml -e dedicated_node=<worker-node>
```

## Run by Tag (skip steps)

```bash
# Run everything except Vault (already initialized)
ansible-playbook -i inventory.yml site.yml --skip-tags vault

# Only deploy the ingress stack
ansible-playbook -i inventory.yml site.yml --tags ingress
```

## Configuration

Edit `group_vars/all.yml` to change IPs, namespaces, or versions. The inventory has the control node IP and SSH key path.

## File Structure

```
ansible/
├── site.yml                       # Master playbook (runs all steps)
├── inventory.yml                  # Hosts (localhost only)
├── group_vars/
│   └── all.yml                    # Shared variables
└── playbooks/
    ├── 01-prereqs.yml             # Check/install helm + kubectl + vault
    ├── 02-kubeconfig.yml          # Fetch kubeconfig from 192.168.2.123
    ├── 03-cert-manager.yml        # Install cert-manager + ClusterIssuer
    ├── 04-vault.yml               # Install + init Vault + store all secrets
    ├── 05-external-secrets.yml    # Install ESO + sync CF token
    ├── 06-ingress-stack.yml       # Traefik + TLS + services + Homer
    ├── 07-registry.yml            # Harbor enterprise registry
    ├── 08-headlamp.yml            # Headlamp Kubernetes dashboard
    ├── 20a-install-cilium.yml         # [LAST] Install Cilium CNI (replace Flannel)
    └── 20b-revert-flannel.yml         # [LAST] Revert to Flannel CNI (remove Cilium)
    ├── 09-tekton.yml                  # Tekton CI/CD Stack
    ├── 20a-install-cilium.yml         # [LAST] Install Cilium CNI (replace Flannel)
    └── 20b-revert-flannel.yml         # [LAST] Revert to Flannel CNI (remove Cilium)
    ├── 15-hpa-common.yml              # HPA Shared Common Resources
    ├── 15a-hpa-topology-spread.yml    # HPA Variant A: topologySpreadConstraints
    ├── 15b-hpa-pod-anti-affinity.yml  # HPA Variant B: podAntiAffinity
    └── 15c-hpa-taints-tolerations.yml # HPA Variant C: Taints & Tolerations
```

## TODO: Cluster Upgrade Simulation

- **Simulate incremental k3s cluster upgrades (1.21 → 1.22 → 1.23 → 1.24 → 1.25)**
  - The current playbooks use older Helm chart versions (cert-manager `v1.9.1`, external-secrets `v0.7.2`) to maintain compatibility with the existing `k3s v1.21` cluster.
  - Demonstrate a stepped OS/k3s upgrade path to show the upgrade lifecycle safely.
  - After reaching `1.25+`, rerun Ansible or create a separate versioned Ansible playbook to use the latest Helm charts (e.g., `crds.enabled=true` syntax for cert-manager v1.14+, and CEL validation features for external-secrets v0.9+).
