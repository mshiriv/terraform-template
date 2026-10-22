# azure / bootstrap

The Azure state backend (resource group, GRS storage account with versioning
and soft delete, `tfstate` container) and the CI identity (Entra app + service
principal with one federated credential per GitHub OIDC subject, Owner on each
workload subscription, Blob Data Contributor on the state account).

Applied **once, by a tenant admin, from a laptop**. It starts on a local
backend because the storage account it creates doesn't exist yet:

1. Fill `terraform.tfvars` (the placeholder GUIDs are rejected).
2. `az login`, then `terraform init && terraform apply`.
3. Swap `backend.tf` to the commented `azurerm` block,
   `terraform init -migrate-state`, delete the local `terraform.tfstate*`.
4. Store the `ci_client_id` / `tenant_id` outputs as the `AZURE_CLIENT_ID` /
   `AZURE_TENANT_ID` secrets (SETUP.md step 10).

Excluded from CI by `scripts/detect-changes.sh`. The storage account accepts
public network traffic because GitHub-hosted runners have no fixed IPs; the
data plane is Entra-only (shared keys disabled). The inline checkov/trivy
skips document each accepted finding.

## Terraform reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 3.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azuread_application.ci](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) | resource |
| [azuread_application_federated_identity_credential.github](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_federated_identity_credential) | resource |
| [azuread_service_principal.ci](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal) | resource |
| [azurerm_resource_group.tfstate](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.ci_owner](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.ci_state_blob](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_storage_account.tfstate](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_container.tfstate](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [azuread_client_config.current](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_state_subscription_id"></a> [state\_subscription\_id](#input\_state\_subscription\_id) | Subscription that hosts the Terraform state storage account. | `string` | n/a | yes |
| <a name="input_workload_subscription_ids"></a> [workload\_subscription\_ids](#input\_workload\_subscription\_ids) | Subscriptions the CI identity manages, keyed by environment (must match the azure/<env>/ directories and the AZURE\_SUBSCRIPTION\_<ENV> secrets). | `map(string)` | n/a | yes |
| <a name="input_default_branch"></a> [default\_branch](#input\_default\_branch) | Default branch: scheduled drift checks and chatops plans present its ref as the OIDC subject. | `string` | `"main"` | no |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | GitHub repository (owner/name) whose Actions OIDC tokens may federate into the CI identity. | `string` | `"YOUR_GITHUB_ORG/YOUR_GITHUB_REPO"` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for the bootstrap (state + identity) resources. | `string` | `"westeurope"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ci_client_id"></a> [ci\_client\_id](#output\_ci\_client\_id) | Application (client) ID of the CI identity. Store it as the AZURE\_CLIENT\_ID repository secret. |
| <a name="output_state_resource_group_name"></a> [state\_resource\_group\_name](#output\_state\_resource\_group\_name) | Resource group holding the state storage account (backend resource\_group\_name). |
| <a name="output_state_storage_account_name"></a> [state\_storage\_account\_name](#output\_state\_storage\_account\_name) | Storage account holding Terraform state (backend storage\_account\_name). |
| <a name="output_tenant_id"></a> [tenant\_id](#output\_tenant\_id) | Entra tenant ID. Store it as the AZURE\_TENANT\_ID repository secret. |
<!-- END_TF_DOCS -->
