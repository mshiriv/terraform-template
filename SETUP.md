# Setup: from template to first apply

Every step needed to turn this template into a working infrastructure repo:
your names in the code, AWS accounts bootstrapped, GitHub configured, and CI
planning and applying. Do the steps in order. The optional clouds (Azure,
Datadog) and extras come after the core path.

Expect about an hour for the core path (steps 1 to 9), most of it waiting on
AWS account creation.

| # | Step | Where | Required |
|---|------|-------|----------|
| 1 | [Create your repository](#1-create-your-repository) | GitHub | yes |
| 2 | [Install the local tooling](#2-install-the-local-tooling) | laptop | yes |
| 3 | [Initialize the template](#3-initialize-the-template) | laptop | yes |
| 4 | [Trim what you don't need](#4-trim-what-you-dont-need) | laptop | yes |
| 5 | [Bootstrap AWS](#5-bootstrap-aws) | laptop + AWS | yes (AWS) |
| 6 | [Add repository secrets](#6-add-repository-secrets) | GitHub | yes |
| 7 | [Create GitHub Environments](#7-create-github-environments) | GitHub | yes |
| 8 | [Lock down the repository](#8-lock-down-the-repository) | GitHub | yes |
| 9 | [Enable CI and ship the first change](#9-enable-ci-and-ship-the-first-change) | GitHub | yes |
| 10 | [Azure](#10-azure-optional) | laptop + Azure | optional |
| 11 | [Datadog](#11-datadog-optional) | Datadog + GitHub | optional |
| 12 | [Private module repository](#12-private-module-repository-optional) | GitHub | optional |
| 13 | [Plans for the github/ roots](#13-plans-for-the-github-roots-optional) | GitHub | optional |
| 14 | [Claude Code](#14-claude-code) | laptop | nothing to do |

Reference: [all secrets and variables](#reference-secrets-and-variables) ·
[troubleshooting](#troubleshooting).

---

## 1. Create your repository

1. On the template's GitHub page, click **Use this template → Create a new
   repository**.
2. Make it **private**. CI posts full `terraform plan` output as PR comments
   and drift issues. Terraform masks sensitive values, but plans still expose
   account IDs, ARNs, IPs, CIDRs and resource names. On a public repository
   anyone can read them (and download workflow logs).
3. Clone it:

   ```bash
   git clone git@github.com:<owner>/<repo>.git && cd <repo>
   ```

You need **admin** on the repository for steps 6 to 8.

## 2. Install the local tooling

| Tool | Version | Why |
|------|---------|-----|
| Terraform | `.terraform-version` (use [tfenv](https://github.com/tfutils/tfenv) or [mise](https://mise.jdx.dev)) | everything |
| [pre-commit](https://pre-commit.com) | 4.x | runs the guardrails locally |
| tflint, terraform-docs **v0.24.0**, checkov, trivy | see `.github/actions/install-precommit-tools` | invoked by the pre-commit hooks |
| AWS CLI v2, jq | any recent | `scripts/bootstrap.sh` |
| [gh](https://cli.github.com) | any recent | the `gh secret` / `gh variable` commands below |

Pin terraform-docs to the CI version: other versions render the README tables
differently and the `terraform_docs` hook fights your changes.

```bash
brew install tfenv pre-commit tflint terraform-docs checkov trivy awscli jq gh   # macOS example
tfenv install && tfenv use
pre-commit install
```

## 3. Initialize the template

The template ships with **placeholders that are deliberately invalid** as real
names: an upper-case state-bucket prefix (illegal in S3 bucket names) and a
GitHub owner containing underscores (illegal on GitHub). Until you replace
them, nothing can write state to someone else's bucket or trust someone
else's repository.

```bash
git switch -c chore/init-template

scripts/init-template.sh \
  --prefix acme \
  --github-repo acme-corp/infrastructure \
  --region us-west-2 \
  --azure-location eastus \
  --codeowners @acme-corp/platform-team

git diff --stat
```

| Option | Meaning |
|--------|---------|
| `--prefix` | Lowercase, 2-15 letters/digits. Buckets become `acme-tfstate-<env>`, accounts `acme-<env>`. |
| `--github-repo` | This repository, `owner/name`. Trusted by the CI roles' OIDC policies. |
| `--region` | Primary AWS workload region. Omit to keep the template default (Ireland). |
| `--azure-location` | Primary Azure location. Only matters if you keep `azure/`. |
| `--codeowners` | Owner for every CODEOWNERS path. Use `@your-username` for a personal repo. |

Run `scripts/init-template.sh --help` for every option, or add `--dry-run`
first. The script rewrites every tracked file except itself and the vendored
skill, renames the region directories, and warns about anything it couldn't
replace.

Then check by hand:

- **Availability zones.** `aws/accounts/*/<region>/01-foundation/main.tf` pins
  AZ names (`<region>a`, `<region>b`, ...). Confirm they exist for your
  accounts: `aws ec2 describe-availability-zones --region <region>`.
- **CIDR plan.** Each foundation uses its own `/16` (production `10.0.0.0/16`,
  staging `10.1.0.0/16`). Change them now if they clash with your on-prem or
  other cloud networks; changing a VPC CIDR later means rebuilding it.
- **Region restriction.** `aws/policies/scp/baseline.json` denies every region
  except your primary region and `us-east-1`. Add any others you need.

Commit, push, open a PR, and merge it. Every cloud's CI is still disabled, so
the PR runs only the pre-commit guardrails, which must pass.

## 4. Trim what you don't need

The template covers AWS, Azure, Datadog and GitHub. Delete what you won't use
**now**, before anything is applied (removing a root later needs a teardown):

| Not using | Delete |
|-----------|--------|
| Azure | `azure/` |
| Datadog | `datadog/` |
| A sandbox account | `aws/accounts/sandbox/`, its entry in `aws/organization/terraform.tfvars`, its provider + module pair in `aws/bootstrap/` |
| The example workload | keep it until your first real product is onboarded, then remove `aws/accounts/staging/<region>/03-workloads/example-app/` |

The workflows handle a missing cloud tree without changes. Remove `azure/production/`
and Azure-related CODEOWNERS lines too if you drop Azure.

## 5. Bootstrap AWS

The bootstrap is the only thing applied from a laptop. After it, every change
goes through PR → plan → approval → chatops apply.

### 5.1 Prepare the management account

You need one AWS account to be the **management (payer) account** of the
organization. It runs no workloads.

1. Secure the root user: strong password, MFA, no access keys.
2. Create an admin identity for yourself (IAM Identity Center user with
   `AdministratorAccess`, or a temporary IAM user you delete after bootstrap)
   and configure the CLI:

   ```bash
   aws configure sso            # or: aws configure --profile management-admin
   export AWS_PROFILE=management-admin
   aws sts get-caller-identity  # must show the management account
   ```

3. **Existing organization?** Add `import` blocks for the organization (and
   any existing member accounts) at the top of `aws/organization/main.tf`,
   as its header comment describes. A fresh account needs nothing: the first
   apply creates the organization.

### 5.2 Fill in the organization settings

Edit `aws/organization/terraform.tfvars`:

- `accounts`: one **unique** email per member account (plus-addressing works:
  `aws+production@yourcompany.com`). The variable rejects the template's
  `example.com` addresses.
- `monthly_budgets_usd` and `budget_alert_emails`.
- Leave `enable_sso = false` for now (step 9.4 turns it on).

Commit this to your branch. The bootstrap reads the files from your working
copy.

### 5.3 Run the bootstrap

```bash
# Optional safety net: refuse to run against any other account.
export EXPECTED_MANAGEMENT_ACCOUNT_ID=111111111111

scripts/bootstrap.sh
```

The script is idempotent and asks before every apply:

| Step | What it does |
|------|--------------|
| 0 | Creates and hardens the management state bucket `<prefix>-tfstate-management` (versioning, SSE-KMS, public access block, TLS-only policy, lifecycle). This is the only resource created outside Terraform. |
| 1 | Applies `aws/organization`: organization, OUs, member accounts, SCPs, tag policy, budgets. Account creation takes a few minutes per account. |
| 2 | Applies `aws/bootstrap`: a state bucket and CMK in every member account. |
| 3 | Applies `aws/accounts/management/github-oidc`: the CI role in the management account. |
| 4 | For each member account, assumes `OrganizationAccountAccessRole` and applies `aws/accounts/<env>/github-oidc`. |

It finishes by printing the four role ARNs for step 6. Re-run it at any time;
unchanged steps are skipped.

> **SCPs apply immediately.** The strict SCP (deny root user, protect security
> services) attaches to the Workloads OU in step 1. If you rely on the root
> user of a member account for anything, do it before bootstrapping.

## 6. Add repository secrets

Settings → Secrets and variables → **Actions** → New repository secret, or
with `gh`:

```bash
gh secret set AWS_ROLE_MANAGEMENT --body "arn:aws:iam::<mgmt-id>:role/github-actions-terraform"
gh secret set AWS_ROLE_PRODUCTION --body "arn:aws:iam::<prod-id>:role/github-actions-terraform"
gh secret set AWS_ROLE_STAGING    --body "arn:aws:iam::<staging-id>:role/github-actions-terraform"
gh secret set AWS_ROLE_SANDBOX    --body "arn:aws:iam::<sandbox-id>:role/github-actions-terraform"
```

These are role ARNs, not credentials: CI exchanges a GitHub OIDC token for
short-lived credentials, and the role only trusts this repository's
pull-request, default-branch and environment contexts. There are no AWS
access keys anywhere.

Optional: `gh variable set AWS_REGION --body <region>` sets the region CI uses
for STS calls (default `us-east-1`; providers set their own regions).

## 7. Create GitHub Environments

Chatops applies run inside a GitHub Environment, and the environment's name is
part of the OIDC subject each AWS role trusts. Create these under
Settings → **Environments** (names must match exactly):

| Environment | Used by applies to | Suggested protection |
|-------------|--------------------|----------------------|
| `production` | `aws/accounts/production/**`, `azure/production/**` | required reviewers |
| `staging` | `aws/accounts/staging/**`, `azure/staging/**` | none |
| `sandbox` | `aws/accounts/sandbox/**` | none |
| `organization` | `aws/organization`, `aws/accounts/management/**` | required reviewers |
| `datadog` | `datadog/**` | none |

For **every** environment set **Deployment branches and tags → Selected
branches → your default branch only**. This is a security control, not
housekeeping. Chatops runs on `issue_comment`, which always executes from the
default branch, so it still works. Without the restriction, a PR that edits a
workflow to add `environment: production` to a job would receive the
production OIDC subject and could assume the production role.

Required reviewers on environments need a paid plan for private repositories
(GitHub Team / Enterprise). Without one, the chatops approval gate (an
approving review by someone other than the person applying) is still
enforced.

## 8. Lock down the repository

Settings → **Actions → General**:

- Fork pull request workflows: **Require approval for all external contributors**.
- Workflow permissions: **Read repository contents and packages permissions**
  (every workflow declares the extra permissions it needs).
- Leave **Allow GitHub Actions to create and approve pull requests** unchecked.

**Branch protection.** Require the stable status checks `plan-summary` and
`Pre-commit Checks` on the default branch, block force pushes and deletion,
and require a PR. Two ways:

- **As code (recommended):** apply `github/repo-management` once by hand, as
  its [README](github/repo-management/README.md) describes. For a solo
  maintainer set `required_approving_review_count = 0` and
  `require_code_owner_review = false`, since you can't approve your own PRs.
- **By hand:** Settings → Rules → Rulesets → New branch ruleset targeting the
  default branch, with the same settings.

Do not require the per-root `Plan: <dir>` checks: their names change with
every PR. `plan-summary` aggregates them.

## 9. Enable CI and ship the first change

### 9.1 Turn on AWS CI

```bash
gh variable set CI_AWS_ENABLED --body true
```

Until this is `true`, the workflows skip AWS roots with a warning instead of
failing on missing credentials. That's what kept the template's own CI green.

### 9.2 First PR

Open a PR. Any change that passes the guardrails will do, but docs-only changes
don't trigger plans. On every PR, CI will:

1. run pre-commit (fmt, validate, tflint, terraform-docs, checkov, trivy,
   gitleaks, shellcheck, actionlint) and the required-tags gate;
2. post a `terraform plan` comment for every root the PR changes;
3. report `plan-summary`.

For roots the PR doesn't change, which is all of them on day one, ask for a
plan explicitly by commenting on the PR:

```text
terraform plan aws/accounts/staging/github-oidc
terraform plan aws/accounts/staging/hardening
```

The `github-oidc` roots applied by the bootstrap should plan as **no changes**.
If they don't, stop and find out why before going further.

### 9.3 Apply through chatops

After an approving review, comment on the PR, one root per comment, lower
tiers first:

```text
terraform apply aws/accounts/staging/hardening
terraform apply aws/accounts/staging/<region>/01-foundation
terraform apply aws/accounts/staging/<region>/02-platform
terraform apply aws/accounts/staging/<region>/03-workloads/example-app
```

Each apply re-checks that `plan-summary` and `Pre-commit Checks` are green on
the PR's head commit (waiting up to 15 minutes for in-flight runs), that the
head hasn't moved, and that someone other than you approved it. A repository
admin can apply without an approval; the workflow posts an audited
"admin override" comment. It then posts the apply output. **Merge once every
root is applied**, so `main` matches what is deployed.

Repeat for production and the other accounts' `hardening` roots.

### 9.4 Turn on SSO (recommended)

1. AWS console (management account) → IAM Identity Center → **Enable** (an
   Organization instance).
2. PR: set `enable_sso = true` in `aws/organization/terraform.tfvars`, apply
   `aws/organization`.
3. Add people to the `platform-admins` / `developers` groups in the Identity
   Center console, or connect your IdP over SCIM. People are deliberately not
   managed in this repo.
4. Delete the temporary admin identity from step 5.1.

### 9.5 Drift detection

`terraform-drift.yml` runs on weekdays at 06:00 UTC (and on demand from the
Actions tab). It opens one issue per drifting root and closes it when the root
is clean again. Nothing to configure. Make sure someone watches the `drift`
label.

---

## 10. Azure (optional)

1. Fill `azure/bootstrap/terraform.tfvars`: the subscription that holds state,
   and the subscriptions CI manages keyed by environment.
2. As a tenant admin (Graph write + Owner on those subscriptions):

   ```bash
   az login
   terraform -chdir=azure/bootstrap init
   terraform -chdir=azure/bootstrap apply
   ```

3. Migrate its state into the storage account it just created: swap the
   backend block in `azure/bootstrap/backend.tf` as its comments describe, then
   `terraform -chdir=azure/bootstrap init -migrate-state` and delete the local
   `terraform.tfstate*` files.
4. Secrets: `AZURE_CLIENT_ID` and `AZURE_TENANT_ID` (bootstrap outputs),
   `AZURE_SUBSCRIPTION_STAGING`, `AZURE_SUBSCRIPTION_PRODUCTION`.
5. `gh variable set CI_AZURE_ENABLED --body true`.

Azure roots live at `azure/<env>/<location>/<NN-tier>/` and map to a
subscription by `<env>` (`.github/actions/resolve-azure-subscription`).

## 11. Datadog (optional)

1. Datadog → Organization Settings → Service Accounts → create `terraform-ci`
   (Datadog Admin role) and an application key for it; create an API key.
2. Secrets: `DATADOG_API_KEY`, `DATADOG_APP_KEY`. Use the API key's value, not
   its "Key ID".
3. Set `datadog_api_url` in each Datadog root for your site (default US1).
4. `gh variable set CI_DATADOG_ENABLED --body true`.

Datadog state lives in the management account's bucket, so it uses
`AWS_ROLE_MANAGEMENT` too.

## 12. Private module repository (optional)

Keep reusable modules in a separate repository and consume them by tag:
`git::https://github.com/<owner>/terraform-modules.git//modules/<name>?ref=<name>/v1.2.0`.
For CI to fetch them:

1. Create a GitHub App with **Repository permissions → Contents: Read**,
   install it on the module repository.
2. Secrets: `TF_MODULES_APP_ID`, `TF_MODULES_APP_PRIVATE_KEY`.
3. Variables (only if different from the defaults): `TF_MODULES_OWNER`
   (default: this repo's owner), `TF_MODULES_REPOS` (comma-separated, default
   `terraform-modules`).

With no secrets set the step is a no-op and public registry modules just work.

## 13. Plans for the github/ roots (optional)

`github-roots-plan.yml` posts plans for `github/**` changes. It needs a GitHub
App with **Administration: Read** installed on the managed repositories:

1. Secrets: `TF_GH_APP_ID`, `TF_GH_APP_PRIVATE_KEY`.
2. `gh variable set CI_GITHUB_ROOTS_ENABLED --body true`.

Applies for `github/**` stay manual (see its README): CI never holds an admin
token.

## 14. Claude Code

Nothing to configure. Opening the repo in Claude Code loads:

- `CLAUDE.md`: the repo's conventions and guardrails;
- `.claude/skills/terraform-skill/`: Anton Babenko's Terraform skill (vendored);
- `.claude/skills/new-terraform-root/` and `review-terraform-plan/`: repo
  workflows;
- `.claude/settings.json`: allows read-only Terraform and git commands, **denies**
  `terraform apply/destroy/import/state mv|rm/force-unlock`, and runs
  `terraform fmt` on every `.tf` file Claude edits.

Personal overrides go in `.claude/settings.local.json` (gitignored).

---

## Reference: secrets and variables

**Secrets** (Settings → Secrets and variables → Actions → Secrets):

| Name | Needed for | Value |
|------|-----------|-------|
| `AWS_ROLE_MANAGEMENT` | AWS (org, management, Datadog and github state) | role ARN from bootstrap |
| `AWS_ROLE_PRODUCTION` | AWS production roots | role ARN from bootstrap |
| `AWS_ROLE_STAGING` | AWS staging roots | role ARN from bootstrap |
| `AWS_ROLE_SANDBOX` | AWS sandbox roots | role ARN from bootstrap |
| `AZURE_CLIENT_ID` | Azure | `azure/bootstrap` output `ci_client_id` |
| `AZURE_TENANT_ID` | Azure | `azure/bootstrap` output `tenant_id` |
| `AZURE_SUBSCRIPTION_STAGING` | Azure staging roots | subscription ID |
| `AZURE_SUBSCRIPTION_PRODUCTION` | Azure production roots | subscription ID |
| `DATADOG_API_KEY` | Datadog | API key value |
| `DATADOG_APP_KEY` | Datadog | application key |
| `TF_MODULES_APP_ID` / `TF_MODULES_APP_PRIVATE_KEY` | private git:: modules | GitHub App (Contents: read) |
| `TF_GH_APP_ID` / `TF_GH_APP_PRIVATE_KEY` | github/ root plans | GitHub App (Administration: read) |

**Variables** (same page → Variables):

| Name | Default | Effect |
|------|---------|--------|
| `CI_AWS_ENABLED` | unset | `true` = plan/apply/drift AWS roots |
| `CI_AZURE_ENABLED` | unset | `true` = plan/apply/drift Azure roots |
| `CI_DATADOG_ENABLED` | unset | `true` = plan/apply/drift Datadog roots |
| `CI_GITHUB_ROOTS_ENABLED` | unset | `true` = plan github/ roots on PRs |
| `AWS_REGION` | `us-east-1` | region for CI's STS calls |
| `TF_MODULES_OWNER` | repo owner | owner of the private module repos |
| `TF_MODULES_REPOS` | `terraform-modules` | comma-separated private module repos |

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | The OIDC subject isn't trusted: wrong repo slug, a renamed default branch, or an environment missing from the account's `github_environments` | Compare the job's context with the `github_oidc_subjects` output of that account's `github-oidc` root |
| PR stuck on "Expected: waiting for status" | A required check never ran (the workflow's `paths:` filter didn't match) | Add the path to `terraform-plan.yml` `on.pull_request.paths` |
| `terraform_tflint ... Failed` with a panic | tflint hit the unauthenticated GitHub API rate limit while installing plugins | Locally: `export GITHUB_TOKEN=$(gh auth token)`. CI already passes a token |
| Apply blocked: required checks not green | `plan-summary` or `Pre-commit Checks` failed or is still running on the head commit | Fix and push; the apply waits up to 15 min for running checks |
| `Error acquiring the state lock` | A cancelled run left a lock behind | [docs/runbooks/state-lock-recovery.md](docs/runbooks/state-lock-recovery.md) |
| `Terraform root removed or renamed` in Detect Changes | You deleted a directory with a `backend.tf` | [docs/runbooks/removing-a-root.md](docs/runbooks/removing-a-root.md) |
| Plans skipped with "CI_AWS_ENABLED is not true" | Expected until step 9.1 | `gh variable set CI_AWS_ENABLED --body true` |
