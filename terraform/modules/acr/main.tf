# ---------------------------------------------------------------------------------------------------------------------
# AZURE CONTAINER REGISTRY MODULE
# Simple ACR with AKS pull permissions
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_container_registry" "this" {
  name                = var.registry_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic" # Cost-optimized for demo

  admin_enabled = true # Enable for GitHub Actions push (simpler than service principal)

  tags = var.tags
}

# Grant AKS the ability to pull images from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = var.aks_principal_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.this.id
  skip_service_principal_aad_check = true
}
