# Non-secret organization settings. Replace every example.com address before
# the first plan (the accounts variable rejects them). Use a distinct mailbox or
# plus-address per account; AWS requires each account email to be unique.

accounts = {
  production = {
    email = "aws+production@example.com"
    ou    = "workloads"
  }
  staging = {
    email = "aws+staging@example.com"
    ou    = "workloads"
  }
  sandbox = {
    email = "aws+sandbox@example.com"
    ou    = "sandbox"
  }
}

monthly_budgets_usd = {
  production = 2000
  staging    = 1000
  sandbox    = 500
}

budget_alert_emails = []

enable_sso = false
