# Workload: example-app
#
# Everything owned by one product: its image repository, data bucket, secrets,
# log group and the IAM role its containers run as. The ECS service / task
# definition itself is deployed by the app's own pipeline onto the shared
# cluster from 02-platform. Copy this directory to onboard a new product.

locals {
  product = "example-app"
  service = "api"
}

# --- Container images ---------------------------------------------------------

module "ecr_api" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 3.0"

  # Slash-namespaced per product: <product>/<service>.
  repository_name                 = "${local.product}/${local.service}"
  repository_image_tag_mutability = "IMMUTABLE"
  repository_image_scan_on_push   = true
  repository_encryption_type      = "KMS"
  repository_kms_key              = local.kms_key_arns["general"]

  # Keep enough history to roll back several releases. A tight count can expire
  # the image a running task still references, which then fails to reschedule.
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the last 30 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      },
    ]
  })
}

# --- Application data ---------------------------------------------------------

# Application bucket naming: <prefix>-<env>-<product>-<usecase> (S3 names are
# global, so the org prefix stays here). See aws/README.md#naming.
module "data_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.0"

  bucket = "CHANGEME-${var.environment}-${local.product}-data"

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      bucket_key_enabled = true
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = local.kms_key_arns["s3"]
      }
    }
  }

  control_object_ownership              = true
  object_ownership                      = "BucketOwnerEnforced"
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  lifecycle_rule = [
    {
      id      = "expire-noncurrent-versions"
      enabled = true
      filter  = {}

      noncurrent_version_expiration = {
        noncurrent_days = 30
      }

      abort_incomplete_multipart_upload_days = 7
    },
  ]
}

# --- Secrets ------------------------------------------------------------------

# Name per aws/SECRETS.md: <env>/<product>/<runtime>/<consumer>/[<category>/]<leaf>.
# Terraform creates the container and seeds `{}` once; the real value is set
# out-of-band, and ignore_secret_changes keeps it out of every later plan.
module "app_config_secret" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 2.0"

  name        = "${var.environment}/${local.product}/ecs/${local.service}/app/config"
  description = "Runtime configuration for ${local.product}/${local.service}"
  kms_key_id  = local.kms_key_arns["general"]

  secret_string         = jsonencode({})
  ignore_secret_changes = true

  # Staging: no recovery window, so a renamed secret can be recreated at once.
  # Production should keep the 7-30 day default.
  recovery_window_in_days = var.environment == "production" ? 30 : 0
}

# --- Logs ---------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${local.ecs_cluster_name}/${local.product}/${local.service}"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.kms_key_arns["logs"]
}

# --- Runtime identity ---------------------------------------------------------

data "aws_iam_policy_document" "api_task_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    # Confused-deputy guard: only tasks launched in this account.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "api_task" {
  name               = "${local.product}-${local.service}-task"
  description        = "Runtime role for the ${local.product}/${local.service} ECS tasks"
  assume_role_policy = data.aws_iam_policy_document.api_task_trust.json
}

data "aws_iam_policy_document" "api_task" {
  statement {
    sid       = "DataBucketList"
    actions   = ["s3:ListBucket"]
    resources = [module.data_bucket.s3_bucket_arn]
  }

  statement {
    sid       = "DataBucketObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${module.data_bucket.s3_bucket_arn}/*"]
  }

  statement {
    sid       = "ReadAppConfig"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [module.app_config_secret.secret_arn]
  }

  statement {
    sid       = "UseDataKeys"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [local.kms_key_arns["s3"], local.kms_key_arns["general"]]
  }
}

resource "aws_iam_role_policy" "api_task" {
  name   = "app-access"
  role   = aws_iam_role.api_task.id
  policy = data.aws_iam_policy_document.api_task.json
}
