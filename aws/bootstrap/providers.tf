terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Management account: default provider (the caller's own credentials).
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Repository  = "YOUR_GITHUB_ORG/YOUR_GITHUB_REPO"
      Environment = "management"
      Region      = "us-east-1"
      Product     = "shared"
      Tier        = "bootstrap"
    }
  }
}

# Member accounts: assumed from the management account through the role AWS
# Organizations creates in every new account. Providers cannot use for_each, so
# each account needs a static alias here plus a module pair in main.tf.

provider "aws" {
  alias  = "production"
  region = "us-east-1"

  assume_role {
    role_arn = "arn:aws:iam::${var.account_ids["production"]}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Repository  = "YOUR_GITHUB_ORG/YOUR_GITHUB_REPO"
      Environment = "production"
      Region      = "us-east-1"
      Product     = "shared"
      Tier        = "bootstrap"
    }
  }
}

provider "aws" {
  alias  = "staging"
  region = "us-east-1"

  assume_role {
    role_arn = "arn:aws:iam::${var.account_ids["staging"]}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Repository  = "YOUR_GITHUB_ORG/YOUR_GITHUB_REPO"
      Environment = "staging"
      Region      = "us-east-1"
      Product     = "shared"
      Tier        = "bootstrap"
    }
  }
}

provider "aws" {
  alias  = "sandbox"
  region = "us-east-1"

  assume_role {
    role_arn = "arn:aws:iam::${var.account_ids["sandbox"]}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Repository  = "YOUR_GITHUB_ORG/YOUR_GITHUB_REPO"
      Environment = "sandbox"
      Region      = "us-east-1"
      Product     = "shared"
      Tier        = "bootstrap"
    }
  }
}
