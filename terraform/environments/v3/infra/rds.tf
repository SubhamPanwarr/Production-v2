module "rds" {
  source = "../../../modules/rds"

  identifier = "production-v3-mysql"

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.database_subnet_ids

  # Allow MySQL only from the EKS cluster security group.
  allowed_security_group_ids = [
    module.eks.cluster_security_group_id
  ]

  db_name     = "UserDB"
  db_username = "dbadmin"

  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 25

  multi_az            = false
  create_read_replica = false

  backup_retention_period = 1

  create_parameter_group = true

  deletion_protection = false
  skip_final_snapshot = true

  tags = local.common_tags
}
