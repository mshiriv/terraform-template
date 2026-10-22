data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "CHANGEME-tfstate-staging"
    key    = "eu-west-1/01-foundation/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  vpc_id       = data.terraform_remote_state.foundation.outputs.vpc_id
  kms_key_arns = data.terraform_remote_state.foundation.outputs.kms_key_arns
}
