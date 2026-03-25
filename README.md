# harvester

This repo contains the declarative GitOps infrastructure for a bare-metal homelab running on Harvester, k3s, and Argo CD.

---

## Architecture Overview

![Homelab Architecture](docs/architecture.png)

### Directory Structure

| Directory | Purpose |
|-----------|---------|
| `argo/argocd/applications/` | Argo CD Application manifests (managed by app-of-apps) |
| `argo/extras/` | Argo Workflows templates, EventSources, Sensors |
| `ingress/routes/` | Traefik IngressRoutes for all services |
| `ingress/services/` | StatefulSets and Deployments (e.g. Omada) |
| `ingress/homer/` | Homer dashboard ConfigMap, Deployment, Service |
| `ingress/external-secrets/` | ExternalSecret manifests (Vault → K8s Secrets) |
| `monitoring/dashboards/` | Grafana dashboard ConfigMaps |
| `monitoring/` | Prometheus stack and adapter Helm values |
| `kyverno/policies/` | Kyverno ClusterPolicies (Audit mode) |
| `scaling/base/` | HPA simulation Deployment, HPA, Service, PodMonitor |
| `cloud-init/` | VM cloud-init scripts |
| `ansible/` | Ansible playbooks for initial provisioning |

---

## Bootstrap — App of Apps

All Argo CD Applications are managed by a single **app-of-apps** root Application. After initial cluster setup, this is the only manual step required:

```bash
kubectl apply -f argo/argocd/applications/app-of-apps.yaml
```

This watches `argo/argocd/applications/` and automatically deploys every Application manifest found there. Any new YAML pushed to that directory is auto-synced; any deleted YAML is pruned.

### Managed Applications

| Application | Chart / Source | Namespace |
|-------------|---------------|-----------|
| Harbor | `helm.goharbor.io/harbor` | `homelab` |
| Headlamp | `kubernetes-sigs.github.io/headlamp` | `homelab` |
| Kyverno | `kyverno.github.io/kyverno` | `kyverno` |
| Kyverno Policies | `harvester.git → kyverno/policies/` | `kyverno` |
| Policy Reporter | `kyverno.github.io/policy-reporter` | `kyverno` |
| HPA Simulation | `harvester.git → scaling/base/` | `harvester-autoscaling-sim` |
| Grafana Dashboards | `harvester.git → monitoring/dashboards/` | `monitoring` |
| kube-prometheus-stack | `prometheus-community` | `monitoring` |
| cert-manager | `jetstack` | `cert-manager` |
| Argo Workflows | `argoproj.github.io/argo-helm` | `argo` |
| Argo Events | `argoproj.github.io/argo-helm` | `argo` |
| Ingress Stack | `harvester.git → ingress/` | various |

---

## Services & Ingress

All services are exposed via Traefik IngressRoutes with TLS (`home-kenchlightyear-tls`).

| Service | URL | Source |
|---------|-----|--------|
| Homer (dashboard) | `home.kenchlightyear.com` | `ingress/routes/homer-ingressroute.yaml` |
| Grafana | `grafana.home.kenchlightyear.com` | `ingress/routes/grafana-ingressroute.yaml` |
| Harbor | `registry.home.kenchlightyear.com` | `ingress/routes/harbor-ingressroute.yaml` |
| Argo CD | `argocd.home.kenchlightyear.com` | `ingress/routes/argo-ingressroute.yaml` |
| Argo Workflows | `argo.home.kenchlightyear.com` | `ingress/routes/argo-events-ingressroute.yaml` |
| Headlamp | `headlamp.home.kenchlightyear.com` | `ingress/routes/headlamp-ingressroute.yaml` |
| Vault | `vault.home.kenchlightyear.com` | `ingress/routes/vault-ingressroute.yaml` |
| Omada | `omada.home.kenchlightyear.com` | `ingress/routes/omada-ingressroute.yaml` |
| Kyverno (Policy Reporter) | `kyverno.home.kenchlightyear.com` | `ingress/routes/kyverno-ingressroute.yaml` |

---

## Secrets Management

Secrets are managed via **HashiCorp Vault** + **External Secrets Operator**. ExternalSecrets in `ingress/external-secrets/` sync Vault paths into Kubernetes Secrets automatically.

| Secret | Vault Path | Namespace |
|--------|-----------|-----------|
| Grafana admin credentials | `monitoring/grafana` | `monitoring` |
| Harbor admin password | Via Helm | `homelab` |
| Harbor pull secret | Via ExternalSecret | `homelab` |
| Headlamp token | `headlamp` | `homelab` |
| Cloudflare API token | Via ExternalSecret | `cert-manager` |

