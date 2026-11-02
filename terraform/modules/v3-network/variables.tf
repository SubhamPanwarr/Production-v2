variable "name" {
  description = "Name prefix for v3 networking resources."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name used in subnet discovery tags."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR; use a /16 to create /24 subnets."
  type        = string
  default     = "10.30.0.0/16"
}

variable "availability_zones" {
  description = "Two distinct AZs in the selected AWS region."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2 && var.availability_zones[0] != var.availability_zones[1]
    error_message = "Provide exactly two distinct availability zones."
  }
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}
