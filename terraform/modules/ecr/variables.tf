variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "tags" {
  description = "Tags applied to ECR resources"
  type        = map(string)
  default     = {}
}
