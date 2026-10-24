resource "aws_eks_addon" "secrets_store_csi" {
  cluster_name  = local.cluster_name
  addon_name    = "aws-secrets-store-csi-driver-provider"
  addon_version = "v3.1.4-eksbuild.2"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(local.common_tags, {
    Component = "Secrets-Store-CSI"
  })
}
