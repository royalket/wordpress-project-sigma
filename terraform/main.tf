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
  zone = "us-central1-a"
}

# Create GKE cluster
resource "google_container_cluster" "primary" {
  name = "wordpress-cluster"
  location = "us-central1-a"
  initial_node_count = 1

  node_config {
    machine_type = "e2-small"
    disk_size_gb = 10
    
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }
}

# Create Cloud SQL instance
resource "google_sql_database_instance" "wordpress" {
  name = "wordpress-mysql"
  database_version = "MYSQL_5_7"
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
  password = "CHANGE_ME_BEFORE_APPLYING" # You should change this and use Secret Manager in production
}

# Create Artifact Registry repository
resource "google_artifact_registry_repository" "wordpress" {
  location = "us-central1"
  repository_id = "wordpress-repo"
  format = "DOCKER"
}

# Output values
output "gke_cluster_name" {
  value = google_container_cluster.primary.name
}

output "cloudsql_instance_name" {
  value = google_sql_database_instance.wordpress.name
}

output "artifact_registry_repo" {
  value = google_artifact_registry_repository.wordpress.name
}
