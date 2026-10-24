module "ecr" {
  source = "../../../modules/ecr"

  repository_name = var.ecr_repository_name

  tags = merge(local.common_tags, {
    Component = "ECR"
  })
}
