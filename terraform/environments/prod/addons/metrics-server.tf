resource "aws_eks_addon" "metrics_server" {
  cluster_name  = local.cluster_name
  addon_name    = "metrics-server"
  addon_version = "v0.9.0-eksbuild.14"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(local.common_tags, {
    Component = "Metrics-Server"
  })
}
