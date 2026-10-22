output "ci_client_id" {
  description = "Application (client) ID of the CI identity. Store it as the AZURE_CLIENT_ID repository secret."
  value       = azuread_application.ci.client_id
}

output "tenant_id" {
  description = "Entra tenant ID. Store it as the AZURE_TENANT_ID repository secret."
  value       = data.azuread_client_config.current.tenant_id
}

output "state_resource_group_name" {
  description = "Resource group holding the state storage account (backend resource_group_name)."
  value       = azurerm_resource_group.tfstate.name
}

output "state_storage_account_name" {
  description = "Storage account holding Terraform state (backend storage_account_name)."
  value       = azurerm_storage_account.tfstate.name
}
