# ---------------------------------------------------------------------------------------------------------------------
# AZURE CONTAINER REGISTRY MODULE
# ACR with AKS pull permissions and optional private endpoint
# Note: Private endpoint requires Premium SKU (~$1.50/day vs ~$0.17/day for Basic)
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_container_registry" "this" {
  name                = var.registry_name
  resource_group_name = var.resource_group_name
  location            = var.location

  # Premium required for private endpoints, Basic for cost-optimized demo
  sku = var.enable_private_endpoint ? "Premium" : "Basic"

  admin_enabled = true # Enable for GitHub Actions push (simpler than service principal)

  # Network restrictions when private endpoint is enabled
  public_network_access_enabled = var.enable_private_endpoint ? false : true

  tags = var.tags
}

# Grant AKS the ability to pull images from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = var.aks_principal_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.this.id
  skip_service_principal_aad_check = true
}

# ---------------------------------------------------------------------------------------------------------------------
# PRIVATE ENDPOINT (optional)
# Creates private endpoint and DNS zone for secure access from VNet
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "acr" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  count                 = var.enable_private_endpoint ? 1 : 0
  name                  = "${var.registry_name}-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr[0].name
  virtual_network_id    = local.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "acr" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "${var.registry_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.registry_name}-connection"
    private_connection_resource_id = azurerm_container_registry.this.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr[0].id]
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# LOCAL VALUES
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Extract VNet ID from subnet ID (format: /subscriptions/.../virtualNetworks/{vnet}/subnets/{subnet})
  vnet_id = var.private_endpoint_subnet_id != null ? join("/", slice(split("/", var.private_endpoint_subnet_id), 0, 9)) : null
}
