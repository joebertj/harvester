# harvester

This repo contains the files I used on my homelab using Harvester, k3os and k3s.

---

## Demo: Kubernetes HPA with Custom Metric (Poisson Distribution)

This demo simulates Kubernetes-level **Horizontal Pod Autoscaling (HPA)** using a **custom metric** from a FastAPI app, combined with **Harvester node-level autoscaling** triggered by pod topology spread constraints.

### File: [`fastapi-hpa-simulation.yaml`](./fastapi-hpa-simulation.yaml)

### What it does

| Resource | Description |
|---|---|
| `Namespace` | `harvester-autoscaling-sim` — isolates the demo |
| `ConfigMap` | Holds the FastAPI Python script |
| `Deployment` | Runs the FastAPI app with `topologySpreadConstraints` (max 1 pod skew per node) |
| `Service` | Exposes port 80 → port 8000 for Prometheus scraping |
| `HPA` | Scales replicas 1–10 based on the `simulated_user_load` custom metric (target avg: `10`) |

### How the metric works

The FastAPI app emits a `simulated_user_load` Prometheus gauge whose mean oscillates between **2 and 18** using a sine wave over ~5 minutes:

- When load **> 10** → HPA scales **up**
- When load **< 10** → HPA scales **down**
- `topologySpreadConstraints` (`maxSkew: 1`) distributes pods evenly across nodes, potentially triggering **Harvester worker VM provisioning** when nodes are saturated

### Pre-requisites

- A running Harvester/Rancher cluster with `kubectl` access
- **Prometheus** deployed and scraping pod annotations
- **Prometheus Adapter** configured to expose `simulated_user_load` as a custom metric to the HPA API

### Deploy

```bash
kubectl apply -f fastapi-hpa-simulation.yaml
```

### Observe

Open three terminal windows:

```bash
# 1. Watch HPA calculate desired replicas
kubectl get hpa -n harvester-autoscaling-sim -w

# 2. Watch pod scheduling (look for Pending pods on node saturation)
kubectl get pods -n harvester-autoscaling-sim -w

# 3. Watch Harvester provision new worker nodes
kubectl get nodes -w
```

### Tear Down

```bash
kubectl delete -f fastapi-hpa-simulation.yaml
```

---

> **Note:** To test strict 1-pod-per-node autoscaling (forcing one new Harvester VM per replica), replace `topologySpreadConstraints` with `podAntiAffinity` (to be added separately).
