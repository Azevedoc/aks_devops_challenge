# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "project" {
  description = "Project name (used in resource naming)"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# NETWORKING VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "CIDR for AKS subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_endpoints_subnet_cidr" {
  description = "CIDR for private endpoints subnet"
  type        = string
  default     = "10.0.2.0/24"
}

# ---------------------------------------------------------------------------------------------------------------------
# AKS VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.33"
}

variable "aks_node_size" {
  description = "VM size for AKS nodes (Standard_B2s is smallest AKS-compatible)"
  type        = string
  default     = "Standard_B2s"
}

# ---------------------------------------------------------------------------------------------------------------------
# ACR VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "acr_enable_private_endpoint" {
  description = "Enable private endpoint for ACR (requires Premium SKU: ~$1.50/day vs ~$0.17/day for Basic)"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------------------------------------------------
# MONITORING VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "log_retention_days" {
  description = "Log Analytics retention in days"
  type        = number
  default     = 30
}
