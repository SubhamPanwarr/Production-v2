module "eks" {
  source = "../../../modules/eks"

  cluster_name = var.eks_cluster_name

  private_subnet_ids = [
    module.vpc_a.private_subnet_id,
    aws_subnet.vpc_a_private_2.id
  ]

  # General-purpose node group
  instance_types = ["t3.small"]
  min_size       = 2
  desired_size   = 3
  max_size       = 4
  capacity_type  = "ON_DEMAND"

  # Dedicated frontend node group
  create_workload_node_group = true
  workload_node_group_name   = "frontend"
  workload_instance_types    = ["t3.small"]

  workload_min_size     = 1
  workload_desired_size = 1
  workload_max_size     = 2

  workload_labels = {
    workload    = "frontend"
    environment = "production"
  }

  workload_taints = [
    {
      key    = "dedicated"
      value  = "frontend"
      effect = "NO_SCHEDULE"
    }
  ]

  tags = merge(local.common_tags, {
    ManagedBy = "Terraform"
    Component = "EKS"
  })
}
