#!/usr/bin/env bash
set -e

REGISTRY="registry.home.kenchlightyear.com"
IMAGE_NAME="library/scaling-fastapi"
TAG="latest"

echo "Fetching auto-generated Harbor password from Kubernetes..."
HARBOR_PASS=$(kubectl get secret harbor-admin-password -n homelab -o jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' | base64 -d)

echo "Logging into Harbor..."
echo "$HARBOR_PASS" | docker login ${REGISTRY} -u admin --password-stdin

echo "Building Docker image..."
docker build -t ${REGISTRY}/${IMAGE_NAME}:${TAG} .

echo "Pushing Docker image to ${REGISTRY}..."
docker push ${REGISTRY}/${IMAGE_NAME}:${TAG}

echo "Done! Image pushed to ${REGISTRY}/${IMAGE_NAME}:${TAG}"
