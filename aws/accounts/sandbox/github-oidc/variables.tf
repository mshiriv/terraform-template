variable "environment" {
  description = "Account short name this root is applied to (management, production, staging or sandbox)."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["management", "production", "staging", "sandbox"], var.environment)
    error_message = "environment must be one of management, production, staging, sandbox."
  }
}

variable "github_repository" {
  description = "GitHub repository (owner/name) whose Actions workflows may assume the CI role."
  type        = string
  default     = "YOUR_GITHUB_ORG/YOUR_GITHUB_REPO"
  nullable    = false

  validation {
    # GitHub owners are alphanumerics and single hyphens only, so the template
    # placeholder can never match a real repository's OIDC subject.
    condition     = can(regex("^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "github_repository must be a real owner/name slug. Run scripts/init-template.sh to replace the YOUR_GITHUB_ORG/YOUR_GITHUB_REPO placeholder."
  }
}

variable "default_branch" {
  description = "Default branch of the repository. Scheduled drift checks and chatops plans run on it."
  type        = string
  default     = "main"
  nullable    = false
}

variable "github_environments" {
  description = "GitHub Environments whose chatops apply jobs may assume the CI role in this account (see the environment mapping in terraform-chatops.yml)."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.github_environments) > 0
    error_message = "List at least one GitHub Environment, or no apply job can assume this role."
  }
}

variable "ci_role_name" {
  description = "Name of the IAM role GitHub Actions assumes. Its ARN goes in the AWS_ROLE_<ENV> repository secret."
  type        = string
  default     = "github-actions-terraform"
  nullable    = false
}
