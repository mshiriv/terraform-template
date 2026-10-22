terraform {
  backend "s3" {
    bucket       = "CHANGEME-tfstate-management"
    key          = "organization/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
