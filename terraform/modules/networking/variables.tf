# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "resource_group_id" {
  description = "ID of the resource group"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group (for NSG)"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES WITH DEFAULTS
# ---------------------------------------------------------------------------------------------------------------------

variable "address_space" {
  description = "VNet address space"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "CIDR for AKS subnet (nodes and pods with Azure CNI)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_endpoints_subnet_cidr" {
  description = "CIDR for private endpoints subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
