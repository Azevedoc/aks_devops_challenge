# ---------------------------------------------------------------------------------------------------------------------
# KEY VAULT MODULE
# Thin wrapper around Azure Verified Module for Key Vault
# Provides secrets storage with private endpoint and RBAC
# ---------------------------------------------------------------------------------------------------------------------

module "key_vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "~> 0.10"

  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = var.tenant_id

  # Use RBAC for access control (recommended over legacy access policies)
  legacy_access_policies_enabled = false

  # Soft delete and purge protection for production safety
  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  # Network configuration - allow public access for demo (disable for production)
  public_network_access_enabled = var.enable_private_endpoint ? false : true
  network_acls = var.enable_private_endpoint ? {
    default_action = "Deny"
    bypass         = "AzureServices"
  } : null

  # Private endpoint for secure access from VNet (disabled for demo)
  private_endpoints = var.enable_private_endpoint ? {
    primary = {
      name                          = "${var.key_vault_name}-pe"
      subnet_resource_id            = var.private_endpoint_subnet_id
      private_dns_zone_resource_ids = var.private_dns_zone_ids
    }
  } : {}

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# RBAC ROLE ASSIGNMENT FOR AKS
# Allows AKS workload identity to read secrets
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_role_assignment" "aks_secrets_user" {
  count                = var.enable_rbac_assignment ? 1 : 0
  scope                = module.key_vault.resource_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.aks_principal_id
}
