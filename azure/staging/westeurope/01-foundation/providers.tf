terraform {
  required_version = ">= 1.14.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

# No subscription_id here: CI exports ARM_SUBSCRIPTION_ID for the subscription
# mapped to this directory (.github/actions/resolve-azure-subscription), so no
# subscription IDs live in code. Locally: export ARM_SUBSCRIPTION_ID=<id>.
provider "azurerm" {
  features {}
}
