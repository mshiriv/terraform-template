# Account hardening: security defaults
#
# Account-level and per-region guardrails, in one root for ergonomics:
#   - S3 Block Public Access (account-wide)
#   - IAM password policy (14+ chars, complexity, rotation, reuse prevention)
#   - per region: EBS default encryption, IMDSv2 required, block public EBS
#     snapshot sharing, block new public AMI sharing
#
# The per-region resources exist once for us-east-1 (default provider: global
# services land there) and once for the primary workload region (aws.primary).
# If your primary region IS us-east-1, delete the aws.primary copies.

# -----------------------------------------------------------------------------
# Account level (region-agnostic)
# -----------------------------------------------------------------------------

resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  require_uppercase_characters   = true
  require_lowercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  max_password_age               = 90
  password_reuse_prevention      = 24
  allow_users_to_change_password = true
}

# -----------------------------------------------------------------------------
# us-east-1
# -----------------------------------------------------------------------------

resource "aws_ebs_encryption_by_default" "us_east_1" {
  enabled = true
}

resource "aws_ec2_instance_metadata_defaults" "us_east_1" {
  http_tokens                 = "required"
  http_put_response_hop_limit = 2
}

resource "aws_ebs_snapshot_block_public_access" "us_east_1" {
  state = "block-all-sharing"
}

resource "aws_ec2_image_block_public_access" "us_east_1" {
  state = "block-new-sharing"
}

# -----------------------------------------------------------------------------
# Primary workload region
# -----------------------------------------------------------------------------

resource "aws_ebs_encryption_by_default" "primary" {
  provider = aws.primary
  enabled  = true
}

resource "aws_ec2_instance_metadata_defaults" "primary" {
  provider                    = aws.primary
  http_tokens                 = "required"
  http_put_response_hop_limit = 2
}

resource "aws_ebs_snapshot_block_public_access" "primary" {
  provider = aws.primary
  state    = "block-all-sharing"
}

resource "aws_ec2_image_block_public_access" "primary" {
  provider = aws.primary
  state    = "block-new-sharing"
}
