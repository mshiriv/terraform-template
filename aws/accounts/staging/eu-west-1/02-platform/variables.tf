variable "environment" {
  description = "Environment (account short name). Also the ECS cluster name."
  type        = string
  default     = "staging"
  nullable    = false

  validation {
    condition     = contains(["production", "staging", "sandbox"], var.environment)
    error_message = "environment must be one of production, staging, sandbox."
  }
}

variable "log_retention_days" {
  description = "Retention for platform log groups, in days."
  type        = number
  default     = 365
  nullable    = false
}
