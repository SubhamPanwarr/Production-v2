data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"

    labels = {
      "app.kubernetes.io/part-of" = "observability"
    }
  }
}

resource "kubernetes_secret_v1" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  type = "Opaque"

  data = {
    "admin-user"     = "admin"
    "admin-password" = var.grafana_admin_password
  }
}

resource "kubernetes_storage_class_v1" "ebs_gp3" {
  metadata {
    name = "ebs-gp3"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "oci://ghcr.io/prometheus-community/charts"
  chart      = "kube-prometheus-stack"
  version    = "93.10.1"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name

  create_namespace = false
  timeout          = 1200
  wait             = true

  values = [
    file("${path.module}/monitoring-values.yaml")
  ]

  depends_on = [
    kubernetes_storage_class_v1.ebs_gp3,
    kubernetes_secret_v1.grafana_admin
  ]
}
