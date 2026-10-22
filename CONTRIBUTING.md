# Contributing

How to make infrastructure changes in this repo. For repo structure and
Terraform conventions, read [CLAUDE.md](CLAUDE.md) and
[aws/README.md](aws/README.md) first. Setting the repo up for the first time?
See [SETUP.md](SETUP.md).

## Prerequisites

- **Terraform** at the version in [`.terraform-version`](.terraform-version),
  via [`tfenv`](https://github.com/tfutils/tfenv) or [mise](https://mise.jdx.dev).
- **[pre-commit](https://pre-commit.com/)** plus the tools it drives: `tflint`,
  `terraform-docs`, `checkov`, `trivy`. Pin **`terraform-docs`** to the version
  in [install-precommit-tools](.github/actions/install-precommit-tools/action.yml):
  other versions render the README tables differently and the `terraform_docs`
  hook will fight your changes.
- Read access to your private modules repository, if roots use one.
- Cloud access (AWS SSO / aws-vault, `az login`) only for local, read-only
  `plan`s. Day to day you shouldn't need it: CI does the planning.

## One-time setup

```bash
pre-commit install          # installs the git hook
pre-commit run --all-files  # sanity-check your environment
```

If the tflint hook panics while installing plugins, you've hit GitHub's
unauthenticated API rate limit: `export GITHUB_TOKEN=$(gh auth token)`.

## Making a change

1. **Branch off `main`**. Direct commits to `main` are blocked by the
   `no-commit-to-branch` hook.
   ```bash
   git switch -c <type>/<short-description> main
   ```
2. **Edit the right root.** Use the decision tree in
   [aws/README.md](aws/README.md); keep changes within one root per concern
   where possible. New root? `scripts/new-root.sh <path>`.
3. **Follow the conventions** in [CLAUDE.md](CLAUDE.md): descriptive resource
   names, documented/typed/validated variables, `for_each` over `count`,
   `default_tags`, secrets in Secrets Manager (never in variables or tfvars),
   `moved {}` for renames.
4. **Run the guardrails locally:**
   ```bash
   pre-commit run --all-files
   ```
   This runs fmt, validate, tflint, terraform-docs (regenerates each root's
   README table), checkov, trivy, gitleaks, shellcheck, actionlint and the
   required-tags gate. Fix everything before pushing. **Never add a new
   checkov/trivy suppression without an inline comment justifying it.**
5. **Open a PR.** CI ([terraform-plan.yml](.github/workflows/terraform-plan.yml))
   re-runs pre-commit and posts a `terraform plan` for each changed root. Fill
   in the PR template's plan-review checklist.
6. **Apply after approval** via a PR comment, `terraform apply <dir>`, handled
   by [terraform-chatops.yml](.github/workflows/terraform-chatops.yml). Tiers
   apply in order (`01` → `02` → `03`), staging before production. Do **not**
   apply shared environments from your laptop. The command must be the
   comment's first line; anything below it (e.g. the diff you expect) is
   ignored. If the PR's checks are still running, the apply waits up to 15
   minutes for them.
7. **Merge once every affected root is applied**, so `main` always matches
   what's deployed.

Weekday drift is detected by
[terraform-drift.yml](.github/workflows/terraform-drift.yml), which keeps one
issue per root: `Drift detected: <dir>` when live state diverges from code,
`Drift check failing: <dir>` when the check itself errors. Each issue body
always shows the latest output; a new comment (and notification) is posted
only when the drift changes, and the issue closes itself once the root is
clean.

## Testing

**Automated Terraform tests belong in the modules repository**, where reusable
modules are developed (native `terraform test` / Terratest).

Roots in *this* repo are **compositions**, not modules. They are gated by:
- `terraform validate` (pre-commit, every root), and
- the CI `terraform plan` matrix (per changed root on every PR).

**Do not add native `.tftest.hcl` suites to roots here**: a plan-only test
would just duplicate the CI plan. If a root grows logic worth unit-testing,
that logic almost certainly belongs in a module.

## Secrets & sensitive data

- Secrets live in **AWS Secrets Manager** (KMS-encrypted), named per
  [aws/SECRETS.md](aws/SECRETS.md). Never put a secret in a root `variable`,
  an output, or a committed `*.tfvars`.
- `*.pem` / `*.key` and `*.tfstate*` are git-ignored; keep it that way.
- The `detect-private-key` and gitleaks hooks are a backstop, not a license
  to be careless.

## Changing the pipeline itself

Workflow and composite-action changes are linted by actionlint and still need
the required checks to pass. Keep third-party actions pinned to a full commit
SHA with the version in a trailing comment (Dependabot bumps them weekly).
Never interpolate `${{ ... }}` expressions straight into a `run:` script: pass
them through `env:`.
