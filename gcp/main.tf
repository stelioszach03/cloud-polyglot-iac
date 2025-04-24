terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
  required_version = ">= 1.0.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

module "common_networking" {
  source = "../common-networking"
  
  project_name       = var.project_name
  environment        = var.environment
  dns_domain         = "gcp.example.com"
  availability_zones = var.zones
  tags               = var.tags
}

locals {
  resource_prefix = module.common_networking.resource_prefix
  network_config  = module.common_networking.network_config
  common_tags     = module.common_networking.common_tags
  
  # Convert tags map to labels format
  labels = {
    for k, v in local.common_tags :
    k => lower(replace(v, "/[^a-zA-Z0-9-_]/", "_"))
  }
}

# Create VPC network
resource "google_compute_network" "main" {
  name                    = "${local.resource_prefix}-vpc"
  auto_create_subnetworks = false
  
  # GCP compute networks don't support labels directly
  description = "VPC network for ${local.resource_prefix}"
}

# Create public subnets
resource "google_compute_subnetwork" "public" {
  count = length(local.network_config.public_subnet_cidrs)
  
  name          = "${local.resource_prefix}-subnet-public-${count.index + 1}"
  network       = google_compute_network.main.id
  ip_cidr_range = local.network_config.public_subnet_cidrs[count.index]
  region        = var.region
  
  # Enable Google Cloud NAT in the subnetwork
  purpose = "PRIVATE"
  
  # Enable flow logs for security analysis
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
  
  description = "Public subnet ${count.index + 1} for ${local.resource_prefix}"
  # Subnetworks don't support labels directly
}

# Create private subnets
resource "google_compute_subnetwork" "private" {
  count = length(local.network_config.private_subnet_cidrs)
  
  name          = "${local.resource_prefix}-subnet-private-${count.index + 1}"
  network       = google_compute_network.main.id
  ip_cidr_range = local.network_config.private_subnet_cidrs[count.index]
  region        = var.region
  
  # Enable private Google access
  private_ip_google_access = true
  
  # Secondary IP ranges for GKE pods and services
  secondary_ip_range {
    range_name    = "pods-range"
    ip_cidr_range = "10.10.${count.index}.0/24"
  }
  
  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "10.20.${count.index}.0/24"
  }
  
  # Enable flow logs for security analysis
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
  
  description = "Private subnet ${count.index + 1} for ${local.resource_prefix}"
  # Subnetworks don't support labels directly
}

# Create Cloud Router for NAT
resource "google_compute_router" "router" {
  name    = "${local.resource_prefix}-router"
  region  = var.region
  network = google_compute_network.main.id
  
  bgp {
    asn = 64514
  }
  
  description = "Router for ${local.resource_prefix}"
  # Routers don't support labels directly
}

# Create Cloud NAT for private instances
resource "google_compute_router_nat" "nat" {
  name                               = "${local.resource_prefix}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Create firewall rule for allowing internal communication
resource "google_compute_firewall" "internal" {
  name    = "${local.resource_prefix}-fw-internal"
  network = google_compute_network.main.id
  
  allow {
    protocol = "icmp"
  }
  
  allow {
    protocol = "tcp"
  }
  
  allow {
    protocol = "udp"
  }
  
  source_ranges = concat(
    local.network_config.public_subnet_cidrs,
    local.network_config.private_subnet_cidrs
  )
  
  target_tags = ["kubernetes"]
  
  description = "Allow internal communication for ${local.resource_prefix}"
  # Firewalls don't support labels directly
}

# Create firewall rule for allowing health checks
resource "google_compute_firewall" "health_check" {
  name    = "${local.resource_prefix}-fw-health-check"
  network = google_compute_network.main.id
  
  allow {
    protocol = "tcp"
  }
  
  # Health check IP ranges
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  
  target_tags = ["kubernetes"]
  
  description = "Allow health checks for ${local.resource_prefix}"
  # Firewalls don't support labels directly
}

# Create service account for GKE nodes
resource "google_service_account" "gke_nodes" {
  account_id   = "${local.resource_prefix}-gke-sa"
  display_name = "GKE Service Account for ${local.resource_prefix}"
}

# Grant necessary roles to the service account
resource "google_project_iam_member" "gke_nodes_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/storage.objectViewer",
    "roles/artifactregistry.reader",
  ])
  
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Create GKE cluster
resource "google_container_cluster" "main" {
  name     = "${local.resource_prefix}-gke"
  location = var.region
  
  # We can't create a cluster with no node pool defined, but we want to use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  
  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.private[0].id
  
  # Specify the ranges to use for the pods and services
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods-range"
    services_secondary_range_name = "services-range"
  }
  
  # Enable private cluster
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  
  # Enable network policy
  network_policy {
    enabled  = true
    provider = "CALICO"
  }
  
  # Enable workload identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  
  # Enable Kubernetes Dashboard
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }
  
  # Set maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }
  
  # Set the minimum Kubernetes version
  min_master_version = var.kubernetes_version
  
  # Add resource labels - GKE clusters do support resource_labels
  resource_labels = local.labels
}

# Create GKE node pool
resource "google_container_node_pool" "main" {
  name       = "${local.resource_prefix}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.main.name
  
  initial_node_count = var.initial_node_count
  
  # Enable autoscaling
  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }
  
  # Set node management options
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  
  # Set upgrade settings to minimize disruption
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
  
  # Configure the nodes
  node_config {
    machine_type = var.node_machine_type
    
    # Specify disk size and type
    disk_size_gb = 100
    disk_type    = "pd-standard"
    
    # Specify service account and scopes
    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    
    # Add metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }
    
    # Node config does support labels
    labels = local.labels
    tags   = ["kubernetes", local.resource_prefix]
    
    # Enable workload identity on the nodes
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}
