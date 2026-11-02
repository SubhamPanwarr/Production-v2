locals {
  common_tags = {
    Component = "Production-v3-Infra"
  }
}

module "network" {
  source             = "../../../modules/v3-network"
  name               = "production-v3"
  cluster_name       = var.cluster_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  tags               = local.common_tags
}

# Reuse existing repository module; disable its extra dedicated/tainted node group.
module "eks" {
  source                     = "../../../modules/eks"
  cluster_name               = var.cluster_name
  private_subnet_ids         = module.network.private_subnet_ids
  public_access_cidrs        = var.public_access_cidrs
  instance_types             = ["m7i-flex.large"]
  capacity_type              = "ON_DEMAND"
  min_size                   = 2
  desired_size               = 2
  max_size                   = 3
  create_workload_node_group = false
  tags                       = local.common_tags
}
