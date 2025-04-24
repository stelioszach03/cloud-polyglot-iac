# This module provides common networking definitions that can be used across cloud providers
# It doesn't create actual resources, but defines data structures to be consumed by provider-specific modules

locals {
  resource_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
  
  # Common networking configuration to be used across cloud providers
  network_config = {
    cidr_block            = var.cidr_block
    public_subnet_cidrs   = var.public_subnet_cidrs
    private_subnet_cidrs  = var.private_subnet_cidrs
    availability_zones    = var.availability_zones
    enable_dns_hostnames  = var.enable_dns_hostnames
    enable_dns_support    = var.enable_dns_support
    dns_domain            = var.dns_domain
  }
}

# Output network configuration to be consumed by other modules
output "network_config" {
  description = "Network configuration to be used by cloud provider modules"
  value       = local.network_config
}

output "resource_prefix" {
  description = "Common prefix for resource names"
  value       = local.resource_prefix
}

output "common_tags" {
  description = "Common tags to be applied to all resources"
  value       = local.common_tags
}
