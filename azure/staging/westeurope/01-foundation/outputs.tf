output "resource_group_name" {
  description = "Network resource group name."
  value       = azurerm_resource_group.network.name
}

output "vnet_id" {
  description = "VNet ID."
  value       = azurerm_virtual_network.this.id
}

output "subnet_ids" {
  description = "Subnet ID per subnet key (app, data)."
  value       = { for k, s in azurerm_subnet.subnets : k => s.id }
}
