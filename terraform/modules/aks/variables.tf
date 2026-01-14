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

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "node_subnet_id" {
  description = "Subnet ID for AKS nodes"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID for RBAC"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES WITH DEFAULTS
# ---------------------------------------------------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "node_size" {
  description = "VM size for nodes (Standard_B2s is smallest AKS-compatible)"
  type        = string
  default     = "Standard_B2s"
}

variable "pod_cidr" {
  description = "CIDR for pod network (Azure CNI overlay)"
  type        = string
  default     = "172.16.0.0/16"
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services"
  type        = string
  default     = "172.17.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for Kubernetes DNS service"
  type        = string
  default     = "172.17.0.10"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
