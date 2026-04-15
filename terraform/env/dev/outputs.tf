output "github_actions_provider_name" {
  description = "Copy this value to the WIF_PROVIDER secret/variable in GitHub"
  value       = module.wif.workload_identity_provider_name
}

output "github_actions_service_account" {
  description = "Copy this value to the SERVICE_ACCOUNT secret/variable in GitHub"
  value       = module.wif.service_account_email
}