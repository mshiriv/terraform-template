terraform {
  backend "s3" {
    bucket       = "CHANGEME-tfstate-sandbox"
    key          = "github-oidc/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
