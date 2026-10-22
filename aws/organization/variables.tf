variable "account_name_prefix" {
  description = "Prefix for member account names: an account keyed `staging` is named `<prefix>-staging`."
  type        = string
  default     = "CHANGEME"
  nullable    = false
}

variable "organizational_units" {
  description = "Organizational units to create directly under the organization root."
  type        = set(string)
  default     = ["workloads", "sandbox"]
  nullable    = false
}

variable "accounts" {
  description = "Member accounts to create. Key = account short name (it must match the aws/accounts/<name> directory); ou must be one of organizational_units."
  type = map(object({
    email = string
    ou    = string
  }))
  nullable = false

  validation {
    condition     = alltrue([for a in values(var.accounts) : !endswith(lower(a.email), "@example.com")])
    error_message = "Replace the example.com placeholder emails in terraform.tfvars with addresses you control (one unique address per account)."
  }
}

variable "strict_scp_ous" {
  description = "OUs that get the strict SCP (deny root user, protect security services, keep S3 public-access blocks)."
  type        = set(string)
  default     = ["workloads"]
  nullable    = false
}

variable "require_tags_scp_ous" {
  description = "OUs that get the require-tags SCP (deny create without a Product tag). Roll it out to sandbox first, then add workloads once validated."
  type        = set(string)
  default     = ["sandbox"]
  nullable    = false
}

variable "monthly_budgets_usd" {
  description = "Monthly cost budget per member account, in USD. Key = account short name from var.accounts; accounts not listed get no budget."
  type        = map(number)
  default     = {}
  nullable    = false
}

variable "budget_alert_emails" {
  description = "Addresses notified at 50/80/100% of actual and 80% of forecasted spend."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "enable_sso" {
  description = "Manage IAM Identity Center groups, permission sets and account assignments (sso.tf). Enable Identity Center in the console first; it cannot be turned on through the API."
  type        = bool
  default     = false
  nullable    = false
}
