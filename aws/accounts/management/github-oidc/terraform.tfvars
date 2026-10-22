environment = "management"

# The management role backs aws/organization, aws/accounts/management/*, the
# datadog/* and github/* roots (their state lives in the management bucket), so
# it trusts both apply environments those use in terraform-chatops.yml.
github_environments = ["organization", "datadog"]
