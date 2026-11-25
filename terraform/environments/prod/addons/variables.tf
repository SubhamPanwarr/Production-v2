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

variable "grafana_admin_password" {
  description = "Grafana admin password. Provide through TF_VAR_grafana_admin_password; do not commit it in a tfvars file."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.grafana_admin_password) >= 16
    error_message = "Grafana admin password must contain at least 16 characters."
  }
}
