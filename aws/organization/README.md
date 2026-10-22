# Organization: AWS control plane

Managed from the management account. First applied by
`scripts/bootstrap.sh`; afterwards through the normal PR + chatops flow
(apply environment `organization`).

| File | Manages |
|------|---------|
| `main.tf` | Organization (all features, SCP + tag policies enabled), OUs, member accounts, SCPs and their attachments, tag policy |
| `sso.tf` | IAM Identity Center groups, permission sets, account assignments (opt-in: `enable_sso`) |
| `budgets.tf` | Monthly cost budget per member account with 50/80/100% actual and 80% forecast alerts |
| `terraform.tfvars` | Accounts (emails, OU), budgets, alert emails, SSO toggle. **Non-secret only.** |

## Service control policies

AWS allows five SCPs per target (`FullAWSAccess` is one), so the building
blocks are consolidated in [`../policies/scp/`](../policies/scp/):

| Policy | Attached to | Effect |
|--------|-------------|--------|
| `baseline` | all OUs | Deny every region except the primary region and `us-east-1` (global services exempt); deny leaving the organization |
| `strict` | `strict_scp_ous` (Workloads) | Deny the root user; protect CloudTrail, Config, GuardDuty, Security Hub; keep S3 public access blocks |
| `require-tags` | `require_tags_scp_ous` (Sandbox first) | Deny creating EC2/EBS, RDS, ECR and ElastiCache resources without a `Product` tag |

Roll SCP changes out to the Sandbox OU first: an SCP mistake can lock
everyone, including CI, out of an account. The management account is never
affected by SCPs.

## Accounts

- Accounts are `prevent_destroy`: removing one from `var.accounts` fails the
  plan instead of closing it. Retire an account deliberately (remove the guard
  in the same PR, and know that closed accounts enter a 90-day suspension).
- `role_name` (`OrganizationAccountAccessRole`) is only read at creation;
  it's ignored afterwards so it can't force a replacement.
- Existing organization or accounts: import them (see the header of
  `main.tf`).

## SSO (IAM Identity Center)

1. Enable Identity Center in the console (Organization instance); the API
   can't.
2. Set `enable_sso = true`, apply.
3. Add people to `platform-admins` (AdministratorAccess, 4 h sessions) and
   `developers` (ReadOnlyAccess, 8 h) in the console, or provision from your
   IdP over SCIM. If the IdP owns the groups, switch the group resources to
   data sources (see `sso.tf`).

Users are deliberately not managed in this repo: no names or emails in git.

## Not included (good next steps)

Organization CloudTrail (S3 + KMS, log file validation), delegated
administrators for GuardDuty / Security Hub / Config in a security account,
AWS Config aggregator, IPAM. Each fits as a new file here or an account-level
root.

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
| [aws_budgets_budget.monthly](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget) | resource |
| [aws_identitystore_group.sso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/identitystore_group) | resource |
| [aws_organizations_account.accounts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_account) | resource |
| [aws_organizations_organization.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organization) | resource |
| [aws_organizations_organizational_unit.ous](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_policy.baseline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) | resource |
| [aws_organizations_policy.require_tags](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) | resource |
| [aws_organizations_policy.strict](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) | resource |
| [aws_organizations_policy.tags](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) | resource |
| [aws_organizations_policy_attachment.baseline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment) | resource |
| [aws_organizations_policy_attachment.require_tags](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment) | resource |
| [aws_organizations_policy_attachment.strict](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment) | resource |
| [aws_organizations_policy_attachment.tags](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment) | resource |
| [aws_ssoadmin_account_assignment.sso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_account_assignment) | resource |
| [aws_ssoadmin_managed_policy_attachment.sso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_managed_policy_attachment) | resource |
| [aws_ssoadmin_permission_set.sso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_permission_set) | resource |
| [aws_ssoadmin_instances.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssoadmin_instances) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_accounts"></a> [accounts](#input\_accounts) | Member accounts to create. Key = account short name (it must match the aws/accounts/<name> directory); ou must be one of organizational\_units. | <pre>map(object({<br/>    email = string<br/>    ou    = string<br/>  }))</pre> | n/a | yes |
| <a name="input_account_name_prefix"></a> [account\_name\_prefix](#input\_account\_name\_prefix) | Prefix for member account names: an account keyed `staging` is named `<prefix>-staging`. | `string` | `"CHANGEME"` | no |
| <a name="input_budget_alert_emails"></a> [budget\_alert\_emails](#input\_budget\_alert\_emails) | Addresses notified at 50/80/100% of actual and 80% of forecasted spend. | `list(string)` | `[]` | no |
| <a name="input_enable_sso"></a> [enable\_sso](#input\_enable\_sso) | Manage IAM Identity Center groups, permission sets and account assignments (sso.tf). Enable Identity Center in the console first; it cannot be turned on through the API. | `bool` | `false` | no |
| <a name="input_monthly_budgets_usd"></a> [monthly\_budgets\_usd](#input\_monthly\_budgets\_usd) | Monthly cost budget per member account, in USD. Key = account short name from var.accounts; accounts not listed get no budget. | `map(number)` | `{}` | no |
| <a name="input_organizational_units"></a> [organizational\_units](#input\_organizational\_units) | Organizational units to create directly under the organization root. | `set(string)` | <pre>[<br/>  "workloads",<br/>  "sandbox"<br/>]</pre> | no |
| <a name="input_require_tags_scp_ous"></a> [require\_tags\_scp\_ous](#input\_require\_tags\_scp\_ous) | OUs that get the require-tags SCP (deny create without a Product tag). Roll it out to sandbox first, then add workloads once validated. | `set(string)` | <pre>[<br/>  "sandbox"<br/>]</pre> | no |
| <a name="input_strict_scp_ous"></a> [strict\_scp\_ous](#input\_strict\_scp\_ous) | OUs that get the strict SCP (deny root user, protect security services, keep S3 public-access blocks). | `set(string)` | <pre>[<br/>  "workloads"<br/>]</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_account_ids"></a> [account\_ids](#output\_account\_ids) | Map of member account short name to account ID. Feed it to aws/bootstrap (scripts/bootstrap.sh does). |
| <a name="output_organization_id"></a> [organization\_id](#output\_organization\_id) | ID of the AWS Organization (o-...). |
| <a name="output_ou_ids"></a> [ou\_ids](#output\_ou\_ids) | Map of OU name to OU ID. |
| <a name="output_sso_permission_set_arns"></a> [sso\_permission\_set\_arns](#output\_sso\_permission\_set\_arns) | Identity Center permission set ARNs by name (empty when enable\_sso = false). |
<!-- END_TF_DOCS -->
