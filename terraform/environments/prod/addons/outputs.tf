output "app_secrets_role_arn" {
  value = module.eks_secrets_access.role_arn
}

output "alb_controller_role_arn" {
  value = module.alb_controller_iam.iam_role_arn
}

output "cluster_name" {
  value = local.cluster_name
}

output "vpc_id" {
  value = local.vpc_id
}
