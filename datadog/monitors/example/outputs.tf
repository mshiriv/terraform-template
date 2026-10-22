output "monitor_ids" {
  description = "IDs of the monitors managed by this root."
  value = {
    host_cpu_high = datadog_monitor.host_cpu_high.id
  }
}
