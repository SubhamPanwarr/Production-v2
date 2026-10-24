variable "instance_name" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "ssh_allowed_cidrs" {
  type = list(string)
}

variable "root_volume_size" {
  type    = number
  default = 20
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "iam_instance_profile" {
  description = "IAM instance profile to attach to the EC2 instance"
  type        = string
  default     = null
}
