# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = module.log_analytics.resource_id
}

output "workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = module.log_analytics.resource.name
}

output "workspace_primary_key" {
  description = "Primary shared key for the Log Analytics workspace"
  value       = module.log_analytics.resource.primary_shared_key
  sensitive   = true
}
