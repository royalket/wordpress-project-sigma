terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = "wordpress-cluster"
  location = var.region
  
  # Use a regional cluster for better availability
  remove_default_node_pool = true
  initial_node_count       = 1

  # Enable workload identity for better security
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "wordpress-node-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name

  # Reduce node count to stay within quotas
  node_count = 2

  node_config {
    preemptible  = true
    machine_type = "e2-small"  # Smaller instance type

    # Enable workload identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

# Cloud SQL Instance
resource "google_sql_database_instance" "wordpress" {
  name             = "wordpress-db-instance"
  database_version = "MYSQL_5_7"
  region           = var.region

  settings {
    tier      = "db-f1-micro"
    disk_size = 10  # Reduced disk size
    
    backup_configuration {
      enabled = true
    }
  }

  deletion_protection = false  # Allow Terraform to delete the instance
}

resource "google_sql_database" "wordpress" {
  name     = "wordpress"
  instance = google_sql_database_instance.wordpress.name
}

data "google_secret_manager_secret_version" "db_password" {
  secret = "wordpress-db-password"
}

resource "google_sql_user" "wordpress" {
  name     = "wordpress"
  instance = google_sql_database_instance.wordpress.name
  password = data.google_secret_manager_secret_version.db_password.secret_data
}

# Cloud Storage Bucket
resource "google_storage_bucket" "wordpress_uploads" {
  name     = "${var.project_id}-wordpress-uploads"
  location = var.region

  # Ensure the bucket is not public
  uniform_bucket_level_access = true
}

# Artifact Registry Repository
resource "google_artifact_registry_repository" "wordpress_repo" {
  location      = var.region
  repository_id = "wordpress-repo"
  format        = "DOCKER"

}

# Variables
variable "project_id" {
  description = "The project ID to deploy to"
  type        = string
  default     = "wordpress-project-sigma"
}

variable "region" {
  description = "The region to deploy to"
  type        = string
  default     = "us-central1"
}