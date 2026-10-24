variable "name" {
  type = string
}

variable "description" {
  type    = string
  default = "Transit Gateway"
}

variable "vpc_attachments" {
  type = map(object({
    vpc_id     = string
    subnet_ids = list(string)
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
