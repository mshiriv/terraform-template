terraform {
  backend "s3" {
    bucket       = "CHANGEME-tfstate-staging"
    key          = "eu-west-1/02-platform/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
