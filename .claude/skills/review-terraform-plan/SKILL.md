---
name: review-terraform-plan
description: Use when asked to review a terraform plan (a CI plan comment on a PR, a drift issue, or local `terraform plan` output) before someone applies it. Checks that every change is explained by the PR's diff, and flags destroys, replacements, IAM/network/data-loss risks and drift riding along. Produces a go / no-go with reasons.
---

# Reviewing a Terraform plan

Chatops `terraform apply <dir>` re-plans and applies the **whole root** at the
PR's head commit. Anything in that root's plan ships, whether or not this PR
caused it. The review answers one question: *is every change in this plan
intended?*

## 1. Gather

- The plan: the PR comment titled `Plan: <dir>` (or run
  `gh pr view <n> --comments`), or local plan output.
- The intent: `git diff --stat origin/main...HEAD -- <dir>` and the full diff
  of that root. Also the PR description.

## 2. Reconcile plan against diff

For each resource in the plan, find the line(s) in the diff that cause it.
Anything you can't trace is one of:

| Untraceable change | Usually means | Action |
|---|---|---|
| Update to a resource the PR didn't touch | Drift (someone changed it by hand) or a provider default change | Stop. Decide: import / codify the live value, or let the apply revert it on purpose |
| Changes from another PR | Applied-but-unmerged branch, or a merge on `main` not yet applied | Stop. Coordinate; never apply someone else's change by accident |
| Perpetual diff (same change on every plan) | Provider/API normalization (e.g. a value equal to the server default) | Fine to apply, but fix the config so the diff disappears |
| `~ update in-place` on tags only | A default_tags change | Usually fine; confirm it's expected |

## 3. Flag the dangerous shapes

Search the plan for these and require an explicit reason in the PR for each:

- `must be replaced` / `-/+` / `+/-`: replacement. Check for `# forces
  replacement` on immutable arguments (names, descriptions of security groups,
  subnet CIDRs, KMS key specs, ELB names). Replacing a database, bucket, EIP,
  load balancer or DNS record is an outage or data loss.
- `will be destroyed`: especially stateful resources (`aws_db_*`, `aws_rds_*`,
  `aws_s3_bucket`, `aws_dynamodb_table`, `aws_efs_*`, `aws_kms_key`,
  `aws_secretsmanager_secret`, `aws_route53_record`, `aws_eip`). A rename
  without a `moved {}` block shows up as destroy + create: ask for the `moved`
  block instead.
- IAM: new `Action: "*"` / `Resource: "*"`, wildcard principals, trust policy
  changes (`assume_role_policy`), OIDC subject changes, new `AdministratorAccess`.
- Network exposure: `0.0.0.0/0` / `::/0` ingress, `internal = false`,
  `publicly_accessible = true`, public S3 policies or ACLs, removed
  public-access blocks.
- Encryption/logging turned off: `kms_key_id` removed, `encrypted = false`,
  flow/access logs disabled, retention shortened.
- `(known after apply)` on an identifier other roots read through remote state:
  downstream roots will need a follow-up apply.
- Errors or warnings in the plan output (deprecations included).

## 4. Order and blast radius

- Multi-root PRs apply tier by tier: `01-foundation` before `02-platform`
  before `03-workloads`. A tier that removes an output another tier still
  reads must go last, after the reader stops using it.
- Production after staging, never both in one comment unless the change is
  trivial.

## 5. Verdict

Answer with:

- **Go / No-go**, one line.
- Each change you could not trace to the diff, with the likely cause.
- Each dangerous shape found and whether the PR justifies it.
- The exact apply sequence (`terraform apply <dir>` comments, in order).

Never post the apply comment yourself, and never run `terraform apply`.
