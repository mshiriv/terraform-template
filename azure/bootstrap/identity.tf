# CI identity: GitHub Actions OIDC (workload identity federation, no secret)
#
# An Entra app registration + service principal that GitHub Actions federates
# into to plan/apply the azure/ roots, plus its RBAC. The first apply needs a
# tenant admin (Graph write + Owner on the subscriptions).

data "azuread_client_config" "current" {}

resource "azuread_application" "ci" {
  display_name     = "github-actions-terraform"
  sign_in_audience = "AzureADMyOrg"
  owners           = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "ci" {
  client_id = azuread_application.ci.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# One federated credential per distinct GitHub OIDC subject (Entra does not
# accept wildcards). PR plans present `pull_request`; drift checks and chatops
# plans run on the default branch; chatops applies run under the per-env
# GitHub Environment. A missing subject fails login with AADSTS700213.
locals {
  github_oidc_subjects = merge(
    {
      pull_request   = "repo:${var.github_repository}:pull_request"
      default_branch = "repo:${var.github_repository}:ref:refs/heads/${var.default_branch}"
    },
    { for env in keys(var.workload_subscription_ids) : "environment-${env}" => "repo:${var.github_repository}:environment:${env}" },
  )
}

resource "azuread_application_federated_identity_credential" "github" {
  #checkov:skip=CKV_AZURE_249:False positive: checkov cannot resolve each.value from the merge()-built map. Every subject is an exact repo-qualified claim (see local.github_oidc_subjects), with no wildcards.
  for_each = local.github_oidc_subjects

  application_id = azuread_application.ci.id
  display_name   = "github-${each.key}"
  description    = "GitHub Actions OIDC: ${each.value}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = each.value
}

# Owner on each workload subscription: roots create role assignments (e.g. Key
# Vault RBAC), which Contributor cannot. Narrow to Contributor + Role Based
# Access Control Administrator (with conditions) once your roots allow it.
resource "azurerm_role_assignment" "ci_owner" {
  for_each = var.workload_subscription_ids

  scope                = "/subscriptions/${each.value}"
  role_definition_name = "Owner"
  principal_id         = azuread_service_principal.ci.object_id
}

# Data-plane access to the state blobs (the backend uses Entra auth).
resource "azurerm_role_assignment" "ci_state_blob" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.ci.object_id
}
