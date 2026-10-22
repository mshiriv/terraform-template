# Foundation: KMS keys, VPC, flow logs, S3 gateway endpoint
#
# Account: production
# Region:  primary workload region
#
# Everything every workload in this region depends on, created before any
# compute or data plane. Consumers read the outputs via terraform_remote_state.

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  name = var.environment

  # One CMK per data class, rotated yearly. `logs` additionally lets the
  # CloudWatch Logs service in this region use it (flow logs, app log groups).
  kms_keys = {
    ebs     = "EBS volume encryption"
    rds     = "RDS / Aurora encryption"
    s3      = "S3 bucket encryption"
    general = "General purpose: Secrets Manager, ECR, ECS exec, SQS/SNS"
    logs    = "CloudWatch Logs encryption"
  }

  # CIDR plan: one /16 per account per region (see aws/README.md#cidr-plan),
  # carved into /20s (4,096 IPs) per tier per AZ. Slots for up to three AZs are
  # reserved per tier, so adding an AZ (append to local.azs) is additive:
  #
  #   tier      AZ index 0      AZ index 1      AZ index 2
  #   public    x.x.0.0/20      x.x.16.0/20     x.x.32.0/20
  #   private   x.x.48.0/20     x.x.64.0/20     x.x.80.0/20
  #   database  x.x.96.0/20     x.x.112.0/20    x.x.128.0/20
  vpc_cidr = "10.0.0.0/16"
  # Pinned explicitly so the subnet layout never shifts when AWS adds an AZ.
  azs = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

  public_subnets   = [for i in range(length(local.azs)) : cidrsubnet(local.vpc_cidr, 4, i)]
  private_subnets  = [for i in range(length(local.azs)) : cidrsubnet(local.vpc_cidr, 4, i + 3)]
  database_subnets = [for i in range(length(local.azs)) : cidrsubnet(local.vpc_cidr, 4, i + 6)]
}

module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 4.0"

  for_each = local.kms_keys

  description             = "${each.value} (${var.environment})"
  aliases                 = ["${local.name}-${each.key}"]
  enable_key_rotation     = true
  deletion_window_in_days = 30

  key_statements = each.key == "logs" ? [
    {
      sid = "CloudWatchLogs"
      actions = [
        "kms:Encrypt*",
        "kms:Decrypt*",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:Describe*",
      ]
      resources = ["*"]
      principals = [
        {
          type        = "Service"
          identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
        },
      ]
      conditions = [
        {
          test     = "ArnLike"
          variable = "kms:EncryptionContext:aws:logs:arn"
          values   = ["arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:*"]
        },
      ]
    },
  ] : []
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.name
  cidr = local.vpc_cidr

  azs              = local.azs
  public_subnets   = local.public_subnets
  private_subnets  = local.private_subnets
  database_subnets = local.database_subnets

  create_database_subnet_group = true

  # Production: one NAT gateway per AZ, so losing an AZ never cuts egress for
  # the others (and no cross-AZ NAT data charges).
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Lock down the default security group / NACL / route table so nothing can
  # accidentally use them.
  manage_default_security_group = true
  default_security_group_egress = []

  enable_flow_log                                 = true
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_max_aggregation_interval               = 60
  flow_log_cloudwatch_log_group_retention_in_days = var.log_retention_days
  flow_log_cloudwatch_log_group_kms_key_id        = module.kms["logs"].key_arn
}

# S3 gateway endpoint: free, keeps S3 traffic (ECR layers, app buckets) off the
# NAT gateway. Add interface endpoints here when a service's NAT data charges
# outweigh ~$7/month/AZ per endpoint.
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 6.0"

  vpc_id = module.vpc.vpc_id

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
      tags            = { Name = "${local.name}-s3" }
    }
  }
}
