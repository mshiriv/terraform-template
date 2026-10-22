terraform {
  required_version = ">= 1.14.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  owner = var.github_owner
  # Authentication comes from the GITHUB_TOKEN environment variable: a GitHub
  # App installation token or fine-grained PAT with `administration:write` on
  # the managed repository for apply (read is enough for plan). See README.md.
}
