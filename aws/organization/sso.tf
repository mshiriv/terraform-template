# IAM Identity Center (SSO): groups, permission sets, account assignments
#
# Opt-in via var.enable_sso, because Identity Center must first be enabled in
# the console (Organization instance). People are NOT managed here: add users
# to the groups in the Identity Center console or provision them from your IdP
# over SCIM, so no names or emails ever land in this repo.
#
# If your IdP provisions the groups over SCIM, replace the
# aws_identitystore_group resources with `data "aws_identitystore_group"`
# lookups by display name; creating them here would conflict.

data "aws_ssoadmin_instances" "this" {
  count = var.enable_sso ? 1 : 0
}

locals {
  sso_instance_arn      = var.enable_sso ? tolist(data.aws_ssoadmin_instances.this[0].arns)[0] : null
  sso_identity_store_id = var.enable_sso ? tolist(data.aws_ssoadmin_instances.this[0].identity_store_ids)[0] : null

  sso_permission_sets = {
    PlatformAdmin = {
      description        = "Full administrative access for the platform team"
      managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
      session_duration   = "PT4H"
    }
    ReadOnly = {
      description        = "Read-only access to every member account"
      managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
      session_duration   = "PT8H"
    }
  }

  # Group -> permission set it receives on every member account. Extend with
  # per-account grants (e.g. developers -> PowerUser on sandbox) as needed.
  sso_group_grants = {
    platform-admins = "PlatformAdmin"
    developers      = "ReadOnly"
  }

  sso_assignments = var.enable_sso ? {
    for pair in setproduct(keys(local.sso_group_grants), keys(var.accounts)) :
    "${pair[0]}/${pair[1]}" => {
      group          = pair[0]
      account        = pair[1]
      permission_set = local.sso_group_grants[pair[0]]
    }
  } : {}
}

resource "aws_identitystore_group" "sso" {
  for_each = var.enable_sso ? local.sso_group_grants : {}

  identity_store_id = local.sso_identity_store_id
  display_name      = each.key
  description       = "Managed by Terraform (aws/organization/sso.tf)"
}

resource "aws_ssoadmin_permission_set" "sso" {
  for_each = var.enable_sso ? local.sso_permission_sets : {}

  name             = each.key
  description      = each.value.description
  instance_arn     = local.sso_instance_arn
  session_duration = each.value.session_duration
}

resource "aws_ssoadmin_managed_policy_attachment" "sso" {
  for_each = var.enable_sso ? local.sso_permission_sets : {}

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.sso[each.key].arn
  managed_policy_arn = each.value.managed_policy_arn
}

resource "aws_ssoadmin_account_assignment" "sso" {
  for_each = local.sso_assignments

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.sso[each.value.permission_set].arn

  principal_type = "GROUP"
  principal_id   = aws_identitystore_group.sso[each.value.group].group_id

  target_type = "AWS_ACCOUNT"
  target_id   = aws_organizations_account.accounts[each.value.account].id
}
