variable "location" {
  description = "Azure region for the bootstrap (state + identity) resources."
  type        = string
  default     = "westeurope"
  nullable    = false
}

variable "state_subscription_id" {
  description = "Subscription that hosts the Terraform state storage account."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.state_subscription_id)) && var.state_subscription_id != "00000000-0000-0000-0000-000000000000"
    error_message = "state_subscription_id must be a real subscription GUID (replace the all-zero placeholder)."
  }
}

variable "workload_subscription_ids" {
  description = "Subscriptions the CI identity manages, keyed by environment (must match the azure/<env>/ directories and the AZURE_SUBSCRIPTION_<ENV> secrets)."
  type        = map(string)
  nullable    = false

  validation {
    condition     = alltrue([for id in values(var.workload_subscription_ids) : id != "00000000-0000-0000-0000-000000000000"])
    error_message = "Replace the all-zero placeholder subscription IDs in terraform.tfvars."
  }
}

variable "github_repository" {
  description = "GitHub repository (owner/name) whose Actions OIDC tokens may federate into the CI identity."
  type        = string
  default     = "YOUR_GITHUB_ORG/YOUR_GITHUB_REPO"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "github_repository must be a real owner/name slug. Run scripts/init-template.sh to replace the placeholder."
  }
}

variable "default_branch" {
  description = "Default branch: scheduled drift checks and chatops plans present its ref as the OIDC subject."
  type        = string
  default     = "main"
  nullable    = false
}
