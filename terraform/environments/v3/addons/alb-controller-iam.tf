module "alb_controller_iam" {
  source = "../../../modules/alb-controller-iam"

  cluster_name = data.terraform_remote_state.infra.outputs.eks_cluster_name

  oidc_provider_arn = data.terraform_remote_state.infra.outputs.eks_oidc_provider_arn

  oidc_provider_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = {
    Project     = "Production-v3"
    Environment = "lab"
  }
}

output "alb_controller_role_arn" {
  value = module.alb_controller_iam.iam_role_arn
}
