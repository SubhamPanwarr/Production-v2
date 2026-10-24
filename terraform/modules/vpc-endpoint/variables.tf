variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "route_table_ids" {
  description = "Route table IDs to associate with S3 Gateway Endpoint"
  type        = list(string)
}

variable "endpoint_name" {
  description = "Name of the VPC endpoint"
  type        = string
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
