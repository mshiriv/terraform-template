variable "datadog_api_url" {
  description = "Datadog API endpoint for your site, e.g. https://api.datadoghq.com/ (US1) or https://api.datadoghq.eu/ (EU1)."
  type        = string
  default     = "https://api.datadoghq.com/"
  nullable    = false
}

variable "environment" {
  description = "Environment the monitors watch (the `env` tag value on your hosts and services)."
  type        = string
  default     = "staging"
  nullable    = false
}

variable "notification_handles" {
  description = "Datadog notification handles appended to every monitor message, e.g. [\"@slack-ops-alerts\", \"@pagerduty-platform\"]."
  type        = list(string)
  default     = []
  nullable    = false
}
