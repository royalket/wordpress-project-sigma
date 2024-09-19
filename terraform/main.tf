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

  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "wordpress-node-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name
  node_count = 3

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

# Cloud SQL Instance
resource "google_sql_database_instance" "wordpress" {
  name              = "wordpress-db-instance"
  database_version  = "MYSQL_5_7"
  region            = var.region

  settings {
    tier = "db-f1-micro"
  }
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
