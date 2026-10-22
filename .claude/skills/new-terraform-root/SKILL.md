---
name: new-terraform-root
description: Use when adding infrastructure that needs a NEW Terraform root in this repo (a new product under 03-workloads, a new tier/region for an account, or a new account-level root like config). Decides placement with the repo's decision tree, scaffolds the root with scripts/new-root.sh, wires cross-tier remote state, and runs the guardrails. Not for editing an existing root.
---

# Adding a Terraform root

A *root* is any directory with a `backend.tf`. CI discovers roots by that file
(`scripts/detect-changes.sh`), so a correctly scaffolded root is planned on its
first PR with no workflow edits.

## 1. Decide whether you need a new root at all

Prefer adding to an existing root when the change has the same owner, the same
lifecycle and the same blast radius as what's already there. Create a new root
when one of these is true:

- it belongs to a **new product** (`03-workloads/<product>`),
- it is a **tier or region** an account doesn't have yet,
- it needs **different credentials or providers** than its neighbours, or
- isolating its state meaningfully shrinks the blast radius of a bad apply.

## 2. Place it

Walk the decision tree in `aws/README.md` ("Where does my change go?"). The
short form:

| What | Where |
|---|---|
| Org, OUs, SCPs, SSO | `aws/organization/` (exists) |
| Account-wide, region-agnostic (IAM, Config, password policy) | `aws/accounts/<env>/<name>/` |
| Network primitives, KMS keys, endpoints | `aws/accounts/<env>/<region>/01-foundation/` |
| Shared by 2+ workloads (cluster, database, cache) | `aws/accounts/<env>/<region>/02-platform/` |
| Owned by one product | `aws/accounts/<env>/<region>/03-workloads/<product>/` |

Higher tiers read lower ones via `terraform_remote_state`; never the reverse.

## 3. Scaffold

```bash
scripts/new-root.sh aws/accounts/<env>/<region>/03-workloads/<product>
```

This writes `backend.tf` (bucket `<prefix>-tfstate-<env>`, key mirroring the
path, native S3 locking), `providers.tf` (`~>` pins, all six mandatory
`default_tags`), `variables.tf`, `main.tf`, `outputs.tf`, `data.tf` (remote
state for the lower tiers) and a `README.md` with terraform-docs markers.

Never hand-write `backend.tf`: a wrong `key` silently shares or overwrites
another root's state.

## 4. Fill it in

Follow `CLAUDE.md` (conventions) and the vendored terraform-skill:

- Prefer `terraform-aws-modules/*` registry modules (pinned `~> X.0`) over raw
  resources when one fits; check the module's real inputs by running
  `terraform init -backend=false` and reading `.terraform/modules/*/variables.tf`
  rather than guessing names.
- Consume lower tiers through `local`s in `data.tf`
  (`data.terraform_remote_state.foundation.outputs.kms_key_arns["s3"]`).
- Name secrets per `aws/SECRETS.md`; never put secret values in variables,
  tfvars or outputs.
- Resource labels describe the thing (`aws_iam_role.api_task`); `this` only
  for true singletons.

For a new product, copy the shape of
`aws/accounts/staging/<region>/03-workloads/example-app/` and add the product
to `aws/policies/tag/required-tags.json` (the `Product` allowed values).

## 5. Verify, then hand off

```bash
pre-commit run --files <root>/*        # fmt, validate, tflint, docs, checkov, trivy
scripts/check-required-tags.sh
```

Fix findings rather than suppressing them. If a suppression is truly right,
put an inline `#checkov:skip=<ID>:<reason>` / `#trivy:ignore:<ID>` on the one
resource, with the reason.

If the root is security-sensitive, add a path to `.github/CODEOWNERS`. If CI
can't reach it (e.g. a provider that needs a private network path), add a
`.ci-skip` file explaining why and document the out-of-band apply in its
README.

You cannot apply: `terraform apply` is denied to Claude in this repo. Open the
PR; humans apply through the chatops flow (`terraform apply <dir>` comment).
