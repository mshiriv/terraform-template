# Per-account monthly cost budgets
#
# One budget per entry in var.monthly_budgets_usd, filtered to that member
# account, alerting var.budget_alert_emails at 50/80/100% of actual spend and
# at 80% of forecasted spend.
#
# Cost Anomaly Detection is deliberately not managed here: new accounts get an
# AWS-created default services monitor, and a second DIMENSIONAL/SERVICE
# monitor fails with a limit error. Tune the default one in the console.

locals {
  budget_thresholds = {
    actual_50     = { threshold = 50, type = "ACTUAL" }
    actual_80     = { threshold = 80, type = "ACTUAL" }
    actual_100    = { threshold = 100, type = "ACTUAL" }
    forecasted_80 = { threshold = 80, type = "FORECASTED" }
  }
}

resource "aws_budgets_budget" "monthly" {
  for_each = length(var.budget_alert_emails) > 0 ? var.monthly_budgets_usd : {}

  name         = "monthly-${each.key}"
  budget_type  = "COST"
  limit_amount = tostring(each.value)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "LinkedAccount"
    values = [aws_organizations_account.accounts[each.key].id]
  }

  dynamic "notification" {
    for_each = local.budget_thresholds

    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value.threshold
      threshold_type             = "PERCENTAGE"
      notification_type          = notification.value.type
      subscriber_email_addresses = var.budget_alert_emails
    }
  }
}
