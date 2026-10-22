# staging / eu-west-1 / 02-platform

Runtime shared by every staging workload. Example contents: an ECS Fargate
cluster (no cost while idle) with ECS exec sessions encrypted and logged.
Replace or extend with your shared platform (EKS, databases, caches, agents).

## Terraform reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.ecs_exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [terraform_remote_state.foundation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment (account short name). Also the ECS cluster name. | `string` | `"staging"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retention for platform log groups, in days. | `number` | `365` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ecs_cluster_arn"></a> [ecs\_cluster\_arn](#output\_ecs\_cluster\_arn) | Shared ECS cluster ARN. |
| <a name="output_ecs_cluster_name"></a> [ecs\_cluster\_name](#output\_ecs\_cluster\_name) | Shared ECS cluster name. |
| <a name="output_ecs_exec_log_group_name"></a> [ecs\_exec\_log\_group\_name](#output\_ecs\_exec\_log\_group\_name) | Log group auditing ECS exec sessions. |
<!-- END_TF_DOCS -->
