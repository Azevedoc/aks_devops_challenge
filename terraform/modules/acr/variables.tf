variable "registry_name" {
  description = "Name of the container registry (must be globally unique, alphanumeric only)"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "aks_principal_id" {
  description = "Principal ID of the AKS kubelet identity for ACR pull access"
  type        = string
}

variable "enable_private_endpoint" {
  description = "Enable private endpoint for ACR (requires Premium SKU, ~$1.50/day vs ~$0.17/day for Basic)"
  type        = bool
  default     = false
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for the private endpoint (required if enable_private_endpoint is true)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
