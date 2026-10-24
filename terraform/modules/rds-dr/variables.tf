variable "source_db_arn" {
  description = "ARN of primary RDS instance"
  type        = string
}

variable "dr_vpc_id" {
  description = "DR VPC ID"
  type        = string
}

variable "dr_private_subnet_ids" {
  description = "Private subnet IDs in DR Region"
  type        = list(string)
}

variable "create_cross_region_replica" {
  type    = bool
  default = false
}

variable "cross_region_replica_identifier" {
  type    = string
  default = "prod-mysql-dr-replica"
}

variable "replica_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "enable_cross_region_backups" {
  type    = bool
  default = false
}

variable "cross_region_backup_retention" {
  type    = number
  default = 7
}

variable "create_cross_region_snapshot" {
  type    = bool
  default = false
}

variable "source_snapshot_arn" {
  description = "Source snapshot ARN for optional cross-region copy"
  type        = string
  default     = null
}

variable "allowed_cidr_blocks" {
  description = "Application CIDRs allowed to access DR RDS after failover"
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
