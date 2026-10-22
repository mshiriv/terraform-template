# Secrets Manager naming convention

How AWS Secrets Manager secrets are named across the estate. Applies to every
secret created in Terraform **and** every out-of-band secret a workload reads
(e.g. through External Secrets Operator or the ECS `secrets` block).

## The shape

```
<env>/<product>/<runtime>/<consumer>/[<category>/]<leaf>
```

| Segment | Meaning | Examples |
|---|---|---|
| `<env>` | account / deployment stage | `staging`, `production` |
| `<product>` | product or tenant | `example-app`, `shared` |
| `<runtime>` | platform / consumer domain | `ecs`, `eks`, `lambda`, `ci` |
| `<consumer>` | what reads it: ECS service, k8s namespace, function. **The IAM access boundary.** | `api`, `worker`, `monitoring` |
| `<category>` *(optional)* | groups a family under one consumer | `db`, `app`, `integrations` |
| `<leaf>` | the secret itself | `credentials`, `config`, `api-key` |

Example: `staging/example-app/ecs/api/app/config`.

## Rules

1. **env-first, slash hierarchy, general → specific.** Broadest, most stable
   segment first.
2. **Lowercase only.** `-` separates words *within* a segment (`api-key`);
   `/` only separates hierarchy levels.
3. **No redundant prefixes in the leaf.** The path already says `staging` and
   the product, so `…/db/credentials`, not `…/db/staging-example-app-credentials`.
4. **`<category>` lives *under* the consumer, never above it**, so the
   consumer-level IAM wildcard (rule 6) keeps working.
5. **Names are immutable.** Changing a secret's `name` is a destroy +
   recreate (and in production a recovery window blocks re-creating the same
   name for up to 30 days). Pick the name once; migrate deliberately
   (create the new name, move readers, then delete the old one).
6. **Why this order:** `<env>` maps to the account boundary, and the consumer
   is the real access-control unit, so it sits exactly where an IAM wildcard
   is written:
   `arn:aws:secretsmanager:<region>:<account>:secret:staging/example-app/ecs/api/*`.
   Secrets Manager appends a random `-AbCdEf` suffix to every ARN, so IAM
   *must* wildcard; this layout keeps that wildcard least-privilege. The
   console also renders the slashes as a folder tree.

## How to create one

- **Terraform-managed container, value set out-of-band** (the default): use
  `terraform-aws-modules/secrets-manager/aws` (`~> 2.0`), seed
  `secret_string = jsonencode({})` once with `ignore_secret_changes = true`,
  and set the real value in the console/CLI. The value never enters state.
  Encrypt with the foundation **general CMK** (`kms_key_id`). See
  `app_config_secret` in
  [example-app/main.tf](accounts/staging/eu-west-1/03-workloads/example-app/main.tf).
- **Value must exist at apply time** (e.g. a generated cache auth token):
  let Terraform own it, preferably through a write-only argument
  (`secret_string_wo` + `secret_string_wo_version`) so the value is not
  persisted in state.
- **Adopting an existing secret**: `import` it as a bare
  `aws_secretsmanager_secret` (no `aws_secretsmanager_secret_version`), so the
  live value never enters state and no apply can overwrite it. Don't import
  through the module: it always manages a version.
- Use `recovery_window_in_days = 0` in non-production for rename convenience;
  keep the default window in production.

Grant readers `secretsmanager:GetSecretValue` on the consumer-level wildcard
plus `kms:Decrypt` on the general CMK.
