terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# IAM is global; us-east-1 is its home region.
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Repository  = "YOUR_GITHUB_ORG/YOUR_GITHUB_REPO"
      Environment = var.environment
      Region      = "us-east-1"
      Product     = "shared"
      Tier        = "governance"
    }
  }
}
