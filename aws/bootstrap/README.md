# Bootstrap: per-account state buckets

Creates the Terraform state bucket, and a dedicated KMS key for it, in every
member account. Applied by [`scripts/bootstrap.sh`](../../scripts/bootstrap.sh)
(SETUP.md step 5), never by CI: it spans several accounts through aliased
providers and needs the account IDs from `aws/organization` at runtime.

## Sequence

```
scripts/bootstrap.sh, from the management account:
  Step 0  AWS CLI      -> <prefix>-tfstate-management (holds this root's state)
  Step 1  terraform    -> aws/organization  (organization, OUs, accounts, SCPs)
  Step 2  terraform    -> aws/bootstrap     (this root: member-account buckets)
  Step 3  terraform    -> aws/accounts/management/github-oidc
  Step 4  terraform    -> aws/accounts/<member>/github-oidc  (via OrganizationAccountAccessRole)
```

Every step is idempotent: re-running the script skips anything already in
the desired state.

## Why one bucket per account

- **Blast radius.** State contains ARNs, IPs, connection strings and
  sometimes secret values. Keeping production state inside the production
  account means access to it is governed by that account's IAM and SSO
  assignments.
- **Least privilege.** A staging CI role can't read production state.
- **Audit.** State access shows up in that account's CloudTrail.

State locking uses S3 native locking (`use_lockfile = true`, Terraform 1.10+);
no DynamoDB table.

## Hardening (every state bucket)

| Setting | Value | Why |
|---|---|---|
| Versioning | Enabled; non-current versions kept 90 days | Roll back a corrupted or bad state write |
| Encryption | SSE-KMS with a dedicated, rotated CMK per account (management: AWS-managed key) | Encryption at rest, key access auditable |
| Public access | Fully blocked, ACLs disabled (BucketOwnerEnforced) | No accidental exposure |
| Bucket policy | Deny non-TLS, require TLS 1.2+ | Encryption in transit |

## Adding an account

See [docs/runbooks/adding-an-account.md](../../docs/runbooks/adding-an-account.md).
In this root: one provider alias in `providers.tf` (providers can't use
`for_each`, so each account needs a static alias) and one KMS + bucket module
pair in `main.tf`, then re-run `scripts/bootstrap.sh`.

## Edge cases

- **Bucket name taken.** S3 names are global. If `<prefix>-tfstate-<env>`
  belongs to someone else, creation fails; pick another prefix
  (re-run `scripts/init-template.sh` on a fresh copy) before anything is applied.
- **Bucket exists but isn't in state.** Import it (`import` block) instead of
  creating it.

## Terraform reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_state_bucket_production"></a> [state\_bucket\_production](#module\_state\_bucket\_production) | terraform-aws-modules/s3-bucket/aws | ~> 5.0 |
| <a name="module_state_bucket_sandbox"></a> [state\_bucket\_sandbox](#module\_state\_bucket\_sandbox) | terraform-aws-modules/s3-bucket/aws | ~> 5.0 |
| <a name="module_state_bucket_staging"></a> [state\_bucket\_staging](#module\_state\_bucket\_staging) | terraform-aws-modules/s3-bucket/aws | ~> 5.0 |
| <a name="module_state_kms_production"></a> [state\_kms\_production](#module\_state\_kms\_production) | terraform-aws-modules/kms/aws | ~> 4.0 |
| <a name="module_state_kms_sandbox"></a> [state\_kms\_sandbox](#module\_state\_kms\_sandbox) | terraform-aws-modules/kms/aws | ~> 4.0 |
| <a name="module_state_kms_staging"></a> [state\_kms\_staging](#module\_state\_kms\_staging) | terraform-aws-modules/kms/aws | ~> 4.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_ids"></a> [account\_ids](#input\_account\_ids) | Map of member account name to account ID: the `account_ids` output of aws/organization. scripts/bootstrap.sh passes it in. | `map(string)` | n/a | yes |
| <a name="input_noncurrent_version_retention_days"></a> [noncurrent\_version\_retention\_days](#input\_noncurrent\_version\_retention\_days) | Days to keep non-current state object versions (the rollback window for a corrupted or bad state write). | `number` | `90` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_state_buckets"></a> [state\_buckets](#output\_state\_buckets) | Terraform state bucket name per member account. Each account's roots use theirs in backend.tf. |
| <a name="output_state_kms_key_arns"></a> [state\_kms\_key\_arns](#output\_state\_kms\_key\_arns) | KMS key ARN encrypting each member account's state bucket. |
<!-- END_TF_DOCS -->
