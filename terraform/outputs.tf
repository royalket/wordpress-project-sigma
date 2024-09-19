output "gke_cluster_name" {
  value = google_container_cluster.primary.name
}

output "sql_instance_name" {
  value = google_sql_database_instance.wordpress.name
}

output "storage_bucket_name" {
  value = google_storage_bucket.wordpress_uploads.name
}

output "artifact_registry_repo" {
  value = google_artifact_registry_repository.wordpress_repo.name
}