# =======================================================
# RDS DB Subnet Group
# =======================================================

resource "aws_db_subnet_group" "this" {
  name = "${var.identifier}-subnet-group"

  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-subnet-group"
    }
  )
}

# =======================================================
# RDS Security Group
# =======================================================

resource "aws_security_group" "rds" {
  name        = "${var.identifier}-sg"
  description = "Allow MySQL access from application EC2"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from application EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
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
      Name = "${var.identifier}-sg"
    }
  )
}

# =======================================================
# Custom MySQL Parameter Group
# =======================================================

resource "aws_db_parameter_group" "this" {
  count = var.create_parameter_group ? 1 : 0

  name   = "${var.identifier}-parameter-group"
  family = var.parameter_group_family

  parameter {
    name  = "slow_query_log"
    value = var.slow_query_log_enabled ? "1" : "0"
  }

  parameter {
    name  = "long_query_time"
    value = tostring(var.long_query_time)
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-parameter-group"
    }
  )
}

# =======================================================
# Primary RDS MySQL
# =======================================================

resource "aws_db_instance" "this" {
  identifier = var.identifier

  engine         = "mysql"
  engine_version = var.engine_version

  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"

  db_name  = var.db_name
  username = var.db_username

  manage_master_user_password = true

  port = 3306

  db_subnet_group_name = aws_db_subnet_group.this.name

  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]

  parameter_group_name = var.create_parameter_group ? aws_db_parameter_group.this[0].name : null

  publicly_accessible = false

  multi_az = var.multi_az

  storage_encrypted = true

  # ---------------------------------------------------
  # Backup Policy
  # ---------------------------------------------------

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window

  copy_tags_to_snapshot = true

  delete_automated_backups = var.delete_automated_backups

  maintenance_window = var.maintenance_window

  # ---------------------------------------------------
  # Protection
  # ---------------------------------------------------

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot

  # ---------------------------------------------------
  # Performance Insights
  # ---------------------------------------------------

  performance_insights_enabled = var.performance_insights_enabled

  performance_insights_retention_period = (
    var.performance_insights_enabled
    ? var.performance_insights_retention_period
    : null
  )

  auto_minor_version_upgrade = true

  tags = merge(
    var.tags,
    {
      Name = var.identifier
      Role = "Primary"
    }
  )
}

# =======================================================
# Same-Region Read Replica
# =======================================================

resource "aws_db_instance" "read_replica" {
  count = var.create_read_replica ? 1 : 0

  identifier = var.read_replica_identifier

  # ARN is used because a DB subnet group is explicitly set.
  replicate_source_db = aws_db_instance.this.arn

  instance_class = var.read_replica_instance_class

  db_subnet_group_name = aws_db_subnet_group.this.name

  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]

  publicly_accessible = false

  auto_minor_version_upgrade = true

  performance_insights_enabled = var.performance_insights_enabled

  performance_insights_retention_period = (
    var.performance_insights_enabled
    ? var.performance_insights_retention_period
    : null
  )

  skip_final_snapshot = true

  tags = merge(
    var.tags,
    {
      Name = var.read_replica_identifier
      Role = "ReadReplica"
    }
  )

  depends_on = [
    aws_db_instance.this
  ]
}
