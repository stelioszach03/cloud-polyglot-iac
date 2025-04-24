variable "location" {
  description = "The Azure region to deploy to"
  type        = string
  default     = "eastus"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "kubernetes_version" {
  description = "The Kubernetes version to use"
  type        = string
  default     = "1.28.0"
}

variable "vm_size" {
  description = "The size of the VM for the node pool"
  type        = string
  default     = "Standard_DS2_v2"
}

variable "node_count" {
  description = "The number of nodes in the node pool"
  type        = number
  default     = 2
}

variable "min_count" {
  description = "The minimum number of nodes in the node pool"
  type        = number
  default     = 1
}

variable "max_count" {
  description = "The maximum number of nodes in the node pool"
  type        = number
  default     = 3
}

variable "enable_auto_scaling" {
  description = "Enable auto scaling for the node pool"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}