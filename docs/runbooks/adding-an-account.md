# Adding an AWS account

Example: a `security` account in the Workloads OU.

1. **aws/organization/terraform.tfvars**: add the account (unique email) and,
   optionally, its budget. PR → plan → `terraform apply aws/organization`.
2. **Extend the environment lists** (same or follow-up PR):
   - `environment` validations in the roots you'll create
     (`github-oidc`, `hardening`, `scripts/new-root.sh`);
   - `.github/actions/resolve-aws-role` (path → `AWS_ROLE_SECURITY`) and its
     callers' `role-*` inputs in the three workflows;
   - the chatops `environment:` mapping for the new account;
   - `aws/policies/tag/required-tags.json` `Environment` values.
3. **aws/bootstrap**: add a provider alias assuming
   `OrganizationAccountAccessRole` in the new account, plus a kms + bucket
   module pair (copy an existing pair). Run `scripts/bootstrap.sh` (or apply
   `aws/bootstrap` by hand with `-var account_ids=...`).
4. **CI role**: copy `aws/accounts/staging/github-oidc` to
   `aws/accounts/security/github-oidc`, set its backend bucket and tfvars
   (`github_environments = ["security"]`), and apply it once with the
   account's credentials (bootstrap's step 4 shows how).
5. **GitHub**: secret `AWS_ROLE_SECURITY`, environment `security` restricted to
   the default branch.
6. Scaffold the account's roots with `scripts/new-root.sh` and ship them
   through the normal PR flow.
