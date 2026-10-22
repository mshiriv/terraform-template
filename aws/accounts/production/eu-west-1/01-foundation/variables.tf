variable "environment" {
  description = "Environment (account short name). Also used as the VPC name and KMS alias prefix."
  type        = string
  default     = "production"
  nullable    = false

  validation {
    condition     = contains(["production", "staging", "sandbox"], var.environment)
    error_message = "environment must be one of production, staging, sandbox."
  }
}

variable "log_retention_days" {
  description = "Retention for the VPC flow log group, in days."
  type        = number
  default     = 365
  nullable    = false
}
