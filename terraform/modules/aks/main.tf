# ---------------------------------------------------------------------------------------------------------------------
# AKS MODULE
# Direct implementation for demo (AVM production pattern requires zones not available in free subscriptions)
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = var.node_size
    vnet_subnet_id = var.node_subnet_id
    # No zones - not available in free subscriptions
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = var.tenant_id
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  # Enable OIDC issuer for workload identity
  oidc_issuer_enabled = true

  # Enable Key Vault secrets provider
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  # Enable workload identity
  workload_identity_enabled = true

  # Container Insights via OMS agent (optional)
  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id != null ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  tags = var.tags
}
