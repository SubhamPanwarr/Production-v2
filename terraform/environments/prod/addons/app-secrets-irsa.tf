# AWS IAM only. The Kubernetes ServiceAccount itself lives in YAML.
module "eks_secrets_access" {
  source = "../../../modules/eks-secrets-access"

  cluster_name      = local.cluster_name
  oidc_provider_arn = local.oidc_provider_arn
  oidc_provider_url = local.oidc_provider_url

  namespace            = var.app_namespace
  service_account_name = var.app_service_account_name

  secret_arn = local.rds_secret_arn

  tags = local.common_tags
}
