# Datadog monitors: example
#
# One monitor per resource; group related monitors per directory under
# datadog/monitors/. Tag every monitor with team + env so they're filterable
# and routable.

locals {
  notify = join(" ", var.notification_handles)

  tags = [
    "managed-by:terraform",
    "env:${var.environment}",
    "team:platform",
  ]
}

resource "datadog_monitor" "host_cpu_high" {
  name    = "[${var.environment}] High CPU on {{host.name}}"
  type    = "metric alert"
  message = <<-EOT
    CPU on {{host.name}} has averaged above {{threshold}}% for 15 minutes.
    Check for a runaway process or an under-sized instance.
    ${local.notify}
  EOT

  query = "avg(last_15m):avg:system.cpu.user{env:${var.environment}} by {host} > 90"

  monitor_thresholds {
    critical = 90
    warning  = 80
  }

  notify_no_data    = false
  renotify_interval = 60
  include_tags      = true

  tags = local.tags
}
