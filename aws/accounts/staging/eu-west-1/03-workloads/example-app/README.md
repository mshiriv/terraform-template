# staging / eu-west-1 / 03-workloads / example-app

A complete example product: ECR repository (`example-app/api`, immutable
tags, KMS, scan on push, keep-30 lifecycle), versioned KMS-encrypted data
bucket, a Secrets Manager secret seeded `{}` (value set out-of-band), a log
group, and the least-privilege ECS task role tying them together. Reads the
foundation (KMS keys) and platform (cluster name) via remote state.

Copy this directory to onboard a product, and add the product name to the
`Product` values in `aws/policies/tag/required-tags.json`. Delete it once
your first real product is live.

## Terraform reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_app_config_secret"></a> [app\_config\_secret](#module\_app\_config\_secret) | terraform-aws-modules/secrets-manager/aws | ~> 2.0 |
| <a name="module_data_bucket"></a> [data\_bucket](#module\_data\_bucket) | terraform-aws-modules/s3-bucket/aws | ~> 5.0 |
| <a name="module_ecr_api"></a> [ecr\_api](#module\_ecr\_api) | terraform-aws-modules/ecr/aws | ~> 3.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.api_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.api_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.api_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.api_task_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [terraform_remote_state.foundation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |
| [terraform_remote_state.platform](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment (account short name). | `string` | `"staging"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retention for the application log group, in days. | `number` | `365` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_app_config_secret_arn"></a> [app\_config\_secret\_arn](#output\_app\_config\_secret\_arn) | ARN of the app config secret (set its value out-of-band). |
| <a name="output_data_bucket_name"></a> [data\_bucket\_name](#output\_data\_bucket\_name) | Application data bucket. |
| <a name="output_ecr_repository_url"></a> [ecr\_repository\_url](#output\_ecr\_repository\_url) | Push the api image here. |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | Log group for the api containers (awslogs driver target). |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | IAM role for the api task definition's taskRoleArn. |
<!-- END_TF_DOCS -->
