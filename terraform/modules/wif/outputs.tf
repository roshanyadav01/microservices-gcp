output "workload_identity_provider_name" {
  description = "The full identifier of the Workload Identity Provider"
  value       = google_iam_workload_identity_pool_provider.provider.name
}

output "service_account_email" {
  description = "The email of the service account used by GitHub Actions"
  value       = google_service_account.sa.email
}