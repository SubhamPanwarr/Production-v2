# AWS IAM only. The controller itself is installed after this Terraform
# layer using the vendor-supported Helm chart.
module "alb_controller_iam" {
  source = "../../../modules/alb-controller-iam"

  cluster_name      = local.cluster_name
  oidc_provider_arn = local.oidc_provider_arn
  oidc_provider_url = local.oidc_provider_url

  tags = local.common_tags
}
