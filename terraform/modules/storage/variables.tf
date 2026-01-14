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

variable "storage_account_name" {
  description = "Name of the storage account (must be globally unique, lowercase, no hyphens)"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES WITH DEFAULTS
# ---------------------------------------------------------------------------------------------------------------------

variable "account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "replication_type" {
  description = "Storage replication type"
  type        = string
  default     = "LRS" # Locally-redundant (cheaper for demo)
}

variable "results_container_name" {
  description = "Name of the blob container for results"
  type        = string
  default     = "results"
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
  description = "Principal ID of AKS workload identity for RBAC assignment"
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
