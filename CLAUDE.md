# CLAUDE.md

Guidance for Claude Code (and humans) working in this repository. Keep it
short; link out rather than duplicate.

## What this is

A Terraform (**not** OpenTofu) monorepo for a multi-cloud estate: AWS
(primary), Azure and Datadog, plus GitHub settings as code. It is a
**leaf-config monorepo**: each deployable unit is a self-contained Terraform
*root* (a directory with a `backend.tf`), wired to others by remote state.

There is **no local `modules/` directory**. Reusable modules come from the
public registry (prefer `terraform-aws-modules/*`) or from a separate,
versioned modules repository consumed via pinned `git::...?ref=<tag>`
sources. **Do not create a local `modules/` dir or inline a module that
belongs upstream.**

New here? Setup: [SETUP.md](SETUP.md). "Where does my change go?":
[aws/README.md](aws/README.md). Pipelines: [docs/ci-cd.md](docs/ci-cd.md).

If backend buckets in this checkout still have an upper-case prefix, the
template hasn't been initialized: run `scripts/init-template.sh` (SETUP.md
step 3) before anything else.

## Layout

```
aws/organization/                                   # org, OUs, accounts, SCPs, SSO, budgets
aws/bootstrap/                                      # per-account state buckets (manual, scripts/bootstrap.sh)
aws/policies/                                       # SCP + tag policy JSON (consumed by organization/)
aws/accounts/<env>/<account-level-root>/            # github-oidc, hardening, ... (region-agnostic)
aws/accounts/<env>/<region>/<NN-tier>[/<workload>]/ # regional roots
azure/<env>/<location>/<NN-tier>[/<workload>]/
datadog/<area>/
github/repo-management/                             # branch ruleset; applied out-of-band
```

- **env**: management · production · staging · sandbox
- **tier**: `01-foundation` → `02-platform` → `03-workloads/<product>` (apply in that order)

## File naming inside a root

`backend.tf`, `providers.tf`, `variables.tf`, `outputs.tf`, `main.tf`, plus
topic files (`dns.tf`, `secrets.tf`, …). `data.tf` holds
`terraform_remote_state` lookups where a root consumes another tier's
outputs. `README.md` carries terraform-docs markers. Scaffold new AWS roots
with `scripts/new-root.sh <path>` (skill: `new-terraform-root`); never
hand-write a `backend.tf`.

## State & backend

S3 backend with native locking: bucket `<prefix>-tfstate-<env>` in
`us-east-1`, key mirroring the path below the env
(`<region>/<tier>[/<workload>]/terraform.tfstate`, or `<root>/terraform.tfstate`
for account-level roots), `use_lockfile = true`, `encrypt = true`. Azure
roots use the `azurerm` backend from `azure/bootstrap`. Cross-tier wiring is
via `terraform_remote_state`; see
[example-app/data.tf](aws/accounts/staging/eu-west-1/03-workloads/example-app/data.tf).
Higher tiers read lower ones, never the reverse.

## Versions & providers

`required_version >= 1.14.0` (`.terraform-version` pins the exact version,
matched by `TF_VERSION` in each workflow). Providers and registry modules
are pinned with `~>` (e.g. `aws ~> 6.0`). Don't introduce exact pins or
unpinned providers. To exclude one broken release, add `!= X.Y.Z` to the
constraint (see [docs/runbooks/provider-regression.md](docs/runbooks/provider-regression.md)).

## Conventions to apply when editing `.tf`

This repo vendors Anton Babenko's Terraform skill at
[.claude/skills/terraform-skill/](.claude/skills/terraform-skill/SKILL.md);
Claude auto-loads it. Apply its conventions, with the repo-specific rules
below taking **precedence** where they conflict:

- **Resource naming**: descriptive labels (`aws_iam_role.api_task`); `this`
  only for true singletons; never generic `main`/`bucket`. Renaming an
  existing resource needs a `moved {}` block
  ([runbook](docs/runbooks/renaming-resources.md)).
- **Variables**: always `description` + explicit `type`; `nullable = false`
  on scalars that have a default and no meaningful "unset"; `validation` for
  enumerated/constrained values; `sensitive = true` for any secret-bearing
  input.
- **Outputs**: always `description`. Mark secrets `sensitive = true`, **but
  check consumers first**: outputs are read across tiers via remote state,
  and flipping one to sensitive cascades downstream and can error if
  re-exported non-sensitively.
- **Collections**: `for_each` (stable addressing) over `count` for lists;
  reserve `count` for on/off toggles.
- **Tags (AWS)**: rely on the provider `default_tags` block, which must set
  all of `ManagedBy`, `Repository`, `Environment`, `Region`, `Product`, `Tier`
  (enforced by `scripts/check-required-tags.sh`). Add resource-level tags only
  for extra metadata. Azure has no `default_tags`: use a `local.tags` map on
  every resource.
- **Modules**: before using a module input or output, read the module's real
  `variables.tf` / `outputs.tf` under `.terraform/modules/` (after
  `terraform init -backend=false`). Don't guess names from memory.
