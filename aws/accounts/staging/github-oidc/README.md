# staging / github-oidc

The GitHub Actions OIDC provider and the CI role for the **staging** account.
The role trusts only this repository's PR, default-branch and
GitHub-Environment contexts (`github_environments` in `terraform.tfvars`);
see [docs/ci-cd.md](../../../../docs/ci-cd.md#cloud-authentication).

- First apply: by `scripts/bootstrap.sh` (SETUP.md step 5), because CI can't
  assume a role that doesn't exist yet. CI manages it afterwards.
- Its `github_actions_role_arn` output goes in the `AWS_ROLE_STAGING` secret.
- An `AssumeRoleWithWebIdentity` denial almost always means the job's OIDC
  subject isn't in the `github_oidc_subjects` output.

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
| [aws_iam_openid_connect_provider.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.github_actions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.github_actions_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.github_actions_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Account short name this root is applied to (management, production, staging or sandbox). | `string` | n/a | yes |
| <a name="input_github_environments"></a> [github\_environments](#input\_github\_environments) | GitHub Environments whose chatops apply jobs may assume the CI role in this account (see the environment mapping in terraform-chatops.yml). | `list(string)` | n/a | yes |
| <a name="input_ci_role_name"></a> [ci\_role\_name](#input\_ci\_role\_name) | Name of the IAM role GitHub Actions assumes. Its ARN goes in the AWS\_ROLE\_<ENV> repository secret. | `string` | `"github-actions-terraform"` | no |
| <a name="input_default_branch"></a> [default\_branch](#input\_default\_branch) | Default branch of the repository. Scheduled drift checks and chatops plans run on it. | `string` | `"main"` | no |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | GitHub repository (owner/name) whose Actions workflows may assume the CI role. | `string` | `"YOUR_GITHUB_ORG/YOUR_GITHUB_REPO"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_github_actions_role_arn"></a> [github\_actions\_role\_arn](#output\_github\_actions\_role\_arn) | IAM role ARN for GitHub Actions. Store it as the AWS\_ROLE\_<ENV> repository secret. |
| <a name="output_github_oidc_subjects"></a> [github\_oidc\_subjects](#output\_github\_oidc\_subjects) | OIDC subject claims trusted by the CI role (useful when debugging an AssumeRoleWithWebIdentity denial). |
<!-- END_TF_DOCS -->
