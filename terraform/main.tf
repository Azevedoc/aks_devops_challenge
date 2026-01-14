# ---------------------------------------------------------------------------------------------------------------------
# AKS PLATFORM - ROOT MODULE
# Orchestrates all infrastructure components using thin wrappers around Azure Verified Modules
# ---------------------------------------------------------------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# RESOURCE GROUP
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# NETWORKING
# VNet with AKS subnet and private endpoints subnet
# ---------------------------------------------------------------------------------------------------------------------

module "networking" {
  source = "./modules/networking"

  resource_group_id   = azurerm_resource_group.main.id
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  name_prefix         = local.name_prefix
  vnet_name           = "${local.name_prefix}-vnet"

  address_space                 = var.vnet_address_space
  aks_subnet_cidr               = var.aks_subnet_cidr
  private_endpoints_subnet_cidr = var.private_endpoints_subnet_cidr

  tags = local.common_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# MONITORING
# Log Analytics workspace for Container Insights
# ---------------------------------------------------------------------------------------------------------------------

module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  workspace_name      = "${local.name_prefix}-law"

  retention_days = var.log_retention_days

  tags = local.common_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# AKS CLUSTER
# Production-ready Kubernetes cluster with Azure CNI and monitoring
# ---------------------------------------------------------------------------------------------------------------------

module "aks" {
  source = "./modules/aks"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  cluster_name        = "${local.name_prefix}-aks"
  node_subnet_id      = module.networking.aks_subnet_id
  tenant_id           = data.azurerm_client_config.current.tenant_id

  kubernetes_version = var.kubernetes_version
  node_size          = var.aks_node_size

  tags = local.common_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# KEY VAULT
# Secrets storage with private endpoint
# ---------------------------------------------------------------------------------------------------------------------

module "keyvault" {
  source = "./modules/keyvault"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  key_vault_name             = "${var.project}${var.environment}kv" # No hyphens allowed
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  private_endpoint_subnet_id = module.networking.private_endpoints_subnet_id
  aks_principal_id           = module.aks.kubelet_identity_object_id

  tags = local.common_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# STORAGE
# Blob storage for worker results with private endpoint
# ---------------------------------------------------------------------------------------------------------------------

module "storage" {
  source = "./modules/storage"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  storage_account_name       = "${var.project}${var.environment}sa" # No hyphens allowed
  private_endpoint_subnet_id = module.networking.private_endpoints_subnet_id
  aks_principal_id           = module.aks.kubelet_identity_object_id

  tags = local.common_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# DATA SOURCES
# ---------------------------------------------------------------------------------------------------------------------

data "azurerm_client_config" "current" {}
