#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="$ROOT_DIR/terraform/environments/prod/infra"
ADDONS_DIR="$ROOT_DIR/terraform/environments/prod/addons"
K8S_DIR="$ROOT_DIR/kubernetes/prod"

export ECR_REPOSITORY_URL
export RDS_SECRET_ARN
export APP_SECRETS_ROLE_ARN
export IMAGE_TAG="${IMAGE_TAG:-v2}"

ECR_REPOSITORY_URL="$(terraform -chdir="$INFRA_DIR" output -raw ecr_repository_url)"
RDS_SECRET_ARN="$(terraform -chdir="$INFRA_DIR" output -raw rds_secret_arn)"
APP_SECRETS_ROLE_ARN="$(terraform -chdir="$ADDONS_DIR" output -raw app_secrets_role_arn)"

apply_dir() {
  local dir="$1"
  echo "==> Applying $dir"
  for file in "$dir"/*.yaml; do
    [ -e "$file" ] || continue
    envsubst < "$file" | kubectl apply -f -
  done
}

apply_dir "$K8S_DIR/00-namespace"
apply_dir "$K8S_DIR/01-security"
apply_dir "$K8S_DIR/02-storage"
apply_dir "$K8S_DIR/03-application"
apply_dir "$K8S_DIR/04-stateful"
apply_dir "$K8S_DIR/05-operations"

echo
echo "NetworkPolicy was NOT applied automatically."
echo "Verify the application first, then apply:"
echo "  kubectl apply -f kubernetes/prod/06-network-policy/network-policy.yaml"
