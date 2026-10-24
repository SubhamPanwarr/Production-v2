############################################
# EKS CONTROL PLANE IAM ROLE
############################################

resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

############################################
# EKS CLUSTER
############################################

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = var.tags
}

############################################
# WORKER NODE IAM ROLE
############################################

resource "aws_iam_role" "eks_node_role" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ecr_pull_only" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

############################################
# EKS MANAGED NODE GROUP
############################################

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.instance_types
  capacity_type  = var.capacity_type

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_node_policy,
    aws_iam_role_policy_attachment.ecr_pull_only,
    aws_iam_role_policy_attachment.cni_policy
  ]

  tags = var.tags
}

############################################
# EKS OIDC PROVIDER
############################################

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint
  ]

  tags = var.tags
}

############################################
# DEDICATED APPLICATION NODE GROUP
############################################

resource "aws_eks_node_group" "workload" {
  count = var.create_workload_node_group ? 1 : 0

  cluster_name = aws_eks_cluster.this.name

  node_group_name = "${var.cluster_name}-${var.workload_node_group_name}-node-group"

  node_role_arn = aws_iam_role.eks_node_role.arn

  subnet_ids = var.private_subnet_ids

  instance_types = var.workload_instance_types

  capacity_type = "ON_DEMAND"

  scaling_config {
    desired_size = var.workload_desired_size
    min_size     = var.workload_min_size
    max_size     = var.workload_max_size
  }

  update_config {
    max_unavailable = 1
  }

  # -----------------------------------------------------
  # Kubernetes Node Labels
  # -----------------------------------------------------

  labels = var.workload_labels

  # -----------------------------------------------------
  # Kubernetes Node Taints
  # -----------------------------------------------------

  dynamic "taint" {
    for_each = var.workload_taints

    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  depends_on = [
    aws_eks_node_group.this,
    aws_iam_role_policy_attachment.worker_node_policy,
    aws_iam_role_policy_attachment.ecr_pull_only,
    aws_iam_role_policy_attachment.cni_policy
  ]

  tags = merge(
    var.tags,
    {
      NodeGroup = "application"
      Workload  = "frontend"
    }
  )
}
