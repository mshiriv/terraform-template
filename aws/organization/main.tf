# Organization: AWS control plane
#
# Manages the organization, OUs, member accounts, SCPs and tag policies.
# Runs in the management account.
#
# Fresh management account: the first apply creates the organization.
# Existing organization: import it before the first plan by adding
#
#   import {
#     to = aws_organizations_organization.this
#     id = "o-xxxxxxxxxx"
#   }
#
# (and import existing accounts the same way, keyed like var.accounts).

resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
  ]

  aws_service_access_principals = [
    "account.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
  ]
}

locals {
  organization_root_id = aws_organizations_organization.this.roots[0].id
}

# --- Organizational Units ---

resource "aws_organizations_organizational_unit" "ous" {
  for_each = var.organizational_units

  name      = title(each.key)
  parent_id = local.organization_root_id
}

# --- Member Accounts ---

resource "aws_organizations_account" "accounts" {
  for_each = var.accounts

  name      = "${var.account_name_prefix}-${each.key}"
  email     = each.value.email
  parent_id = aws_organizations_organizational_unit.ous[each.value.ou].id

  role_name = "OrganizationAccountAccessRole"

  lifecycle {
    # role_name is only read at creation; changing it would force a new account.
    ignore_changes = [role_name]
    # Removing an entry from var.accounts must never close a live account by
    # accident. Delete this guard in the same PR that retires the account.
    prevent_destroy = true
  }
}

# --- Service Control Policies ---
#
# AWS allows 5 SCPs per target (FullAWSAccess counts as one), so the building
# blocks are consolidated into three policies:
#   baseline:     region restriction + deny leave org          -> ALL OUs
#   strict:       deny root, protect security services,
#                 keep S3 public-access blocks                 -> var.strict_scp_ous
#   require-tags: deny create-without-Product-tag              -> var.require_tags_scp_ous

resource "aws_organizations_policy" "baseline" {
  depends_on  = [aws_organizations_organization.this]
  name        = "baseline"
  description = "Region restriction + deny leave org: applied to all OUs"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.root}/../policies/scp/baseline.json")
}

resource "aws_organizations_policy" "strict" {
  depends_on  = [aws_organizations_organization.this]
  name        = "strict"
  description = "Deny root, protect security services, keep S3 public-access blocks"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.root}/../policies/scp/strict.json")
}

# Tag-presence gate. Denies create actions (that support tag-on-create) when the
# request carries no Product tag. Terraform's provider default_tags injects
# Product on create, so Terraform-managed resources pass; manual/console creates
# without it are denied. s3:CreateBucket is intentionally NOT listed: the S3 API
# doesn't accept request tags on create, so an aws:RequestTag Null deny would
# block ALL bucket creation.
resource "aws_organizations_policy" "require_tags" {
  depends_on  = [aws_organizations_organization.this]
  name        = "require-tags"
  description = "Deny create-without-Product-tag for tag-on-create services"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.root}/../policies/scp/require-tags.json")
}

# --- SCP Attachments ---

resource "aws_organizations_policy_attachment" "baseline" {
  for_each = aws_organizations_organizational_unit.ous

  policy_id = aws_organizations_policy.baseline.id
  target_id = each.value.id
}

resource "aws_organizations_policy_attachment" "strict" {
  for_each = var.strict_scp_ous

  policy_id = aws_organizations_policy.strict.id
  target_id = aws_organizations_organizational_unit.ous[each.key].id
}

resource "aws_organizations_policy_attachment" "require_tags" {
  for_each = var.require_tags_scp_ous

  policy_id = aws_organizations_policy.require_tags.id
  target_id = aws_organizations_organizational_unit.ous[each.key].id
}

# --- Tag Policies ---
#
# Governs the tag taxonomy (Product / Tier / Environment, see aws/README.md#tags).
# The tags themselves are applied by each root's provider default_tags; the
# policy pins key casing and allowed values and reports violations in the
# Organizations tag-policy compliance report. It is REPORT-ONLY (no
# `enforced_for`): presence is hard-enforced by the require-tags SCP, and
# `enforced_for` only accepts the resource types AWS lists as
# enforcement-supported (an unsupported entry fails CreatePolicy). Tag policies
# do not count against the 5-SCP-per-target limit.

resource "aws_organizations_policy" "tags" {
  depends_on  = [aws_organizations_organization.this]
  name        = "required-tags"
  description = "Tag taxonomy (Product/Tier/Environment): value and casing rules, report-only"
  type        = "TAG_POLICY"
  content     = file("${path.root}/../policies/tag/required-tags.json")
}

resource "aws_organizations_policy_attachment" "tags" {
  for_each = aws_organizations_organizational_unit.ous

  policy_id = aws_organizations_policy.tags.id
  target_id = each.value.id
}
