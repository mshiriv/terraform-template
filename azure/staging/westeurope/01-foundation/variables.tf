variable "environment" {
  description = "Environment name (matches the azure/<env>/ directory)."
  type        = string
  default     = "staging"
  nullable    = false

  validation {
    condition     = contains(["production", "staging"], var.environment)
    error_message = "environment must be production or staging."
  }
}

variable "location" {
  description = "Azure region for this root's resources."
  type        = string
  default     = "westeurope"
  nullable    = false
}

variable "vnet_cidr" {
  description = "Address space of the environment VNet."
  type        = string
  default     = "10.101.0.0/16"
  nullable    = false
}
