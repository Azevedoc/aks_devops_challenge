# ---------------------------------------------------------------------------------------------------------------------
# STORAGE MODULE
# Thin wrapper around Azure Verified Module for Storage Account
# Provides blob storage for worker results with private endpoint
# ---------------------------------------------------------------------------------------------------------------------

module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "~> 0.6"

  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier             = var.account_tier
  account_replication_type = var.replication_type
  account_kind             = "StorageV2"

  # Secure defaults - allow public access for demo (disable for production)
  public_network_access_enabled     = var.enable_private_endpoint ? false : true
  shared_access_key_enabled         = true
  infrastructure_encryption_enabled = true

  # Blob containers
  containers = {
    results = {
      name                  = var.results_container_name
      container_access_type = "private"
    }
  }

  # Private endpoint for secure access from VNet (disabled for demo)
  private_endpoints = var.enable_private_endpoint ? {
    blob = {
      name                          = "${var.storage_account_name}-blob-pe"
      subnet_resource_id            = var.private_endpoint_subnet_id
      subresource_name              = "blob"
      private_dns_zone_resource_ids = var.private_dns_zone_ids
    }
  } : {}

  # Network rules - allow public for demo
  network_rules = var.enable_private_endpoint ? {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  } : null

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# RBAC ROLE ASSIGNMENT FOR AKS WORKLOAD
# Allows AKS workload identity to write blobs
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_role_assignment" "aks_blob_contributor" {
  count                = var.enable_rbac_assignment ? 1 : 0
  scope                = module.storage_account.resource_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.aks_principal_id
}
