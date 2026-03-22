# Homelab Ingress Stack

Traefik-based ingress on k3s routing `*.home.kenchlightyear.com` to LAN services via a single port-forward (443 → `192.168.2.123`). Secrets managed by Vault. TLS via Let's Encrypt wildcard cert + Cloudflare DNS-01.

## Architecture

```
Internet → Cloudflare DNS → Your Public IP:443
                                    ↓ (port-forward 443 → 192.168.2.123)
                              k3s Traefik (192.168.2.123)
                    ┌──────────────────────────────────────┐
                    │ home.kenchlightyear.com              │ → Homer Dashboard (pod)
                    │ harvester.home.kenchlightyear.com    │ → 192.168.2.118:443
                    │ kvm.home.kenchlightyear.com          │ → 192.168.2.129:443
                    │ vault.home.kenchlightyear.com        │ → Vault UI (pod)
                    └──────────────────────────────────────┘
SSH (optional, needs separate port-forward TCP 2222 → 192.168.2.123):
  ssh.home.kenchlightyear.com:2222 → 192.168.2.122:22

Secrets flow:
  Vault (k3s pod) → stores CF token, k3os creds, SSH key, WG secrets
  External Secrets Operator → syncs Vault → K8s Secrets
  cert-manager → reads K8s Secret → DNS-01 wildcard cert
```

## Prerequisites

- k3s running on `192.168.2.123` — kubeconfig set up via `../utils/kube-config.sh`
- Router: port-forward **TCP 443 → `192.168.2.123`**
- Cloudflare DNS A records (proxied 🟠):
  - `home.kenchlightyear.com` → your home public IP
  - `*.home.kenchlightyear.com` → your home public IP
- Helm installed locally or on `192.168.2.123`

## Deployment Steps

### 1. Apply Namespace

```bash
kubectl apply -f namespace.yaml
```

### 2. Configure Traefik

```bash
kubectl apply -f traefik/traefik-config.yaml
kubectl rollout status deployment/traefik -n kube-system
```

### 3. Install cert-manager

```bash
chmod +x cert-manager/install-cert-manager.sh
./cert-manager/install-cert-manager.sh
```

### 4. Deploy Vault

```bash
cd vault/
chmod +x install-vault.sh init-vault.sh
./install-vault.sh
./init-vault.sh
```

`init-vault.sh` will interactively ask for:
- Cloudflare API token
- k3os node password
- SSH public key (`cat ~/.ssh/klti.pub`)

> ⚠️ It creates `vault-init.json` with the unseal key and root token. **Back this up to a password manager immediately, then delete it.**

```bash
# Back up vault-init.json, then:
rm vault-init.json
cd ..
```

### 5. Install External Secrets Operator

```bash
cd external-secrets/
chmod +x install-eso.sh
./install-eso.sh
kubectl apply -f vault-secretstore.yaml
kubectl apply -f cloudflare-externalsecret.yaml

# Confirm the Cloudflare secret was created
kubectl get secret cloudflare-api-token -n cert-manager
```

### 6. Apply TLS Resources

```bash
# Set your email first
nano cert-manager/clusterissuer.yaml

kubectl apply -f cert-manager/clusterissuer.yaml
kubectl apply -f cert-manager/wildcard-certificate.yaml

# Watch certificate issuance (~60-90 seconds)
kubectl get certificate -n homelab -w
```

### 7. Apply Backend Services

```bash
kubectl apply -f services/
```

### 8. Apply IngressRoutes

```bash
kubectl apply -f routes/
```

### 9. Deploy Homer Dashboard

```bash
kubectl apply -f homer/
kubectl rollout status deployment/homer -n homelab
```

## Verify

```bash
# All resources in homelab namespace
kubectl get all -n homelab

# TLS cert status
kubectl describe certificate home-kenchlightyear-wildcard -n homelab

# IngressRoutes
kubectl get ingressroute -n homelab
```

Browse to:
- https://home.kenchlightyear.com → Homer dashboard
- https://harvester.home.kenchlightyear.com → Harvester UI
- https://kvm.home.kenchlightyear.com → Nano KVM UI
- https://vault.home.kenchlightyear.com → Vault UI

## File Structure

```
ingress/
├── .gitignore
├── namespace.yaml
├── traefik/
│   └── traefik-config.yaml              # HelmChartConfig for k3s Traefik
├── cert-manager/
│   ├── install-cert-manager.sh
│   ├── cloudflare-secret.yaml           # gitignored — managed by ESO/Vault
│   ├── clusterissuer.yaml               # ⚠️ Fill in your email
│   └── wildcard-certificate.yaml
├── vault/
│   ├── vault-values.yaml                # Helm values (Raft, single node)
│   ├── install-vault.sh                 # Helm install
│   └── init-vault.sh                    # Init, unseal, store all secrets
├── external-secrets/
│   ├── install-eso.sh
│   ├── vault-secretstore.yaml           # ClusterSecretStore → Vault
│   └── cloudflare-externalsecret.yaml   # Syncs CF token → cert-manager
├── services/
│   ├── harvester-service.yaml           # → 192.168.2.118:443
│   ├── kvm-service.yaml                 # → 192.168.2.129:443
│   └── ssh-service.yaml                 # → 192.168.2.122:22
├── routes/
│   ├── harvester-ingressroute.yaml
│   ├── kvm-ingressroute.yaml
│   ├── homer-ingressroute.yaml
│   ├── vault-ingressroute.yaml
│   └── ssh-ingressroutetcp.yaml
└── homer/
    ├── homer-configmap.yaml             # Edit to add/change dashboard links
    ├── homer-deployment.yaml
    └── homer-service.yaml
```

## Adding More Services

1. Add `Endpoints` + `Service` in `services/`
2. Add an `IngressRoute` in `routes/`
3. Add a card to `homer/homer-configmap.yaml`
4. `kubectl apply` the new files

## TODO: Cluster Upgrade Simulation

- **Simulate incremental k3s cluster upgrades (1.21 → 1.22 → 1.23 → 1.24 → 1.25)**
  - Our current cluster is running k3s `1.21`, which forced us to downgrade several Helm charts (cert-manager to `v1.9.1` and external-secrets to `v0.7.2`).
  - Demonstrate an incremental OS/k3s upgrade path stepping through each minor version to show the upgrade lifecycle safely.
  - After reaching `1.25+`, rerun Ansible or create a separate versioned Ansible playbook to use the latest Helm charts (e.g., `crds.enabled=true` syntax for cert-manager v1.14+, and CEL validation features for external-secrets v0.9+).
