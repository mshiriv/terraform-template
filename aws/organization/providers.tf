terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Organizations, IAM Identity Center and Budgets are managed from us-east-1.
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Repository  = "YOUR_GITHUB_ORG/YOUR_GITHUB_REPO"
      Environment = "management"
      Region      = "us-east-1"
      Product     = "shared"
      Tier        = "organization"
    }
  }
}
