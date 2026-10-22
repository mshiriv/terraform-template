# terraform-template

A production-shaped starting point for a multi-cloud **Terraform monorepo**:
repo layout, guardrails, CI/CD with PR-comment ChatOps, drift detection, an
AWS landing-zone bootstrap, and a Claude Code harness. Clone it, run one
script to put your names in, and build your own infrastructure on top.

**Start here: [SETUP.md](SETUP.md)** walks through every step from "Use this
template" to your first reviewed apply.

## What you get

**Repo layout.** A *leaf-config monorepo*: every deployable unit is a small,
self-contained Terraform root with its own state, wired to others through
remote state. Roots are sliced by cloud → account → region → tier
(`01-foundation` → `02-platform` → `03-workloads/<product>`), so a change's
blast radius is obvious from its path. [aws/README.md](aws/README.md) has the
"where does my change go?" decision tree.

**Guardrails** (`pre-commit`, identical locally and in CI):
`terraform fmt` · `terraform validate` · tflint (AWS + AzureRM rulesets) ·
terraform-docs (README tables per root) · checkov · trivy · gitleaks ·
detect-private-key · shellcheck · actionlint · a required-tags gate for the
provider `default_tags` taxonomy · `no-commit-to-branch main`.

**CI/CD** (GitHub Actions, every action SHA-pinned, Dependabot-maintained):

| Workflow | What it does |
|----------|--------------|
| [terraform-plan.yml](.github/workflows/terraform-plan.yml) | On every PR: pre-commit, required tags, SARIF security scan, and a `terraform plan` per changed root, posted as a PR comment. One stable `plan-summary` check for branch protection. |
| [terraform-chatops.yml](.github/workflows/terraform-chatops.yml) | `terraform plan [dir]` / `terraform apply [dir]` as PR comments. Apply is gated on green checks for the exact head commit and an approving review by someone else (admin override is audited), then runs serialized inside a GitHub Environment. |
| [terraform-drift.yml](.github/workflows/terraform-drift.yml) | Weekday plan of every root. One issue per drifting root, refreshed silently while unchanged, closed automatically once clean. Benign output-only diffs are not treated as drift. |
| [github-roots-plan.yml](.github/workflows/github-roots-plan.yml) | Plans for the roots that manage GitHub itself (branch rulesets as code). |

Authentication is OIDC end to end: no cloud keys in GitHub. Each account's
CI role trusts only this repository's PR, default-branch and environment
contexts. Each cloud's CI stays off (skipped, not failing) until you enable it,
so a fresh copy is green from the first commit.

**AWS landing zone** (`aws/`): organization with OUs, member accounts, SCPs
(region restriction, deny root user, protect security services, require
tags), a tag policy, budgets, opt-in IAM Identity Center. Per-account state
buckets on dedicated KMS keys, per-account GitHub OIDC roles, account
hardening (S3 public access block, password policy, EBS encryption, IMDSv2,
snapshot/AMI public-sharing blocks), and an example VPC → ECS cluster →
workload stack. All built from the official `terraform-aws-modules`.

**Also included:** an Azure bootstrap (state storage plus a federated CI
identity with no client secret) with an example VNet root, a Datadog monitor
root, and a GitHub branch-ruleset root.

**Claude Code harness:** [CLAUDE.md](CLAUDE.md) conventions, Anton Babenko's
[terraform-skill](.claude/skills/terraform-skill/SKILL.md) (vendored),
repo-specific skills for [adding a root](.claude/skills/new-terraform-root/SKILL.md)
and [reviewing a plan](.claude/skills/review-terraform-plan/SKILL.md), shared
permissions that **deny** `terraform apply/destroy/import/state` surgery to the
agent, and a hook that runs `terraform fmt` on every file it edits.

## Layout

```
.
├── .claude/                 # Claude Code: settings, hooks, skills
├── .github/
│   ├── actions/             # composite actions shared by the workflows
│   └── workflows/           # plan, chatops, drift, github-roots-plan
├── aws/
│   ├── organization/        # org, OUs, accounts, SCPs, tag policy, budgets, SSO
│   ├── bootstrap/           # per-account state buckets (applied by scripts/bootstrap.sh)
│   ├── policies/            # SCP + tag policy JSON consumed by organization/
│   └── accounts/
│       ├── management/      # github-oidc, hardening
│       ├── production/      # github-oidc, hardening, eu-west-1/01-foundation
│       ├── staging/         # github-oidc, hardening, eu-west-1/{01-foundation,02-platform,03-workloads/example-app}
│       └── sandbox/         # github-oidc, hardening
├── azure/                   # bootstrap + <env>/<location>/<NN-tier>/ roots
├── datadog/                 # monitors (dashboards, SLOs, synthetics alongside)
├── github/repo-management/  # default-branch ruleset as code
├── docs/                    # CI/CD internals, runbooks
└── scripts/                 # init-template, bootstrap, new-root, detect-changes, check-required-tags
```

Every root has the same files: `backend.tf`, `providers.tf`, `variables.tf`,
`main.tf`, `outputs.tf`, optional `data.tf` (remote state) and topic files,
and a `README.md` whose reference table terraform-docs maintains.

## How a change ships

```text
branch → edit a root → pre-commit run --all-files → PR
   → CI posts a plan per changed root + plan-summary
   → review the plan (every change explained by the diff?)
   → approve → comment `terraform apply <dir>` (lower tiers first)
   → apply output posted on the PR → merge
```

Nothing is applied from laptops after the one-time bootstrap. Teardown works
the same way: delete the resource blocks, review the plan's *will be
destroyed* list, apply.

## Docs

| Doc | Read it when |
|-----|--------------|
| [SETUP.md](SETUP.md) | Adopting the template: every bootstrap and configuration step |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Making a change: local setup, PR flow, testing policy |
| [CLAUDE.md](CLAUDE.md) | Conventions (also loaded by Claude Code) and known gaps |
| [aws/README.md](aws/README.md) | Placing a change: decision tree, tiers, naming, tags, CIDR plan |
| [aws/SECRETS.md](aws/SECRETS.md) | Naming and creating Secrets Manager secrets |
| [docs/ci-cd.md](docs/ci-cd.md) | How the workflows, gates and OIDC trust fit together |
| [docs/runbooks/](docs/runbooks/) | State locks, renames, removing a root, provider regressions |

## Requirements

Terraform `>= 1.14` (pinned in [.terraform-version](.terraform-version)),
GitHub Actions, and an AWS account to act as the organization's management
account. Azure and Datadog are optional.

## Credits and license

The vendored [terraform-skill](.claude/skills/terraform-skill/VENDORED.md) is
by Anton Babenko, Apache-2.0. Example roots build on
[terraform-aws-modules](https://github.com/terraform-aws-modules). Everything
else in this repository is released under the [MIT License](LICENSE).
