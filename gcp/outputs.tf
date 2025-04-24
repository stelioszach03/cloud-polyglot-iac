output "vpc_name" {
  description = "The name of the VPC"
  value       = google_compute_network.main.name
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = google_compute_network.main.id
}

output "public_subnet_names" {
  description = "The names of the public subnets"
  value       = google_compute_subnetwork.public[*].name
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets"
  value       = google_compute_subnetwork.public[*].id
}

output "private_subnet_names" {
  description = "The names of the private subnets"
  value       = google_compute_subnetwork.private[*].name
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets"
  value       = google_compute_subnetwork.private[*].id
}

output "gke_cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.main.name
}

output "gke_cluster_id" {
  description = "The ID of the GKE cluster"
  value       = google_container_cluster.main.id
}

output "gke_cluster_endpoint" {
  description = "The endpoint of the GKE cluster"
  value       = google_container_cluster.main.endpoint
  sensitive   = true
}

output "gke_cluster_certificate" {
  description = "The certificate data for the GKE cluster"
  value       = google_container_cluster.main.master_auth.0.cluster_ca_certificate
  sensitive   = true
}

output "gke_node_pool_name" {
  description = "The name of the GKE node pool"
  value       = google_container_node_pool.main.name
}

output "kubernetes_version" {
  description = "The Kubernetes version of the GKE cluster"
  value       = google_container_cluster.main.master_version
}

output "kubectl_config_command" {
  description = "The command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.main.name} --region ${var.region} --project ${var.project_id}"
}