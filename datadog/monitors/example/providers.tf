terraform {
  required_version = ">= 1.14.0"

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 4.0"
    }
  }
}

# API and application keys come from the DATADOG_API_KEY / DATADOG_APP_KEY
# environment variables (GitHub secrets in CI); never from variables or tfvars.
provider "datadog" {
  api_url = var.datadog_api_url
}
