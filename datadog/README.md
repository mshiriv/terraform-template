# Datadog

Datadog configuration as code. One root per area, state in the management
account's bucket (`datadog/<area>/terraform.tfstate`):

| Directory | Manages |
|-----------|---------|
| `monitors/example/` | Example metric monitor. Add `monitors/<area>/` per team or service. |
| `dashboards/`, `slos/`, `synthetics/` | Add as needed, same file layout. |
| `global/` | Org-level settings (SAML, role mappings, integrations), if you manage them here. |

## Authentication

The provider reads `DATADOG_API_KEY` and `DATADOG_APP_KEY` from the
environment; never put keys in variables or tfvars. For CI, create a service
account (`terraform-ci`) with an application key and a dedicated API key, and
store both as GitHub secrets (SETUP.md step 11). The API key is the masked
value at the top of the key's page, not its "Key ID".

Locally:

```bash
export AWS_PROFILE=<management-read>     # S3 state
export DATADOG_API_KEY=... DATADOG_APP_KEY=...
terraform -chdir=datadog/monitors/example plan
```

Set `datadog_api_url` per root for your site (`https://api.datadoghq.com/`
US1, `https://api.datadoghq.eu/` EU1, `https://api.us3.datadoghq.com/`, ...).
