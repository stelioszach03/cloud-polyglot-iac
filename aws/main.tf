terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
  required_version = ">= 1.0.0"
}

provider "aws" {
  region = var.region
}

module "common_networking" {
  source = "../common-networking"
  
  project_name    = var.project_name
  environment     = var.environment
  dns_domain      = "aws.example.com"
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 3)
  tags            = var.tags
}

locals {
  cluster_name    = "${module.common_networking.resource_prefix}-eks"
  vpc_name        = "${module.common_networking.resource_prefix}-vpc"
  subnet_name     = "${module.common_networking.resource_prefix}-subnet"
  role_name       = "${module.common_networking.resource_prefix}-role"
  sg_name         = "${module.common_networking.resource_prefix}-sg"
  network_config  = module.common_networking.network_config
  common_tags     = module.common_networking.common_tags
}

data "aws_availability_zones" "available" {}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = local.network_config.cidr_block
  enable_dns_hostnames = local.network_config.enable_dns_hostnames
  enable_dns_support   = local.network_config.enable_dns_support
  
  tags = merge(
    local.common_tags,
    {
      Name = local.vpc_name
    }
  )
}

# Rest of the aws/main.tf content...
