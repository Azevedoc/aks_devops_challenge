# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "storage_account_id" {
  description = "ID of the storage account"
  value       = module.storage_account.resource_id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = module.storage_account.name
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint URL"
  value       = module.storage_account.resource.primary_blob_endpoint
}

output "results_container_name" {
  description = "Name of the results blob container"
  value       = var.results_container_name
}
