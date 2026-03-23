#!/usr/bin/env bash
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REGISTRY="registry.home.kenchlightyear.com"
IMAGE_NAME="library/scaling-fastapi"
TAG="latest"

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

echo "Building Docker image..."
docker build -t ${REGISTRY}/${IMAGE_NAME}:${TAG} "$SCRIPT_DIR"

echo "Pushing Docker image to ${REGISTRY}..."
docker push ${REGISTRY}/${IMAGE_NAME}:${TAG}

echo "Done! Image pushed to ${REGISTRY}/${IMAGE_NAME}:${TAG}"
