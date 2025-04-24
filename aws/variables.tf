variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-1"
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

# Rest of variables...
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
