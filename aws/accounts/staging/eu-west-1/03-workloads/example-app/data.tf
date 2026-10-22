# Cross-tier reads: workloads -> platform -> foundation. Lower tiers never read
# from higher-numbered ones.

data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "CHANGEME-tfstate-staging"
    key    = "eu-west-1/01-foundation/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = "CHANGEME-tfstate-staging"
    key    = "eu-west-1/02-platform/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_caller_identity" "current" {}

locals {
  kms_key_arns     = data.terraform_remote_state.foundation.outputs.kms_key_arns
  ecs_cluster_name = data.terraform_remote_state.platform.outputs.ecs_cluster_name
}