- **Secrets**: never hardcode; never put secrets in root variables or tfvars.
  Use AWS Secrets Manager + KMS, named per [aws/SECRETS.md](aws/SECRETS.md)
  (`<env>/<product>/<runtime>/<consumer>/[<category>/]<leaf>`, general CMK).
  `sensitive = true` only masks *display*: the value still lives in state.
  Prefer `*_wo` write-only arguments, or keep secret material out of Terraform
  entirely (seed `{}` + `ignore_secret_changes`).
- **Immutable arguments**: names of security groups, load balancers, Secrets
  Manager secrets, subnet CIDRs and the like force replacement when changed.
  Check the plan for `# forces replacement` before proposing such edits.

## Guardrails: must pass before commit

`pre-commit` ([.pre-commit-config.yaml](.pre-commit-config.yaml)) runs
`terraform_fmt`, `terraform_validate`, `terraform_tflint`
([.tflint.hcl](.tflint.hcl)), `terraform_docs`
([.terraform-docs.yml](.terraform-docs.yml); injects each root's README
table), `terraform_checkov`, `terraform_trivy` ([.trivyignore](.trivyignore)),
gitleaks, shellcheck, actionlint, the required-tags gate, plus
`no-commit-to-branch` (blocks `main`) and `detect-private-key`. **Do not add
new checkov/trivy suppressions without an inline comment justifying them**;
prefer `#checkov:skip=<ID>:<reason>` / `#trivy:ignore:<ID>` on the one
resource over a repo-wide entry.

- Local: `pre-commit run --all-files`.
- CI ([terraform-plan.yml](.github/workflows/terraform-plan.yml)) re-runs
  pre-commit + `terraform plan` per changed root on PRs. Apply is via PR
  comment `terraform apply <dir>` after approval
  ([terraform-chatops.yml](.github/workflows/terraform-chatops.yml)).
- Before recommending an apply, reconcile the plan with the diff: chatops
  applies the **whole root**, so drift or someone else's unmerged change rides
  along (skill: `review-terraform-plan`).

## Tests

Automated Terraform tests (`terraform test`, Terratest) belong in the modules
repository, next to the reusable code. Roots here are gated by
`terraform validate` + the CI `terraform plan` matrix: **don't add native
`.tftest.hcl` suites to roots.** See [CONTRIBUTING.md](CONTRIBUTING.md).

## Known gaps vs the vendored skill

Conscious, tracked deviations from terraform-skill, listed so this guidance
doesn't silently contradict the skill it ships. Each is an **open decision**,
not a settled waiver.

- **`.terraform.lock.hcl` is gitignored** ([.gitignore](.gitignore)). The
  skill recommends committing lockfiles for reproducible provider resolution;
  today CI resolves providers fresh against the `~>` constraints, so a bad
  provider release can break every plan the day it ships. To adopt the skill:
  `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64` per
  root, commit the locks, then add `-lockfile=readonly` to CI `init`. Do
  **not** just delete the gitignore line: that commits single-platform locks
  and reds CI on the other platform.
- **Apply re-plans instead of applying a reviewed plan artifact.** The chatops
  apply runs `terraform apply -auto-approve` rather than the PR plan's saved
  `tfplan`. Mitigated by the approval gate, the head-SHA check, and the apply
  diff posted back to the PR. Promoting the saved plan would close the
  plan→apply window, but plan files hold unmasked values and workflow
  artifacts are downloadable by anyone with read access, so it needs
  encryption first.
- **One admin CI role per account.** PR plans and applies assume the same
  `AdministratorAccess` role (the trust policy is narrowed to exact OIDC
  subjects, and environments are restricted to the default branch). The
  skill's stronger shape is a read-only plan role (trusting `pull_request`)
  and a separate apply role (trusting only `environment:<name>`).
- **Security scans gate the plan path; the apply path checks their result.**
  checkov/trivy/tflint run in "Pre-commit Checks"; chatops apply refuses
  unless that check is green on the head commit, but doesn't re-run them.
- **Registry modules use `~>` ranges**, not exact pins (the skill wants exact
  pins for production modules). `CKV_TF_1` is skipped for the same reason.

## What NOT to do

- Don't create a local `modules/` directory or inline upstream modules.
- Don't commit secrets, `*.tfvars` with sensitive values, `*.pem`/`*.key`, or
  state files.
- Don't `terraform apply`, `destroy`, `import` or edit state locally against
  shared environments (Claude is denied these in `.claude/settings.json`). Use
  the CI chatops flow. Chatops takes `plan`/`apply` only, so teardown is
  "remove the resource blocks from config → review the plan's *will be
  destroyed* list → `terraform apply <dir>`", never a local destroy. Only the
  one-time bootstrap (SETUP.md) runs from a laptop.
- Don't delete or move a root directory without a teardown or state migration
  first ([runbook](docs/runbooks/removing-a-root.md)); CI fails the PR if you do.
- Don't commit directly to `main`.
- Don't add native test suites to roots (see Tests).
