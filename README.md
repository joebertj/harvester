# harvester

This repo contains the files I used on my homelab using Harvester, k3os and k3s.

---

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
