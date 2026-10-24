variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR range of the VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR of the public subnet"
  type        = string
  default     = null
}

variable "private_subnet_cidr" {
  description = "CIDR of the private subnet"
  type        = string
}

variable "tgw_subnet_cidr" {
  description = "CIDR of the Transit Gateway attachment subnet"
  type        = string
}

variable "availability_zone" {
  description = "Availability Zone"
  type        = string
}

variable "create_igw" {
  description = "Whether to create Internet Gateway"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}

variable "public_subnet_tags" {
  description = "Additional tags for public subnet"
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Additional tags for private subnet"
  type        = map(string)
  default     = {}
}
