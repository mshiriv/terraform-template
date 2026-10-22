# Azure

Azure roots follow the same pattern as AWS, keyed by environment instead of
account:

```
azure/
├── bootstrap/                          # state storage + CI identity (manual, local backend first)
└── <env>/<location>/<NN-tier>[/<workload>]/
    e.g. staging/westeurope/01-foundation/
```

- **Subscriptions** map from the `<env>` directory
  ([resolve-azure-subscription](../.github/actions/resolve-azure-subscription/action.yml)):
  `azure/production/**` → `AZURE_SUBSCRIPTION_PRODUCTION`,
  `azure/staging/**` → `AZURE_SUBSCRIPTION_STAGING`. CI exports
  `ARM_SUBSCRIPTION_ID`, so no subscription IDs live in root code.
- **Auth** is OIDC: [bootstrap](bootstrap/) creates an Entra app with one
  federated credential per GitHub OIDC subject (PRs, the default branch, each
  environment). No client secret exists.
- **State**: the `azurerm` backend in the storage account bootstrap creates,
  Entra-authenticated (`use_azuread_auth = true`, shared keys disabled), keyed
  `<env>/<location>/<tier>/terraform.tfstate`.
- **Tags**: azurerm has no `default_tags`. Every root defines a `local.tags`
  map with the same keys as AWS (`ManagedBy`, `Repository`, `Environment`,
  `Region`, `Product`, `Tier`) and sets `tags = local.tags` on each resource.

Setup: [SETUP.md step 10](../SETUP.md#10-azure-optional). To add an
environment, extend the `case` in `resolve-azure-subscription`, the chatops
`environment:` expression for Azure, and `workload_subscription_ids` in
bootstrap.
