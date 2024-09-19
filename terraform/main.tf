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

# Check if GKE cluster already exists
data "google_container_cluster" "existing_cluster" {
  name     = "wordpress-cluster"
  location = var.region
  project  = var.project_id

  # This prevents Terraform from erroring if the cluster doesn't exist
  count = can(data.google_container_cluster.existing_cluster) ? 1 : 0
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  count    = length(data.google_container_cluster.existing_cluster) == 0 ? 1 : 0
  name     = "wordpress-cluster"
  location = var.region
  
  remove_default_node_pool = true
  initial_node_count       = 1

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

# Check if node pool already exists
data "google_container_node_pool" "existing_pool" {
  name       = "wordpress-node-pool"
  location   = var.region
  cluster    = "wordpress-cluster"
  project    = var.project_id

  count = can(data.google_container_node_pool.existing_pool) ? 1 : 0
}

resource "google_container_node_pool" "primary_nodes" {
  count    = length(data.google_container_node_pool.existing_pool) == 0 ? 1 : 0
  name     = "wordpress-node-pool"
  location = var.region
  cluster  = google_container_cluster.primary[0].name
  
  node_count = 2

  node_config {
    preemptible  = true
    machine_type = "e2-small"

    workload_metadata_config {
      node_metadata = "GKE_METADATA_SERVER"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

# Check if Cloud SQL instance already exists
data "google_sql_database_instance" "existing_db" {
  name = "wordpress-db-instance"

  count = can(data.google_sql_database_instance.existing_db) ? 1 : 0
}

# Cloud SQL Instance
resource "google_sql_database_instance" "wordpress" {
  count            = length(data.google_sql_database_instance.existing_db) == 0 ? 1 : 0
  name             = "wordpress-db-instance"
  database_version = "MYSQL_5_7"
  region           = var.region

  settings {
    tier      = "db-f1-micro"
    disk_size = 10
    
    backup_configuration {
      enabled = true
    }
  }

  deletion_protection = false
}

resource "google_sql_database" "wordpress" {
  name     = "wordpress"
  instance = length(google_sql_database_instance.wordpress) > 0 ? google_sql_database_instance.wordpress[0].name : data.google_sql_database_instance.existing_db[0].name
}

data "google_secret_manager_secret_version" "db_password" {
  secret = "wordpress-db-password"
}

resource "google_sql_user" "wordpress" {
  name     = "wordpress"
  instance = length(google_sql_database_instance.wordpress) > 0 ? google_sql_database_instance.wordpress[0].name : data.google_sql_database_instance.existing_db[0].name
  password = data.google_secret_manager_secret_version.db_password.secret_data
}

# Cloud Storage Bucket
resource "google_storage_bucket" "wordpress_uploads" {
  name     = "${var.project_id}-wordpress-uploads"
  location = var.region

  uniform_bucket_level_access = true

  # Skip creation if bucket already exists
  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

# Artifact Registry Repository
resource "google_artifact_registry_repository" "wordpress_repo" {
  location      = var.region
  repository_id = "wordpress-repo"
  format        = "DOCKER"

  # Skip creation if repository already exists
  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
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