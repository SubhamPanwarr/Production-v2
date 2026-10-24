output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.this.arn
}

output "node_group_name" {
  description = "EKS managed node group name"
  value       = aws_eks_node_group.this.node_group_name
}

output "node_role_arn" {
  description = "IAM role used by EKS worker nodes"
  value       = aws_iam_role.eks_node_role.arn
}


output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate authority data for the EKS cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "cluster_security_group_id" {
  description = "EKS cluster security group"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "workload_node_group_name" {
  description = "Dedicated application managed node group name"

  value = var.create_workload_node_group ? (
    aws_eks_node_group.workload[0].node_group_name
  ) : null
}
