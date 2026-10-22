# Bootstrap: Azure state backend
#
# Creates the resource group + storage account + blob container holding
# Terraform state for every azure/ root. Applied OUT-OF-BAND by a tenant admin,
# once, against a local backend; state is then migrated into the storage
# account it creates (see backend.tf). Excluded from CI by
# scripts/detect-changes.sh.

locals {
  # Azure has no provider-level default_tags; every resource sets these.
  tags = {
    ManagedBy   = "terraform"
    Repository  = var.github_repository
    Environment = "management"
    Product     = "shared"
    Tier        = "bootstrap"
  }
}

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-CHANGEME-tfstate"
  location = var.location
  tags     = local.tags
}

# Entra-auth gated (shared keys disabled) but reachable from GitHub-hosted
# runners, whose IPs are dynamic, so the network default action stays Allow.
#trivy:ignore:AVD-AZU-0012
resource "azurerm_storage_account" "tfstate" {
  #checkov:skip=CKV_AZURE_59:Public network access is required for GitHub-hosted CI runners; data plane is Entra-auth only (shared keys disabled)
  #checkov:skip=CKV2_AZURE_33:A private endpoint is unreachable from GitHub-hosted CI runners
  #checkov:skip=CKV2_AZURE_1:Platform-managed encryption; a customer-managed key is a hardening follow-up
  #checkov:skip=CKV_AZURE_33:State-only account uses no Queue service; nothing to log
  #checkov:skip=CKV2_AZURE_41:SAS expiration is moot; shared-key / SAS access is disabled

  name                              = "stchangemetfstate"
  resource_group_name               = azurerm_resource_group.tfstate.name
  location                          = azurerm_resource_group.tfstate.location
  account_tier                      = "Standard"
  account_kind                      = "StorageV2"
  account_replication_type          = "GRS"
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  shared_access_key_enabled         = false
  allow_nested_items_to_be_public   = false
  public_network_access             = "Enabled"
  infrastructure_encryption_enabled = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 90
    }

    container_delete_retention_policy {
      days = 90
    }
  }

  tags = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "tfstate" {
  #checkov:skip=CKV2_AZURE_21:Blob read logging is noise on a state-only, versioned, Entra-gated container

  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}
