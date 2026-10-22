# Bootstrap state lives in the management account's state bucket, which
# scripts/bootstrap.sh creates (Step 0) before this root is first initialized.
terraform {
  backend "s3" {
    bucket       = "CHANGEME-tfstate-management"
    key          = "bootstrap/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
