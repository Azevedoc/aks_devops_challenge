# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "key_vault_name" {
  description = "Name of the Key Vault (must be globally unique)"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES WITH DEFAULTS
# ---------------------------------------------------------------------------------------------------------------------

variable "soft_delete_retention_days" {
  description = "Number of days to retain soft-deleted vaults"
  type        = number
  default     = 7
}

variable "purge_protection_enabled" {
  description = "Enable purge protection (prevents permanent deletion)"
  type        = bool
  default     = false # Set to true for production
}

variable "enable_private_endpoint" {
  description = "Enable private endpoint (set to false for demo)"
  type        = bool
  default     = false
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoint (null to disable)"
  type        = string
  default     = null
}

variable "private_dns_zone_ids" {
  description = "Private DNS zone IDs for private endpoint"
  type        = list(string)
  default     = []
}

variable "aks_principal_id" {
  description = "Principal ID of AKS managed identity for RBAC assignment"
  type        = string
  default     = null
}

variable "enable_rbac_assignment" {
  description = "Enable RBAC assignment (set to true after AKS is created)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
