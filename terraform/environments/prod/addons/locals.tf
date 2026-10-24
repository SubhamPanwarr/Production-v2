locals {
  cluster_name      = data.terraform_remote_state.infra.outputs.eks_cluster_name
  oidc_provider_arn = data.terraform_remote_state.infra.outputs.eks_oidc_provider_arn
  oidc_provider_url = data.terraform_remote_state.infra.outputs.eks_oidc_provider_url
  vpc_id            = data.terraform_remote_state.infra.outputs.vpc_a_id
  rds_secret_arn    = data.terraform_remote_state.infra.outputs.rds_secret_arn

  common_tags = {
    Environment = var.environment
    Application = "Production-Platform"
  }

  eks_oidc_provider = replace(local.oidc_provider_url, "https://", "")
}
