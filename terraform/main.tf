terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = "wordpress-project-sigma"
  region  = "us-central1"
  zone    = "us-central1-a"
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name               = "wordpress-cluster"
  location           = "us-central1-a"
  initial_node_count = 1

  node_config {
    machine_type = "e2-small"
    disk_size_gb = 10
  }
}

# Cloud SQL instance
resource "google_sql_database_instance" "wordpress" {
  name             = "wordpress-db-instance"
  database_version = "MYSQL_5_7"
  region           = "us-central1"

  settings {
    tier      = "db-f1-micro"
    disk_size = 10
  }
}

# Cloud SQL database
resource "google_sql_database" "wordpress_db" {
  name     = "wordpress"
  instance = google_sql_database_instance.wordpress.name
}

# Data sources for Secret Manager secrets
data "google_secret_manager_secret_version" "db_username" {
  secret = "wordpress-db-username"
}

data "google_secret_manager_secret_version" "db_password" {
  secret = "wordpress-db-password"
}

# Cloud SQL user
resource "google_sql_user" "wordpress_user" {
  name     = data.google_secret_manager_secret_version.db_username.secret_data
  instance = google_sql_database_instance.wordpress.name
  password = data.google_secret_manager_secret_version.db_password.secret_data
}

# GCS Bucket
resource "google_storage_bucket" "wordpress_content" {
  name     = "wordpress-content-bucket-sigma"
  location = "US"
}

# Service Account for Cloud SQL proxy
resource "google_service_account" "cloudsql_proxy" {
  account_id   = "cloudsql-proxy"
  display_name = "Cloud SQL Proxy Service Account"
}

# IAM binding for Cloud SQL client role
resource "google_project_iam_member" "cloudsql_client" {
  project = "wordpress-project-sigma"
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloudsql_proxy.email}"
}

# Service Account key for Cloud SQL proxy
resource "google_service_account_key" "cloudsql_proxy_key" {
  service_account_id = google_service_account.cloudsql_proxy.name
}

# Kubernetes Secret for Cloud SQL proxy credentials
resource "kubernetes_secret" "cloudsql_proxy_credentials" {
  metadata {
    name = "cloudsql-instance-credentials"
  }

  data = {
    "key.json" = base64decode(google_service_account_key.cloudsql_proxy_key.private_key)
  }
}

# Kubernetes Secret for database credentials
resource "kubernetes_secret" "cloudsql_db_credentials" {
  metadata {
    name = "cloudsql-db-credentials"
  }

  data = {
    username = data.google_secret_manager_secret_version.db_username.secret_data
    password = data.google_secret_manager_secret_version.db_password.secret_data
  }
}

# IAM binding for Secret Manager secret accessor role
resource "google_secret_manager_secret_iam_member" "secret_accessor_username" {
  secret_id = "wordpress-db-username"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloudsql_proxy.email}"
}

resource "google_secret_manager_secret_iam_member" "secret_accessor_password" {
  secret_id = "wordpress-db-password"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloudsql_proxy.email}"
}

output "gke_cluster_name" {
  value = google_container_cluster.primary.name
}

output "cloudsql_instance_connection_name" {
  value = google_sql_database_instance.wordpress.connection_name
}

output "gcs_bucket_name" {
  value = google_storage_bucket.wordpress_content.name
}