terraform {
  backend "azurerm" {
    resource_group_name  = "rg-CHANGEME-tfstate"
    storage_account_name = "stchangemetfstate"
    container_name       = "tfstate"
    key                  = "staging/westeurope/01-foundation/terraform.tfstate"
    use_azuread_auth     = true
  }
}
