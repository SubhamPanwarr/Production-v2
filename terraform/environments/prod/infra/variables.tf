variable "aws_region" {
  description = "Primary AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "Disaster recovery AWS Region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "availability_zone" {
  type    = string
  default = "us-east-1a"
}

variable "availability_zone_2" {
  type    = string
  default = "us-east-1b"
}

variable "key_name" {
  description = "Existing EC2 key pair name"
  type        = string
}

variable "admin_cidr" {
  description = "Administrator public IP in CIDR format, for example 203.0.113.10/32"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ami_id" {
  description = "Pinned AMI ID for EC2 instances"
  type        = string
}

variable "db_username" {
  description = "RDS master username; password is managed by RDS in Secrets Manager"
  type        = string
  sensitive   = true
}

variable "eks_cluster_name" {
  description = "Production EKS cluster name"
  type        = string
  default     = "production-eks-cluster"
}

variable "devops_admin_principal_arn" {
  description = "IAM principal ARN that receives EKS cluster-admin access"
  type        = string
}

variable "app_data_bucket_name" {
  description = "Globally unique S3 bucket name for application data"
  type        = string
}

variable "ecr_repository_name" {
  type    = string
  default = "production-app"
}

variable "create_rds_read_replica" {
  type    = bool
  default = false
}

variable "create_cross_region_replica" {
  type    = bool
  default = false
}

variable "enable_cross_region_backups" {
  type    = bool
  default = false
}

variable "create_cross_region_snapshot" {
  type    = bool
  default = false
}

variable "enable_performance_insights" {
  type    = bool
  default = false
}
