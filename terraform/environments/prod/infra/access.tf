resource "aws_eks_access_entry" "devops_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = var.devops_admin_principal_arn
  type          = "STANDARD"

  tags = merge(local.common_tags, {
    Component = "EKS-Access"
  })
}

resource "aws_eks_access_policy_association" "devops_admin_cluster_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_eks_access_entry.devops_admin.principal_arn

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
