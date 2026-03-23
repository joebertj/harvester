#!/usr/bin/env bash
set -e

# Get the absolute path to the repository root so the script can be run from anywhere
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)

echo "Applying Homer ConfigMap..."
kubectl apply -f "$REPO_ROOT/ingress/homer/homer-configmap.yaml"

echo "Fetching the latest index.html directly from the Homer pod..."
HOMER_POD=$(kubectl get pods -n homelab -l app=homer -o jsonpath='{.items[0].metadata.name}')

if [ -z "$HOMER_POD" ]; then
  echo "❌ Error: Could not find a running Homer pod to extract from."
  exit 1
fi

kubectl exec -n homelab $HOMER_POD -- cat /www/index.html > "$REPO_ROOT/ingress/homer/index.html"

echo "Injecting OpenGraph preview tags..."
# MacOS root-safe sed replacement
sed -i.bak 's@</head>@<meta property="og:title" content="Homelab | kenchlightyear.com"><meta property="og:description" content="Next-Gen Self-Hosting Infrastructure."><meta property="og:image" content="https://home.kenchlightyear.com/assets/preview.png"><meta name="twitter:card" content="summary_large_image"></head>@' "$REPO_ROOT/ingress/homer/index.html"
rm -f "$REPO_ROOT/ingress/homer/index.html.bak"

echo "Applying Homer Assets ConfigMap (for Social Previews)..."
kubectl create configmap homer-assets \
  --from-file=index.html="$REPO_ROOT/ingress/homer/index.html" \
  --from-file=preview.png="$REPO_ROOT/ingress/homer/preview.png" \
  -n homelab --dry-run=client -o yaml | kubectl apply -f -

echo "Applying Homer Deployment..."
kubectl apply -f "$REPO_ROOT/ingress/homer/homer-deployment.yaml"

echo "Restarting Homer deployment to pick up the new configuration..."
kubectl rollout restart deployment homer -n homelab

echo "Waiting for Homer to be ready..."
kubectl rollout status deployment homer -n homelab

echo "✅ Homer dashboard successfully reloaded!"
