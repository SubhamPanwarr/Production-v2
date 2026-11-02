variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "aws_account_id" {
  type    = string
  default = "523881172609"
}
variable "cluster_name" {
  type    = string
  default = "production-v3-eks"
}
variable "vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
}
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}
variable "public_access_cidrs" {
  description = "Allowed public IP ranges for kubectl / EKS public API; use your public IP /32."
  type        = list(string)

  validation {
    condition     = length(var.public_access_cidrs) > 0 && alltrue([for cidr in var.public_access_cidrs : can(cidrhost(cidr, 0)) && cidr != "0.0.0.0/0" && cidr != "203.0.113.10/32"])
    error_message = "Set one or more valid, restricted public CIDRs (not 0.0.0.0/0)."
  }
}
