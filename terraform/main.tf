
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = "wordpress-project-sigma"
  region = "us-central1"
}

# Create GKE Cluster
resource "google_container_cluster" "primary" {
  name = "wordpress-cluster"
  location = "us-central1"

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count = 1
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name = "wordpress-node-pool"
  location = "us-central1"
  cluster = google_container_cluster.primary.name
  node_count = 3

  node_config {
    preemptible = true
    machine_type = "e2-medium"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

# Create a service account for the GKE nodes
resource "google_service_account" "default" {
  account_id = "wordpress-gke-sa"
  display_name = "WordPress GKE Service Account"
}

# Grant the service account permissions to access Cloud SQL
resource "google_project_iam_member" "cloudsql_client" {
  project = "wordpress-project-sigma"
  role = "roles/cloudsql.client"
  member = "serviceAccount:${google_service_account.default.email}"
}

# Create Cloud SQL instance
resource "google_sql_database_instance" "wordpress" {
  name = "wordpress-mysql-instance"
  database_version = "MYSQL_8_0"
  region = "us-central1"

  settings {
    tier = "db-f1-micro"
  }

  deletion_protection = false
}

# Create WordPress database
resource "google_sql_database" "wordpress" {
  name = "wordpress"
  instance = google_sql_database_instance.wordpress.name
}

# Create WordPress user
resource "google_sql_user" "wordpress" {
  name = "wordpress"
  instance = google_sql_database_instance.wordpress.name
  password = "changeme" # You should change this and use Secret Manager in production
}

# Create a static IP address for the load balancer
resource "google_compute_global_address" "wordpress" {
  name = "wordpress-ip"
}

# Output the necessary information
output "kubernetes_cluster_name" {
  value = google_container_cluster.primary.name
}

output "kubernetes_cluster_host" {
  value = google_container_cluster.primary.endpoint
}

output "database_instance_name" {
  value = google_sql_database_instance.wordpress.name
}

output "load_balancer_ip" {
  value = google_compute_global_address.wordpress.address
}
