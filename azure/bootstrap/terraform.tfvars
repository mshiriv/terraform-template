# Replace the placeholder GUIDs before the first plan (the variables reject
# them). Subscription IDs are identifiers, not secrets, but keep this repo
# private if you'd rather not publish them.

state_subscription_id = "00000000-0000-0000-0000-000000000000"

workload_subscription_ids = {
  staging    = "00000000-0000-0000-0000-000000000000"
  production = "00000000-0000-0000-0000-000000000000"
}
