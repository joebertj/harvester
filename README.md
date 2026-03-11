# harvester

This repo contains the files I used on my homelab using Harvester, k3os and k3s.

---

## Demo: Kubernetes HPA with Custom Metric (Poisson Distribution)

This demo simulates Kubernetes-level **Horizontal Pod Autoscaling (HPA)** using a **custom metric** from a FastAPI app, combined with **Harvester node-level autoscaling**.

### Files

| File | Description |
|---|---|
| [`hpa-common.yaml`](./hpa-common.yaml) | **Shared base** — Namespace, ConfigMap, Service, HPA |
| [`hpa-topology-spread.yaml`](./hpa-topology-spread.yaml) | **Variant A** — Deployment with `topologySpreadConstraints` (even pod distribution, `maxSkew: 1`) |
| [`hpa-pod-anti-affinity.yaml`](./hpa-pod-anti-affinity.yaml) | **Variant B** — Deployment with strict `podAntiAffinity` (1 pod per node, forces new Harvester VM per replica) |
| [`hpa-taints-tolerations.yaml`](./hpa-taints-tolerations.yaml) | **Variant C** — Deployment restricted to dedicated/tainted nodes using `tolerations` + `nodeAffinity` |

### How the metric works

The FastAPI app emits a `simulated_user_load` Prometheus gauge whose mean oscillates between **2 and 18** using a sine wave over ~5 minutes:

- When load **> 10** → HPA scales **up** (target avg: `10`)
- When load **< 10** → HPA scales **down**
- Replicas range: `1–10`

### Variant A — `topologySpreadConstraints`

Pods are spread evenly across available nodes (max 1 pod skew per node). Multiple pods can share a node.  
Harvester provisions new VMs only when existing nodes are **resource-saturated**.

```bash
kubectl apply -f hpa-common.yaml
kubectl apply -f hpa-topology-spread.yaml
```

### Variant B — `podAntiAffinity`

Each pod **must** run on a unique node. When HPA scales up beyond available nodes, excess pods go `Pending`, directly triggering Harvester to provision **one new VM per pending pod**.

```bash
kubectl apply -f hpa-common.yaml
kubectl apply -f hpa-pod-anti-affinity.yaml
```

### Variant C — Taints & Tolerations (Dedicated Nodes)

Taint specific Harvester worker VMs so **only** the FastAPI pods can schedule there. All other workloads are blocked.

```bash
# 1. Taint and label your target worker node(s) first:
kubectl taint nodes <worker-node> workload=intensive:NoSchedule
kubectl label nodes <worker-node> workload=intensive

# 2. Apply the common resources and variant:
kubectl apply -f hpa-common.yaml
kubectl apply -f hpa-taints-tolerations.yaml
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
kubectl delete -f hpa-topology-spread.yaml        # or other variant
kubectl delete -f hpa-common.yaml

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
