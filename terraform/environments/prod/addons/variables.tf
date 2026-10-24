variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "state_bucket" {
  description = "S3 bucket containing Terraform remote state"
  type        = string
}

variable "infra_state_key" {
  description = "Key for the infrastructure Terraform state"
  type        = string
  default     = "production-v2/infra/terraform.tfstate"
}

variable "app_namespace" {
  type    = string
  default = "production"
}

variable "app_service_account_name" {
  type    = string
  default = "production-app"
}
