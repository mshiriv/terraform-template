variable "github_owner" {
  description = "GitHub organization or user that owns the managed repository."
  type        = string
  default     = "YOUR_GITHUB_ORG"
  nullable    = false
}

variable "repository" {
  description = "Repository (within github_owner) whose default-branch protection ruleset is managed here."
  type        = string
  default     = "YOUR_GITHUB_REPO"
  nullable    = false
}

variable "required_status_checks" {
  description = "Status-check contexts that must pass before merging to the default branch. Use STABLE job names: dynamic matrix leg names (e.g. \"Plan: <dir>\") vary per PR and cannot be required."
  type        = list(string)
  default     = ["plan-summary", "Pre-commit Checks"]
  nullable    = false

  validation {
    condition     = length(var.required_status_checks) > 0
    error_message = "At least one required status check must be configured."
  }
}

variable "required_approving_review_count" {
  description = "Approving reviews required before a PR can merge. Set 0 for a solo maintainer (a required approval could never be satisfied); the chatops apply gate still requires an approval or an audited admin override."
  type        = number
  default     = 1
  nullable    = false

  validation {
    condition     = var.required_approving_review_count >= 0
    error_message = "Required approving review count cannot be negative."
  }
}

variable "require_code_owner_review" {
  description = "Require a CODEOWNERS approval. Turn off while the only code owner is also the PR author (they cannot approve their own PR)."
  type        = bool
  default     = true
  nullable    = false
}

variable "org_admin_break_glass" {
  description = "Add an OrganizationAdmin bypass so org admins can merge a PR while a required check is stuck or CI is down (bypass applies to PR merges only, never direct pushes). Only meaningful for organization-owned repositories."
  type        = bool
  default     = false
  nullable    = false
}
