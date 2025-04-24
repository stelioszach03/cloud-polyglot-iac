terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
  required_version = ">= 1.0.0"
}

provider "azurerm" {
  features {}
}

module "common_networking" {
  source = "../common-networking"
  
  project_name    = var.project_name
  environment     = var.environment
  dns_domain      = "azure.example.com"
  availability_zones = ["1", "2", "3"]  # Azure uses numbers for availability zones
  tags            = var.tags
}

locals {
  resource_prefix = module.common_networking.resource_prefix
  network_config  = module.common_networking.network_config
  common_tags     = module.common_networking.common_tags
}

# Create resource group
resource "azurerm_resource_group" "main" {
  name     = "${local.resource_prefix}-rg"
  location = var.location
  
  tags = local.common_tags
}

# Create virtual network
resource "azurerm_virtual_network" "main" {
  name                = "${local.resource_prefix}-vnet"
  address_space       = [local.network_config.cidr_block]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  tags = local.common_tags
}

# Create public subnets
resource "azurerm_subnet" "public" {
  count = length(local.network_config.public_subnet_cidrs)
  
  name                 = "${local.resource_prefix}-subnet-public-${count.index + 1}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.network_config.public_subnet_cidrs[count.index]]
}

# Create private subnets
resource "azurerm_subnet" "private" {
  count = length(local.network_config.private_subnet_cidrs)
  
  name                 = "${local.resource_prefix}-subnet-private-${count.index + 1}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.network_config.private_subnet_cidrs[count.index]]
}

# Create public IP for NAT gateway
resource "azurerm_public_ip" "nat" {
  name                = "${local.resource_prefix}-nat-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  
  tags = local.common_tags
}

# Create NAT gateway
resource "azurerm_nat_gateway" "main" {
  name                    = "${local.resource_prefix}-nat-gateway"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = ["1", "2", "3"]
  
  tags = local.common_tags
}

# Associate public IP with NAT gateway
resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

# Associate private subnets with NAT gateway
resource "azurerm_subnet_nat_gateway_association" "private" {
  count = length(azurerm_subnet.private)
  
  subnet_id      = azurerm_subnet.private[count.index].id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

# Create network security group for AKS
resource "azurerm_network_security_group" "aks" {
  name                = "${local.resource_prefix}-aks-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  tags = local.common_tags
}

# Associate NSG with private subnets
resource "azurerm_subnet_network_security_group_association" "private" {
  count = length(azurerm_subnet.private)
  
  subnet_id                 = azurerm_subnet.private[count.index].id
  network_security_group_id = azurerm_network_security_group.aks.id
}

# Create AKS cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${local.resource_prefix}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = local.resource_prefix
  kubernetes_version  = var.kubernetes_version
  
  default_node_pool {
    name                = "default"
    vm_size             = var.vm_size
    node_count          = var.enable_auto_scaling ? null : var.node_count
    min_count           = var.enable_auto_scaling ? var.min_count : null
    max_count           = var.enable_auto_scaling ? var.max_count : null
    enable_auto_scaling = var.enable_auto_scaling
    vnet_subnet_id      = azurerm_subnet.private[0].id
    zones               = ["1", "2", "3"]
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  network_profile {
    network_plugin     = "azure"
    load_balancer_sku  = "standard"
    network_policy     = "calico"
    service_cidr       = "10.1.0.0/16"
    dns_service_ip     = "10.1.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
  }
  
  tags = local.common_tags
}

# Create role assignment for AKS to access the vnet
resource "azurerm_role_assignment" "aks_network" {
  scope                = azurerm_virtual_network.main.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}