# =======================================================
# Application data bucket
# =======================================================
module "s3" {
  source = "../../../modules/s3"

  bucket_name        = var.app_data_bucket_name
  versioning_enabled = true

  tags = local.common_tags
}

module "ec2_s3_iam" {
  source = "../../../modules/iam-ec2-s3"

  role_name  = "prod-ec2-s3-role"
  bucket_arn = module.s3.bucket_arn
}

# =======================================================
# RDS MySQL
# =======================================================
module "rds" {
  source = "../../../modules/rds"

  identifier = "prod-mysql"
  vpc_id     = module.vpc_a.vpc_id

  subnet_ids = [
    module.vpc_a.private_subnet_id,
    aws_subnet.vpc_a_private_2.id
  ]

  allowed_security_group_ids = [
    module.ec2_a.security_group_id,
    module.eks.cluster_security_group_id
  ]

  db_name     = "productiondb"
  db_username = var.db_username

  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 100
  multi_az              = false

  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Sun:04:00-Sun:05:00"

  delete_automated_backups = true
  deletion_protection      = false
  skip_final_snapshot      = true

  create_parameter_group = true
  parameter_group_family = "mysql8.0"
  slow_query_log_enabled = true
  long_query_time        = 2

  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_retention_period = 7

  create_read_replica         = var.create_rds_read_replica
  read_replica_identifier     = "prod-mysql-read-1"
  read_replica_instance_class = "db.t3.micro"

  tags = local.common_tags
}
