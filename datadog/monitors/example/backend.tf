# Datadog roots keep state in the management account bucket.
terraform {
  backend "s3" {
    bucket       = "CHANGEME-tfstate-management"
    key          = "datadog/monitors/example/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
