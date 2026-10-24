variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the EKS cluster and managed node group"
  type        = list(string)
}

variable "instance_types" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "capacity_type" {
  description = "Capacity type for EKS worker nodes"
  type        = string
  default     = "ON_DEMAND"
}

variable "desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 4
}

variable "tags" {
  description = "Tags applied to EKS resources"
  type        = map(string)
  default     = {}
}

# =======================================================
# Dedicated Workload Node Group
# =======================================================

variable "create_workload_node_group" {
  description = "Create a dedicated managed node group for application workloads"
  type        = bool
  default     = true
}

variable "workload_node_group_name" {
  description = "Name of the dedicated application node group"
  type        = string
  default     = "application"
}

variable "workload_instance_types" {
  description = "Instance types used by the dedicated workload node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "workload_min_size" {
  description = "Minimum nodes in workload node group"
  type        = number
  default     = 2
}

variable "workload_desired_size" {
  description = "Desired nodes in workload node group"
  type        = number
  default     = 2
}

variable "workload_max_size" {
  description = "Maximum nodes in workload node group"
  type        = number
  default     = 4
}

variable "workload_labels" {
  description = "Kubernetes labels applied to dedicated workload nodes"

  type = map(string)

  default = {
    workload = "frontend"
  }
}

variable "workload_taints" {
  description = "Kubernetes taints applied to dedicated workload nodes"

  type = list(object({
    key    = string
    value  = string
    effect = string
  }))

  default = [
    {
      key    = "dedicated"
      value  = "frontend"
      effect = "NO_SCHEDULE"
    }
  ]
}
