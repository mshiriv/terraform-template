# azure / staging / westeurope / 01-foundation

Example Azure foundation: network resource group, VNet, `app` and `data`
subnets (no default outbound access), and one NSG per subnet. No subscription
ID in code: CI exports `ARM_SUBSCRIPTION_ID` for `azure/staging/**`
(locally: `export ARM_SUBSCRIPTION_ID=<id>`).

## Terraform reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_network_security_group.subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_resource_group.network](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_subnet.subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_network_security_group_association.subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (matches the azure/<env>/ directory). | `string` | `"staging"` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for this root's resources. | `string` | `"westeurope"` | no |
| <a name="input_vnet_cidr"></a> [vnet\_cidr](#input\_vnet\_cidr) | Address space of the environment VNet. | `string` | `"10.101.0.0/16"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Network resource group name. |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | Subnet ID per subnet key (app, data). |
| <a name="output_vnet_id"></a> [vnet\_id](#output\_vnet\_id) | VNet ID. |
<!-- END_TF_DOCS -->
