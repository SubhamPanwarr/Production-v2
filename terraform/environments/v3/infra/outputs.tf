output "vpc_id" {
  value = module.network.vpc_id
}
output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}
output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}
output "database_subnet_ids" {
  value = module.network.database_subnet_ids
}
output "nat_gateway_id" {
  value = module.network.nat_gateway_id
}
output "eks_cluster_name" {
  value = module.eks.cluster_name
}
output "eks_node_group_name" {
  value = module.eks.node_group_name
}
output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
output "eks_node_role_arn" {
  value = module.eks.node_role_arn
}
output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}
output "eks_cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}
