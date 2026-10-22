terraform {
  backend "s3" {
    bucket       = "CHANGEME-tfstate-production"
    key          = "eu-west-1/01-foundation/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
