# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.vnet.resource_id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = module.vnet.name
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = module.vnet.subnets["aks"].resource_id
}

output "private_endpoints_subnet_id" {
  description = "ID of the private endpoints subnet"
  value       = module.vnet.subnets["private_endpoints"].resource_id
}
