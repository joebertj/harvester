#!/usr/bin/env bash
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REGISTRY="registry.home.kenchlightyear.com"
TAG=$(date +%Y%m%d-%H%M%S)

echo "Checking Docker daemon status..."
if ! docker info >/dev/null 2>&1; then
  echo "⚠️  Docker daemon is not running."
  if command -v colima >/dev/null; then
    echo "🚀 Colima detected! Automatically starting the Colima Docker engine..."
    colima start
  else
    echo "❌ Error: Cannot connect to Docker. Please start Docker Desktop or your Docker daemon."
    exit 1
  fi
fi

echo "Fetching auto-generated Harbor password from Kubernetes..."
HARBOR_PASS=$(kubectl get secret harbor-admin-password -n homelab -o jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' | base64 -d)

echo "Logging into Harbor..."
echo "$HARBOR_PASS" | docker login ${REGISTRY} -u admin --password-stdin

echo "Building and pushing multi-platform image with tag: $TAG"
docker buildx build --platform linux/amd64 -t ${REGISTRY}/${IMAGE_NAME}:${TAG} "$SCRIPT_DIR/../hpa-app" --push

echo "Updating manifest files with new tag..."
sed -i '' "s|image: ${REGISTRY}/${IMAGE_NAME}:.*|image: ${REGISTRY}/${IMAGE_NAME}:${TAG}|g" "$SCRIPT_DIR"/hpa-*.yaml

echo "Forcing deployment update in cluster..."
kubectl set image deployment/fastapi-metrics-app fastapi=${REGISTRY}/${IMAGE_NAME}:${TAG} -n harvester-autoscaling-sim

echo "✅ Done! Image ${TAG} pushed and deployment updated."
exit 0
