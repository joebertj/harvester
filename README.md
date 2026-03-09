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

