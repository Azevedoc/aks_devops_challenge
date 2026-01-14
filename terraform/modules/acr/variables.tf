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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
