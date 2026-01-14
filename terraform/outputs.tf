# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

# Resource Group
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

# Networking
output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.networking.vnet_id
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = module.networking.aks_subnet_id
}

# AKS
output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = module.aks.cluster_id
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity"
  value       = module.aks.oidc_issuer_url
}

# Key Vault
output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = module.keyvault.key_vault_name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = module.keyvault.key_vault_uri
}

# Storage
output "storage_account_name" {
  description = "Name of the storage account"
  value       = module.storage.storage_account_name
}

output "storage_blob_endpoint" {
  description = "Primary blob endpoint"
  value       = module.storage.primary_blob_endpoint
  sensitive   = true
}

# Monitoring
output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = module.monitoring.workspace_id
}

# Container Registry
output "acr_login_server" {
  description = "ACR login server URL"
  value       = module.acr.login_server
}

output "acr_admin_username" {
  description = "ACR admin username"
  value       = module.acr.admin_username
}

output "acr_admin_password" {
  description = "ACR admin password"
  value       = module.acr.admin_password
  sensitive   = true
}
