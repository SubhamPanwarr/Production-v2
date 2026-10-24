# =======================================================
# DR KMS Key
# Required for encrypted cross-region replica/backups
# =======================================================

resource "aws_kms_key" "rds_dr" {
  description             = "KMS key for RDS DR resources"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "prod-rds-dr-kms"
    }
  )
}

resource "aws_kms_alias" "rds_dr" {
  name          = "alias/prod-rds-dr"
  target_key_id = aws_kms_key.rds_dr.key_id
}

# =======================================================
# DR DB Subnet Group
# =======================================================

resource "aws_db_subnet_group" "dr" {
  name = "prod-rds-dr-subnet-group"

  subnet_ids = var.dr_private_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "prod-rds-dr-subnet-group"
    }
  )
}

# =======================================================
# DR Security Group
# =======================================================

resource "aws_security_group" "rds_dr" {
  name        = "prod-rds-dr-sg"
  description = "Security group for DR RDS"
  vpc_id      = var.dr_vpc_id

  dynamic "ingress" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? [1] : []

    content {
      description = "MySQL from DR application network"

      from_port = 3306
      to_port   = 3306
      protocol  = "tcp"

      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "prod-rds-dr-sg"
    }
  )
}

# =======================================================
# Cross-Region Read Replica
# =======================================================

resource "aws_db_instance" "cross_region_replica" {
  count = var.create_cross_region_replica ? 1 : 0

  identifier = var.cross_region_replica_identifier

  # For cross-region replicas use the primary DB ARN.
  replicate_source_db = var.source_db_arn

  instance_class = var.replica_instance_class

  db_subnet_group_name = aws_db_subnet_group.dr.name

  vpc_security_group_ids = [
    aws_security_group.rds_dr.id
  ]

  publicly_accessible = false

  kms_key_id = aws_kms_key.rds_dr.arn

  storage_encrypted = true

  skip_final_snapshot = true

  auto_minor_version_upgrade = true

  tags = merge(
    var.tags,
    {
      Name = var.cross_region_replica_identifier
      Role = "CrossRegionReadReplica"
    }
  )
}

# =======================================================
# Cross-Region Automated Backup Replication
# =======================================================

resource "aws_db_instance_automated_backups_replication" "dr" {
  count = var.enable_cross_region_backups ? 1 : 0

  source_db_instance_arn = var.source_db_arn

  retention_period = var.cross_region_backup_retention

  kms_key_id = aws_kms_key.rds_dr.arn
}

# =======================================================
# Optional Manual Cross-Region Snapshot Copy
# =======================================================

resource "aws_db_snapshot_copy" "cross_region" {
  count = (
    var.create_cross_region_snapshot &&
    var.source_snapshot_arn != null
    ? 1
    : 0
  )

  source_db_snapshot_identifier = var.source_snapshot_arn

  target_db_snapshot_identifier = "prod-mysql-dr-snapshot"

  kms_key_id = aws_kms_key.rds_dr.arn

  copy_tags = true

  tags = merge(
    var.tags,
    {
      Name = "prod-mysql-dr-snapshot"
    }
  )
}
