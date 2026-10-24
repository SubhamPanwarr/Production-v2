resource "aws_eks_addon" "coredns" {
  cluster_name  = local.cluster_name
  addon_name    = "coredns"
  addon_version = "v1.14.7-eksbuild.19"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(local.common_tags, {
    Component = "CoreDNS"
  })
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = local.cluster_name
  addon_name    = "kube-proxy"
  addon_version = "v1.37.0-eksbuild.29"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(local.common_tags, {
    Component = "Kube-Proxy"
  })
}