---

## Monitoring

The monitoring stack uses **kube-prometheus-stack** (Prometheus + Grafana) with **prometheus-adapter** for custom HPA metrics.

### Grafana Dashboards

Dashboards are deployed as ConfigMaps with label `grafana_dashboard: "1"` in `monitoring/dashboards/`:

| Dashboard | File |
|-----------|------|
| Harvester HPA Simulation | `hpa-dashboard.yaml` |
| Harvester Autoscaling Sim | `autoscaling-sim-dashboard.yaml` |

---

## Kyverno — Policy Engine

Kyverno is deployed in **Audit mode** — all policies log violations without blocking any traffic. Policies live in `kyverno/policies/` and are synced by Argo CD.

### Active Policies

| Policy | Severity | What it audits |
|--------|----------|---------------|
| `require-resource-limits` | Medium | Pods without CPU/memory limits |
| `disallow-latest-tag` | Medium | Containers using `:latest` tag |
| `require-labels` | Low | Deployments/StatefulSets missing `app` label |
| `disallow-privileged` | High | Privileged containers |
| `require-readonly-rootfs` | Low | Containers without `readOnlyRootFilesystem` |

View violations: `kubectl get policyreport -A` or browse the Policy Reporter UI at `kyverno.home.kenchlightyear.com`.

To switch a policy to enforcing mode, change `validationFailureAction: Audit` to `Enforce` in the policy YAML.

## Step 0: Deploy Rancher on a Harvester VM

Rancher is required before running the Cluster Autoscaler or provisioning RKE2 downstream clusters on Harvester.

### File: [`cloud-init/rancher.yaml`](./cloud-init/rancher.yaml)

Installs k3s + cert-manager + Rancher via Helm on a single Ubuntu VM running inside Harvester.

### VM Requirements

| Resource | Minimum |
|---|---|
| CPU | 4 vCPU |
| RAM | 8 GB |
| Disk | 50 GB |
| OS | Ubuntu 22.04 LTS |

### Setup

**Step 1 — Edit the cloud-init file** — open `cloud-init/rancher.yaml` and replace the placeholders:

| Placeholder | Value |
|---|---|
| `<YOUR_SSH_PUBLIC_KEY>` | Your SSH public key (`cat ~/.ssh/id_rsa.pub`) |
| `<RANCHER_HOSTNAME>` | Stable IP or FQDN for Rancher (e.g. `192.168.2.200`) |
| `<BOOTSTRAP_PASSWORD>` | Your desired Rancher admin password |

**Step 2 — Create the VM in Harvester UI:**
1. Go to **Virtual Machines → Create**
2. OS: Ubuntu 22.04 LTS, CPU: 4, RAM: 8 GB, Disk: 50 GB
3. Under **Cloud Config → User Data**, paste `cloud-init/rancher.yaml`
4. Start the VM and wait ~5 minutes

**Step 3 — Verify Rancher is ready:**
```bash
ssh ubuntu@<RANCHER_HOSTNAME>
sudo tail -f /var/log/install-rancher.log
# Look for: "Rancher is ready!"
```

**Step 4 — Open Rancher UI:** `https://<RANCHER_HOSTNAME>` with your bootstrap password.

---

## Step 1: Connect Rancher to Harvester (Harvester Plugin)

1. Log into Rancher UI
2. Go to **☰ → Virtualization Management**
3. Click **Import Existing → Harvester**
4. In your **Harvester** dashboard, go to **Support → Download KubeConfig**
5. Paste the downloaded kubeconfig into Rancher and click **Import**

Once connected, Rancher can use Harvester VMs to provision RKE2 downstream clusters — required for the Cluster Autoscaler.

---

## Step 2: Demo — Kubernetes HPA with Custom Metric (Poisson Distribution)


This demo simulates Kubernetes-level **Horizontal Pod Autoscaling (HPA)** using a **custom metric** from a FastAPI app, combined with **Harvester node-level autoscaling**.

### Files

| File | Description |
|---|---|
| [`scaling/hpa-common.yaml`](./scaling/hpa-common.yaml) | **Shared base** — Namespace, Service, HPA |
| [`scaling/hpa-topology-spread.yaml`](./scaling/hpa-topology-spread.yaml) | **Variant A** — Deployment with `topologySpreadConstraints` (even pod distribution, `maxSkew: 1`) |
| [`scaling/hpa-pod-anti-affinity.yaml`](./scaling/hpa-pod-anti-affinity.yaml) | **Variant B** — Deployment with strict `podAntiAffinity` (1 pod per node, forces new Harvester VM per replica) |
| [`scaling/hpa-taints-tolerations.yaml`](./scaling/hpa-taints-tolerations.yaml) | **Variant C** — Deployment restricted to dedicated/tainted nodes using `tolerations` + `nodeAffinity` |

