# ---------------------------------------------------------------------------------------------------------------------
# MONITORING MODULE
# Thin wrapper around Azure Verified Module for Log Analytics Workspace
# Provides centralized logging for AKS Container Insights
# ---------------------------------------------------------------------------------------------------------------------

module "log_analytics" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "~> 0.4"

  name                = var.workspace_name
  resource_group_name = var.resource_group_name
  location            = var.location

  log_analytics_workspace_retention_in_days = var.retention_days
  log_analytics_workspace_sku               = var.sku

  tags = var.tags
}
