# Bootstrap: member-account Terraform state buckets
#
# One S3 state bucket + one dedicated KMS key per member account, so each
# account's state (which holds ARNs, IPs and sometimes secrets) stays inside
# that account. The management account's bucket is created by
# scripts/bootstrap.sh (Step 0) because this root's own state lives in it.
# Runs AFTER aws/organization has created the member accounts.
#
# To add an account:
#   1. Add it to aws/organization/terraform.tfvars and apply that root.
#   2. Add a provider alias in providers.tf.
#   3. Copy one kms + bucket module pair below and point it at the new alias.
#   4. Re-run scripts/bootstrap.sh.

locals {
  state_bucket_prefix = "CHANGEME-tfstate"

  state_lifecycle_rules = [
    {
      id      = "expire-noncurrent-versions"
      enabled = true
      filter  = {}

      noncurrent_version_expiration = {
        noncurrent_days = var.noncurrent_version_retention_days
      }

      abort_incomplete_multipart_upload_days = 7
    },
  ]
}

# -----------------------------------------------------------------------------
# production
# -----------------------------------------------------------------------------

module "state_kms_production" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 4.0"

  providers = {
    aws = aws.production
  }

  description             = "Terraform state encryption (production)"
  aliases                 = ["terraform-state"]
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

module "state_bucket_production" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.production
  }

  bucket = "${local.state_bucket_prefix}-production"

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      bucket_key_enabled = true
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = module.state_kms_production.key_arn
      }
    }
  }

  control_object_ownership              = true
  object_ownership                      = "BucketOwnerEnforced"
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  lifecycle_rule = local.state_lifecycle_rules
}

# -----------------------------------------------------------------------------
# staging
# -----------------------------------------------------------------------------

module "state_kms_staging" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 4.0"

  providers = {
    aws = aws.staging
  }

  description             = "Terraform state encryption (staging)"
  aliases                 = ["terraform-state"]
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

module "state_bucket_staging" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.staging
  }

  bucket = "${local.state_bucket_prefix}-staging"

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      bucket_key_enabled = true
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = module.state_kms_staging.key_arn
      }
    }
  }

  control_object_ownership              = true
  object_ownership                      = "BucketOwnerEnforced"
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  lifecycle_rule = local.state_lifecycle_rules
}

# -----------------------------------------------------------------------------
# sandbox
# -----------------------------------------------------------------------------

module "state_kms_sandbox" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 4.0"

  providers = {
    aws = aws.sandbox
  }

  description             = "Terraform state encryption (sandbox)"
  aliases                 = ["terraform-state"]
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

module "state_bucket_sandbox" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.sandbox
  }

  bucket = "${local.state_bucket_prefix}-sandbox"

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      bucket_key_enabled = true
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = module.state_kms_sandbox.key_arn
      }
    }
  }

  control_object_ownership              = true
  object_ownership                      = "BucketOwnerEnforced"
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  lifecycle_rule = local.state_lifecycle_rules
}
