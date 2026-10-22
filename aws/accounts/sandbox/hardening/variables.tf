variable "environment" {
  description = "Account short name this root is applied to (management, production, staging or sandbox)."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["management", "production", "staging", "sandbox"], var.environment)
    error_message = "environment must be one of management, production, staging, sandbox."
  }
}
