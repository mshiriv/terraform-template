# datadog / monitors / example

An example metric monitor (host CPU). Keys come from `DATADOG_API_KEY` /
`DATADOG_APP_KEY` (environment, GitHub secrets in CI); set
`datadog_api_url` for your Datadog site. Add sibling directories under
`datadog/` for dashboards, SLOs and synthetics.

## Terraform reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.0 |
| <a name="requirement_datadog"></a> [datadog](#requirement\_datadog) | ~> 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [datadog_monitor.host_cpu_high](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_datadog_api_url"></a> [datadog\_api\_url](#input\_datadog\_api\_url) | Datadog API endpoint for your site, e.g. https://api.datadoghq.com/ (US1) or https://api.datadoghq.eu/ (EU1). | `string` | `"https://api.datadoghq.com/"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment the monitors watch (the `env` tag value on your hosts and services). | `string` | `"staging"` | no |
| <a name="input_notification_handles"></a> [notification\_handles](#input\_notification\_handles) | Datadog notification handles appended to every monitor message, e.g. ["@slack-ops-alerts", "@pagerduty-platform"]. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_monitor_ids"></a> [monitor\_ids](#output\_monitor\_ids) | IDs of the monitors managed by this root. |
<!-- END_TF_DOCS -->
