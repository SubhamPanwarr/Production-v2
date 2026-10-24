resource "aws_eks_addon" "vpc_cni" {
  cluster_name = local.cluster_name
  addon_name   = "vpc-cni"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  configuration_values = jsonencode({
    enableNetworkPolicy = "true"

    nodeAgent = {
      healthProbeBindAddr = "8163"
      metricsBindAddr     = "8162"
    }
  })

  tags = local.common_tags
}
