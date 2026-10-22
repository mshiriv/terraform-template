output "organization_id" {
  description = "ID of the AWS Organization (o-...)."
  value       = aws_organizations_organization.this.id
}

output "account_ids" {
  description = "Map of member account short name to account ID. Feed it to aws/bootstrap (scripts/bootstrap.sh does)."
  value       = { for k, v in aws_organizations_account.accounts : k => v.id }
}

output "ou_ids" {
  description = "Map of OU name to OU ID."
  value       = { for k, v in aws_organizations_organizational_unit.ous : k => v.id }
}

output "sso_permission_set_arns" {
  description = "Identity Center permission set ARNs by name (empty when enable_sso = false)."
  value       = { for k, v in aws_ssoadmin_permission_set.sso : k => v.arn }
}
