# Step 1: start with a local backend (the storage account doesn't exist yet).
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

# Step 2: after the first apply, replace the block above with this one and run
# `terraform init -migrate-state`, then delete the local terraform.tfstate*.
#
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "rg-CHANGEME-tfstate"
#     storage_account_name = "stchangemetfstate"
#     container_name       = "tfstate"
#     key                  = "bootstrap/terraform.tfstate"
#     use_azuread_auth     = true
#   }
# }