### How the metric works

The FastAPI app emits a `simulated_user_load` Prometheus gauge whose mean oscillates between **2 and 18** using a sine wave over ~5 minutes:

- When load **> 10** → HPA scales **up** (target avg: `10`)
- When load **< 10** → HPA scales **down**
- Replicas range: `1–10`

### Variant A — `topologySpreadConstraints`

Pods are spread evenly across available nodes (max 1 pod skew per node). Multiple pods can share a node.  
Harvester provisions new VMs only when existing nodes are **resource-saturated**.

```bash
kubectl apply -f scaling/hpa-common.yaml
kubectl apply -f scaling/hpa-topology-spread.yaml
```

### Variant B — `podAntiAffinity`

Each pod **must** run on a unique node. When HPA scales up beyond available nodes, excess pods go `Pending`, directly triggering Harvester to provision **one new VM per pending pod**.

```bash
kubectl apply -f scaling/hpa-common.yaml
kubectl apply -f scaling/hpa-pod-anti-affinity.yaml
```

### Variant C — Taints & Tolerations (Dedicated Nodes)

Taint specific Harvester worker VMs so **only** the FastAPI pods can schedule there. All other workloads are blocked.

```bash
# 1. Taint and label your target worker node(s) first:
kubectl taint nodes <worker-node> workload=intensive:NoSchedule
kubectl label nodes <worker-node> workload=intensive

# 2. Apply the common resources and variant:
kubectl apply -f scaling/hpa-common.yaml
kubectl apply -f scaling/hpa-taints-tolerations.yaml
```

> Pods without the matching toleration will go `Pending` on the tainted node, while the FastAPI pods land exclusively on it.

### Observe

```bash
# Watch HPA calculate desired replicas
kubectl get hpa -n harvester-autoscaling-sim -w

# Watch pod scheduling (Pending pods = Harvester provisioning trigger)
kubectl get pods -n harvester-autoscaling-sim -w

# Watch Harvester provision new worker nodes
kubectl get nodes -w
```

### Tear Down

```bash
# Remove the active deployment variant first, then the common resources
kubectl delete -f scaling/hpa-topology-spread.yaml        # or other variant
kubectl delete -f scaling/hpa-common.yaml

# For Variant C only — clean up the taint and label from the node:
kubectl taint nodes <worker-node> workload=intensive:NoSchedule-
kubectl label nodes <worker-node> workload-
```

---

## Cluster Autoscaler — Rancher/Harvester Node Scaling

The Cluster Autoscaler closes the loop by automatically provisioning and deprovisioning **Harvester worker VMs** when pods cannot be scheduled.

### Files

| File | Description |
|---|---|
| [`cluster-autoscaler.yaml`](./cluster-autoscaler.yaml) | Cluster Autoscaler RBAC, Rancher cloud config Secret, and Deployment |
| [`machinepool-patch.yaml`](./machinepool-patch.yaml) | Rancher `Cluster` patch to annotate the worker MachinePool with autoscaler min/max bounds |

### How it works

```
Pending pods detected
  → Cluster Autoscaler reads MachinePool annotations (min/max)
    → Calls Rancher API to increment MachinePool quantity
      → Rancher provisions a new Harvester VM
        → VM joins cluster as a new node
          → Pending pods get scheduled
```

### Setup

**Step 1 — Annotate the MachinePool** *(on the Rancher management cluster)*

Fill in your cluster name in `machinepool-patch.yaml`, then:

```bash
kubectl patch cluster <CLUSTER_NAME> \
  -n fleet-default \
  --type=merge \
  --patch-file=machinepool-patch.yaml
```

**Step 2 — Deploy the Cluster Autoscaler** *(on the downstream RKE2 cluster)*

Edit the `Secret` in `cluster-autoscaler.yaml` to fill in:
- `RANCHER_URL` — your Rancher server URL (e.g. `https://rancher.homelab.local`)
- `RANCHER_API_TOKEN` — create in Rancher UI → Account & API Keys
- `DOWNSTREAM_CLUSTER_NAME` — the name of your RKE2 cluster in Rancher

Then apply:
```bash
kubectl apply -f cluster-autoscaler.yaml
```

**Step 3 — Verify**

```bash
kubectl logs -n kube-system deploy/cluster-autoscaler -f
```

You should see it scanning for unschedulable pods and calling the Rancher API when our HPA demo pods go Pending.

### Tear Down

```bash
kubectl delete -f cluster-autoscaler.yaml
```
