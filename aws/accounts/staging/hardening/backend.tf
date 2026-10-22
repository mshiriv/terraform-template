terraform {
  backend "s3" {
    bucket       = "CHANGEME-tfstate-staging"
    key          = "hardening/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
