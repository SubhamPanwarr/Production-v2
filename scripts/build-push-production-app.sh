#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="$ROOT_DIR/terraform/environments/prod/infra"
AWS_REGION="${AWS_REGION:-us-east-1}"
IMAGE_TAG="${1:?Usage: scripts/build-push-production-app.sh <immutable-image-tag>}"

ECR_REPOSITORY_URL="$(terraform -chdir="$INFRA_DIR" output -raw ecr_repository_url)"
ECR_REGISTRY="${ECR_REPOSITORY_URL%%/*}"

aws ecr get-login-password --region "$AWS_REGION" |
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

docker build -t "$ECR_REPOSITORY_URL:$IMAGE_TAG" "$ROOT_DIR/app"
docker push "$ECR_REPOSITORY_URL:$IMAGE_TAG"

echo "Published $ECR_REPOSITORY_URL:$IMAGE_TAG"
