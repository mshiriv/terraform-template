terraform {
  required_version = ">= 1.14.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}

  # The subscription that hosts the state storage account.
  subscription_id = var.state_subscription_id

  # The state storage account has shared keys disabled, so blob data-plane
  # operations (creating the container) must use Entra ID auth.
  storage_use_azuread = true
}

provider "azuread" {}
