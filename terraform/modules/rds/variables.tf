variable "identifier" {
  description = "Primary RDS instance identifier"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for RDS"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to connect to RDS"
  type        = list(string)
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "productiondb"
}

variable "db_username" {
  description = "Database administrator username"
  type        = string
  sensitive   = true
}

variable "engine" {
  description = "Database engine"
  type        = string
  default     = "mysql"
}

variable "engine_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0.46"
}

variable "instance_class" {
  description = "Primary RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage autoscaling size"
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = false
}

# -------------------------------------------------------
# Backup
# -------------------------------------------------------

variable "backup_retention_period" {
  description = "Automated backup retention in days"
  type        = number
  default     = 1
}

variable "backup_window" {
  description = "Preferred automated backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "Sun:04:00-Sun:05:00"
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "delete_automated_backups" {
  description = "Delete automated backups when DB is deleted"
  type        = bool
  default     = true
}

# -------------------------------------------------------
# Parameter Group
# -------------------------------------------------------

variable "create_parameter_group" {
  description = "Create custom DB parameter group"
  type        = bool
  default     = true
}

variable "parameter_group_family" {
  description = "DB parameter group family"
  type        = string
  default     = "mysql8.0"
}

variable "slow_query_log_enabled" {
  description = "Enable MySQL slow query logging"
  type        = bool
  default     = true
}

variable "long_query_time" {
  description = "Number of seconds before query is considered slow"
  type        = number
  default     = 2
}

# -------------------------------------------------------
# Performance Insights
# -------------------------------------------------------

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = false
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention period in days"
  type        = number
  default     = 7
}

# -------------------------------------------------------
# Same-region Read Replica
# -------------------------------------------------------

variable "create_read_replica" {
  description = "Create same-region read replica"
  type        = bool
  default     = false
}

variable "read_replica_identifier" {
  description = "Read replica identifier"
  type        = string
  default     = "prod-mysql-read-1"
}

variable "read_replica_instance_class" {
  description = "Read replica instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}


