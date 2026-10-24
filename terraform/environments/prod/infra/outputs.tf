output "transit_gateway_id" {
  value = module.transit_gateway.transit_gateway_id
}

output "vpc_a_id" {
  value = module.vpc_a.vpc_id
}

output "vpc_b_id" {
  value = module.vpc_b.vpc_id
}

output "vpc_a_public_subnet_ids" {
  value = [
    module.vpc_a.public_subnet_id,
    aws_subnet.vpc_a_public_2.id
  ]
}

output "vpc_a_private_subnet_ids" {
  value = [
    module.vpc_a.private_subnet_id,
    aws_subnet.vpc_a_private_2.id
  ]
}

output "bastion_public_ip" {
  value = module.bastion.public_ip
}

output "ec2_a_private_ip" {
  value = module.ec2_a.private_ip
}

output "ec2_b_private_ip" {
  value = module.ec2_b.private_ip
}

output "s3_bucket_name" {
  value = module.s3.bucket_name
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "eks_oidc_provider_url" {
  value = module.eks.oidc_provider_url
}

output "eks_node_group_name" {
  value = module.eks.node_group_name
}

output "rds_primary_endpoint" {
  value = module.rds.endpoint
}

output "rds_primary_arn" {
  value = module.rds.db_instance_arn
}

output "rds_secret_arn" {
  value     = module.rds.master_user_secret_arn
  sensitive = true
}

output "rds_cross_region_replica_endpoint" {
  value = module.rds_dr.cross_region_replica_endpoint
}

output "rds_dr_kms_key_arn" {
  value = module.rds_dr.dr_kms_key_arn
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}
