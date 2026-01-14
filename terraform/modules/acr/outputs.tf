output "registry_id" {
  description = "ID of the container registry"
  value       = azurerm_container_registry.this.id
}

output "login_server" {
  description = "Login server URL for the registry"
  value       = azurerm_container_registry.this.login_server
}

output "admin_username" {
  description = "Admin username for the registry"
  value       = azurerm_container_registry.this.admin_username
}

output "admin_password" {
  description = "Admin password for the registry"
  value       = azurerm_container_registry.this.admin_password
  sensitive   = true
}
