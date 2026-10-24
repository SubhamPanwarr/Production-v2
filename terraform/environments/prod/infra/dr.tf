# =======================================================
# DR VPC - secondary region
# =======================================================
resource "aws_vpc" "dr" {
  provider = aws.dr

  cidr_block           = "10.30.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "prod-dr-vpc"
  }
}

resource "aws_subnet" "dr_private_a" {
  provider = aws.dr

  vpc_id                  = aws_vpc.dr.id
  cidr_block              = "10.30.1.0/24"
  availability_zone       = "${var.dr_region}a"
  map_public_ip_on_launch = false

  tags = {
    Name = "prod-dr-private-a"
  }
}

resource "aws_subnet" "dr_private_b" {
  provider = aws.dr

  vpc_id                  = aws_vpc.dr.id
  cidr_block              = "10.30.2.0/24"
  availability_zone       = "${var.dr_region}b"
  map_public_ip_on_launch = false

  tags = {
    Name = "prod-dr-private-b"
  }
}

module "rds_dr" {
  source = "../../../modules/rds-dr"

  providers = {
    aws = aws.dr
  }

  source_db_arn = module.rds.db_instance_arn
  dr_vpc_id     = aws_vpc.dr.id

  dr_private_subnet_ids = [
    aws_subnet.dr_private_a.id,
    aws_subnet.dr_private_b.id
  ]

  create_cross_region_replica     = var.create_cross_region_replica
  cross_region_replica_identifier = "prod-mysql-dr-replica"
  replica_instance_class          = "db.t3.micro"

  enable_cross_region_backups   = var.enable_cross_region_backups
  cross_region_backup_retention = 7

  create_cross_region_snapshot = var.create_cross_region_snapshot
  source_snapshot_arn          = null

  allowed_cidr_blocks = []

  tags = merge(local.common_tags, {
    Purpose = "Disaster-Recovery"
  })
}
