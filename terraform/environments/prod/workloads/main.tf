data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket       = var.state_bucket
    key          = var.infra_state_key
    region       = var.aws_region
    use_lockfile = true
  }
}

data "terraform_remote_state" "addons" {
  backend = "s3"
  config = {
    bucket       = var.state_bucket
    key          = var.addons_state_key
    region       = var.aws_region
    use_lockfile = true
  }
}

locals {
  cluster_name = data.terraform_remote_state.infra.outputs.eks_cluster_name
  k8s_root     = "${path.module}/../../../../kubernetes/prod"

  template_values = {
    ECR_REPOSITORY_URL   = data.terraform_remote_state.infra.outputs.ecr_repository_url
    IMAGE_TAG            = var.image_tag
    RDS_SECRET_ARN       = data.terraform_remote_state.infra.outputs.rds_secret_arn
    APP_SECRETS_ROLE_ARN = data.terraform_remote_state.addons.outputs.app_secrets_role_arn
  }
}

data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

resource "kubernetes_manifest" "namespace" {
  manifest = yamldecode(file("${local.k8s_root}/00-namespace/namespace.yaml"))
}

resource "kubernetes_manifest" "security" {
  for_each = fileset("${local.k8s_root}/01-security", "*.yaml")

  manifest = yamldecode(templatefile("${local.k8s_root}/01-security/${each.value}", local.template_values))

  depends_on = [kubernetes_manifest.namespace]
}

resource "kubernetes_manifest" "storage" {
  for_each = fileset("${local.k8s_root}/02-storage", "*.yaml")

  manifest = yamldecode(templatefile("${local.k8s_root}/02-storage/${each.value}", local.template_values))

  depends_on = [kubernetes_manifest.namespace]
}

resource "kubernetes_manifest" "application" {
  for_each = fileset("${local.k8s_root}/03-application", "*.yaml")

  manifest = yamldecode(templatefile("${local.k8s_root}/03-application/${each.value}", local.template_values))

  depends_on = [kubernetes_manifest.security, kubernetes_manifest.storage]
}

resource "kubernetes_manifest" "stateful" {
  for_each = fileset("${local.k8s_root}/04-stateful", "*.yaml")

  manifest = yamldecode(templatefile("${local.k8s_root}/04-stateful/${each.value}", local.template_values))

  depends_on = [kubernetes_manifest.security, kubernetes_manifest.storage]
}

resource "kubernetes_manifest" "operations" {
  for_each = fileset("${local.k8s_root}/05-operations", "*.yaml")

  manifest = yamldecode(templatefile("${local.k8s_root}/05-operations/${each.value}", local.template_values))

  depends_on = [kubernetes_manifest.application, kubernetes_manifest.stateful]
}

# NetworkPolicy is opt-in on the first apply, matching the repository's
# existing safety order. Turn it on after the application and metrics target
# are healthy, then apply again.
resource "kubernetes_manifest" "network_policy" {
  for_each = var.enable_network_policy ? fileset("${local.k8s_root}/06-network-policy", "*.yaml") : toset([])

  manifest = yamldecode(templatefile("${local.k8s_root}/06-network-policy/${each.value}", local.template_values))

  depends_on = [kubernetes_manifest.application]
}
