# Ansible — Homelab Infrastructure & GitOps Bootstrap

This directory contains the foundational Ansible playbooks required to bootstrap a vanilla k3s cluster into a fully-managed **GitOps + Vault** environment.

## Prerequisites

On your local machine (Mac):
```bash
pip3 install ansible
```

## Run the Full Bootstrap (01-06)

```bash
cd ansible/
ansible-playbook -i inventory.yml site.yml
```

## Individual Steps & GitOps Handoff

Infrastructure is managed in a sequential 6-step process:

```bash
# 01. Prepare binaries & tools
ansible-playbook -i inventory.yml playbooks/01-prereqs.yml

# 02. Sync KUBECONFIG from the Harvester control node
ansible-playbook -i inventory.yml playbooks/02-kubeconfig.yml

# 03. Deploy & Initialize HashiCorp Vault
ansible-playbook -i inventory.yml playbooks/03-vault.yml

# 04. Install External Secrets Operator (ESO)
ansible-playbook -i inventory.yml playbooks/04-external-secrets.yml

# 05. Bootstrap Secrets & ESO Policies (Security Day 0)
ansible-playbook -i inventory.yml playbooks/05-secrets-bootstrap.yml

# 06. Install Argo CD & Rollout all GitOps Applications
ansible-playbook -i inventory.yml playbooks/06-argocd-bootstrap.yml
```

### 🏁 The GitOps Handover
After **Step 06**, Ansible's job is done. Argo CD takes over the lifecycle of:
- **Monitoring**: Prometheus Stack, Grafana
- **Ingress**: Traefik, Cert-Manager, Homer
- **Registry**: Harbor Enterprise
- **Automation**: Argo Workflows, Argo Events

## File Structure

```
ansible/     
├── site.yml                   # Master orchestration (Step 01-06)
├── inventory.yml              # Cluster node definitions
├── group_vars/all.yml         # Shared variables (IPs, versions)
└── playbooks/
    ├── 01-prereqs.yml         # Helm/Kubectl/Vault binary checks
    ├── 02-kubeconfig.yml      # Remote KUBECONFIG fetching
    ├── 03-vault.yml           # Vault installation (Helm)
    ├── 04-external-secrets.yml# ESO installation (Helm)
    ├── 05-secrets-bootstrap.yml# Vault path/policy provisioning
    └── 06-argocd-bootstrap.yml# Argo CD + App-of-Apps Rollout
```

## Self-Healing & Chaos Demo
To verify the GitOps setup, use the included chaos utility:
```bash
./utils/chaos-monkey.sh
```
This script intentionally breaks the cluster (e.g., deleting services) to demonstrate Argo CD's automated self-healing capabilities.
