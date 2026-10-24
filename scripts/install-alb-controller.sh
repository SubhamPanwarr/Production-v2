#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="$ROOT_DIR/terraform/environments/prod/infra"
ADDONS_DIR="$ROOT_DIR/terraform/environments/prod/addons"

export ALB_CONTROLLER_ROLE_ARN
ALB_CONTROLLER_ROLE_ARN="$(terraform -chdir="$ADDONS_DIR" output -raw alb_controller_role_arn)"

CLUSTER_NAME="$(terraform -chdir="$INFRA_DIR" output -raw eks_cluster_name)"
VPC_ID="$(terraform -chdir="$INFRA_DIR" output -raw vpc_a_id)"
AWS_REGION="${AWS_REGION:-us-east-1}"

envsubst < "$ROOT_DIR/kubernetes/addons/aws-load-balancer-controller-serviceaccount.yaml" | kubectl apply -f -

helm repo add eks https://aws.github.io/eks-charts --force-update
helm repo update eks

# Set AWS_LBC_CHART_VERSION explicitly for reproducible installs.
: "${AWS_LBC_CHART_VERSION:?Set AWS_LBC_CHART_VERSION first. Run: helm search repo eks/aws-load-balancer-controller --versions | head}"

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --version "$AWS_LBC_CHART_VERSION" \
  --set clusterName="$CLUSTER_NAME" \
  --set region="$AWS_REGION" \
  --set vpcId="$VPC_ID" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=180s
