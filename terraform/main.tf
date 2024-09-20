provider "google" {
  project = "wordpress-project-sigma"
  region = var.region
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = "wordpress-cluster"
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {}
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "wordpress-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1  # Reduced from 2 to 1

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only"
    ]

    labels = {
      env = "wordpress-project-sigma"
    }

    machine_type = "e2-medium"  # Changed from n1-standard-1 to e2-medium
    tags         = ["gke-node", "wordpress-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }

    disk_size_gb = 20  # Reduced disk size to 20 GB
    disk_type    = "pd-standard"  # Changed from SSD to standard persistent disk
  }
}


# Cloud SQL
resource "google_sql_database_instance" "wordpress" {
  name = "wordpress-mysql"
  database_version = "MYSQL_5_7"
  region = var.region

  settings {
    tier      = "db-f1-micro"
    disk_size = 10
  }

  deletion_protection = false
}

resource "google_sql_database" "wordpress" {
  name = "wordpress"
  instance = google_sql_database_instance.wordpress.name
}

resource "google_sql_user" "wordpress" {
  name = "wordpress-project-sigma"
  instance = google_sql_database_instance.wordpress.name
  password = "Aniket123"
}

# Cloud Storage Bucket
resource "google_storage_bucket" "wordpress_media" {
  name = "wordpress-project-sigma-media"
  location = var.region
}

# IAM
resource "google_service_account" "wordpress" {
  account_id = "wordpress-sa"
  display_name = "WordPress Service Account"
}

resource "google_project_iam_member" "wordpress_storage_admin" {
  project = "wordpress-project-sigma"
  role = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.wordpress.email}"
}

# Variables
variable "region" {
  description = "GCP region"
  default     = "us-central1"
}

variable "gke_num_nodes" {
  default = 2
  description = "Number of GKE nodes"
}

# Outputs
output "kubernetes_cluster_name" {
  value = google_container_cluster.primary.name
  description = "GKE Cluster Name"
}

output "kubernetes_cluster_host" {
  value = google_container_cluster.primary.endpoint
  description = "GKE Cluster Host"
}

output "db_instance_name" {
  value = google_sql_database_instance.wordpress.name
  description = "Cloud SQL Instance Name"
}

output "storage_bucket_name" {
  value = google_storage_bucket.wordpress_media.name
  description = "GCS Bucket Name"
}
