variable "account_ids" {
  description = "Map of member account name to account ID: the `account_ids` output of aws/organization. scripts/bootstrap.sh passes it in."
  type        = map(string)
  nullable    = false

  validation {
    condition     = alltrue([for name in ["production", "staging", "sandbox"] : contains(keys(var.account_ids), name)])
    error_message = "account_ids must contain the production, staging and sandbox accounts."
  }

  validation {
    condition     = alltrue([for id in values(var.account_ids) : can(regex("^[0-9]{12}$", id))])
    error_message = "Every account ID must be a 12-digit AWS account number."
  }
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep non-current state object versions (the rollback window for a corrupted or bad state write)."
  type        = number
  default     = 90
  nullable    = false

  validation {
    condition     = var.noncurrent_version_retention_days >= 30
    error_message = "Keep at least 30 days of state history."
  }
}
