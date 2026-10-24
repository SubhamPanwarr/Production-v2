# Required by CPU/memory based HPA. Metrics Server is not installed by default on EKS.
resource "aws_eks_addon" "metrics_server" {
  cluster_name = local.cluster_name
  addon_name   = "metrics-server"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(local.common_tags, {
    Component = "Metrics-Server"
  })
}
