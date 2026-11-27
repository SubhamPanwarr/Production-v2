variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket" {
  description = "S3 bucket containing the infra/add-ons/workloads Terraform states"
  type        = string
}

variable "infra_state_key" {
  type    = string
  default = "production-v2/infra/terraform.tfstate"
}

variable "addons_state_key" {
  type    = string
  default = "production-v2/addons/terraform.tfstate"
}

variable "image_tag" {
  description = "Immutable tag already pushed to the production-app ECR repository"
  type        = string
}

variable "enable_network_policy" {
  description = "Enable the production ingress policy after validating app and Prometheus scraping"
  type        = bool
  default     = false
}
