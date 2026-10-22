# CI/CD internals

How the workflows, composite actions and cloud trust fit together, and why
each gate exists. For setup see [SETUP.md](../SETUP.md); for the day-to-day
flow see [CONTRIBUTING.md](../CONTRIBUTING.md).

## Workflows

| Workflow | Trigger | Jobs |
|----------|---------|------|
| [terraform-plan.yml](../.github/workflows/terraform-plan.yml) | `pull_request` | Pre-commit Checks · Required Tags · Detect Changes · Security Scan (SARIF) · `Plan: <dir>` per root per cloud · **plan-summary** |
| [terraform-chatops.yml](../.github/workflows/terraform-chatops.yml) | `issue_comment` on a PR | Parse Command · Detect Changes · Check PR Approval (apply only) · `Plan:`/`Apply: <dir>` · Status |
| [terraform-drift.yml](../.github/workflows/terraform-drift.yml) | weekdays 06:00 UTC, manual | Discover roots · `Drift: <dir>` per root |
| [github-roots-plan.yml](../.github/workflows/github-roots-plan.yml) | `pull_request` on `github/**` | `github-plan: <dir>` |

Composite actions in [.github/actions/](../.github/actions/):

| Action | Purpose |
|--------|---------|
| `split-roots` | Split detected roots by cloud; drop clouds whose `CI_<CLOUD>_ENABLED` isn't `true` |
| `resolve-aws-role` | Root path → account role ARN + environment label |
| `resolve-azure-subscription` | Root path → subscription + environment; exports `ARM_SUBSCRIPTION_ID` |
| `tf-modules-token` | GitHub App token for private `git::` modules (no-op without secrets) |
| `install-precommit-tools` | Pinned, checksum-verified tflint / trivy / terraform-docs / checkov |
| `post-tf-comment` | Plan/apply PR comments and the drift-issue lifecycle |
| `tf-drift-classify` | Tell real drift from output-only / refresh-only plan noise |

## Root discovery

[`scripts/detect-changes.sh`](../scripts/detect-changes.sh) is the single
source of truth for which roots CI touches:

- A root is a directory containing `backend.tf`. A changed file maps to the
  nearest ancestor root.
- `aws/policies/**` changes map to `aws/organization`.
- Excluded: `aws/bootstrap`, `azure/bootstrap`, `github/*`, and any root with
  a `.ci-skip` marker. `--check <dir>` answers the same question for chatops.
- A root whose `backend.tf` existed on the base branch but is gone at HEAD
  **fails the PR**: its resources and state would be orphaned
  ([removing-a-root.md](runbooks/removing-a-root.md)).
- Output is sorted, so `01-foundation` < `02-platform` < `03-workloads`. The
  apply matrix runs with `max-parallel: 1` in that order.

## Required checks and the false-green trap

Branch protection requires two **stable** check names: `Pre-commit Checks`
and `plan-summary`. The per-root `Plan: <dir>` names change every PR and
can't be required, so `plan-summary` aggregates them. It fails when:

- pre-commit, required-tags or detect-changes didn't succeed;
- any plan job failed or was cancelled;
- detect-changes reported roots but **no** plan job ran (the false green a
  mis-wired `if:` would otherwise produce).

The workflow's `paths:` filter includes `*.md`, `**/*.md` and every guardrail
config. Without that, a docs-only PR never triggers the workflow, the
required checks never report, and the PR sits at "Expected: waiting for
status" forever.

## ChatOps

```text
terraform plan  [dir]     # first line only; notes may follow below
terraform apply [dir]     # omit dir = every root the PR changes
```

Gates, in order:

1. **Who**: `author_association` pre-filter, then an API check for real write
   or admin permission. Unauthorized commenters never reach OIDC credentials.
2. **What**: the command matches `^terraform (plan|apply)( <path>)?$` with a
   character allow-list and no `..`; the directory must be a CI root.
3. **Checks** (apply): `plan-summary` and `Pre-commit Checks` must be green on
   the PR's *exact* head SHA. Running checks are waited for (up to 15 min).
4. **Freshness** (apply): if the PR head moved after the comment, the apply is
   refused rather than applying a commit the PR no longer contains.
5. **Review** (apply): an `APPROVED` review on the head SHA by someone other
   than the commenter. Admins may proceed without one; the workflow posts an
   "admin override" comment so it's audited.
6. **Environment** (apply): the job runs in the GitHub Environment for that
   root (`production`, `staging`, `sandbox`, `organization`, `datadog`), which
   can add required reviewers and is part of the OIDC subject.

Applies are serialized per root (`terraform-<cloud>-<dir>` concurrency group,
shared with drift) and per PR (`terraform-apply-pr-<n>`, never cancelled).
Reactions on the comment report progress: 👀 received, 🚀 all succeeded,
👎 something failed, 😕 nothing ran (blocked or rejected).

**Concurrency namespaces must stay distinct.** Concurrency groups are
repository-wide. The plan workflow uses `cancel-in-progress: true` (a new push
supersedes a stale plan); if it ever shared a group name with an apply, a push
would cancel an in-flight `terraform apply` and strand the state lock. The
apply groups use `cancel-in-progress: false`.

The apply re-plans rather than applying the PR's saved plan (see "Known gaps"
in [CLAUDE.md](../CLAUDE.md)), and it applies the **whole root** at the head
commit. Anything else pending in that root ships too, so review the plan
against the diff.

## Drift detection

Every CI root is planned with `-detailed-exitcode -lock=false` (read-only, so
a cancelled run can't strand a lock). Exit code 2 alone isn't trusted:
`tf-drift-classify` inspects the JSON plan and reports drift only when a
managed resource has a create/update/delete/replace, ignoring output-only and
refresh-only diffs.

Issue lifecycle (`post-tf-comment`), one issue per root and kind:

- `Drift detected: <dir>`: the body is refreshed silently each run; a
  notifying comment is added only when the *fingerprint* (hash of addresses +
  actions) changes.
- `Drift check failing: <dir>`: auth/init/plan errors. A check that can't run
  isn't drift-free, and a red scheduled run is easy to miss.
- Both close automatically once the root plans clean.

## Cloud authentication

No long-lived cloud credentials exist in GitHub. Jobs request a GitHub OIDC
token (`id-token: write`) and exchange it:

| Context | OIDC `sub` claim | Used by |
|---------|------------------|---------|
| PR plan | `repo:<owner>/<repo>:pull_request` | terraform-plan.yml, github-roots-plan.yml |
| Default branch | `repo:<owner>/<repo>:ref:refs/heads/main` | drift, chatops `plan` |
| Environment | `repo:<owner>/<repo>:environment:<name>` | chatops `apply` |

Each AWS account's role
([github-oidc](../aws/accounts/staging/github-oidc/main.tf)) trusts exactly
those subjects for that account's environments, with `StringEquals` (no
wildcards). The Azure CI identity
([azure/bootstrap/identity.tf](../azure/bootstrap/identity.tf)) has one
federated credential per subject. Restrict every GitHub Environment to the
default branch (SETUP.md step 7), or a PR could add `environment:` to a job
and obtain an apply subject.

| Root path | AWS role secret | Apply environment |
|-----------|-----------------|-------------------|
| `aws/accounts/production/**` | `AWS_ROLE_PRODUCTION` | `production` |
| `aws/accounts/staging/**` | `AWS_ROLE_STAGING` | `staging` |
| `aws/accounts/sandbox/**` | `AWS_ROLE_SANDBOX` | `sandbox` |
| `aws/organization`, `aws/accounts/management/**` | `AWS_ROLE_MANAGEMENT` | `organization` |
| `datadog/**` (state in management) | `AWS_ROLE_MANAGEMENT` | `datadog` |
| `azure/<env>/**` | `AZURE_*` | `<env>` |

## Enabling clouds

`split-roots` drops a cloud's roots unless its repository variable
(`CI_AWS_ENABLED`, `CI_AZURE_ENABLED`, `CI_DATADOG_ENABLED`) is `true`:

- PR plans and drift skip them with a warning (plan-summary stays green), so a
  fresh template with no credentials is green.
- ChatOps **fails** with a comment: an explicit command must never read as
  success.

Once a cloud is enabled, a missing or wrong secret fails loudly.

## Supply chain

- Every third-party action is pinned to a full commit SHA (version in a
  trailing comment); Dependabot opens weekly grouped bumps for workflows and
  composite actions, and for the pip-pinned checkov/pre-commit.
- tflint and trivy install through their official SHA-pinned setup actions;
  terraform-docs is checksum-verified. These pins and the pre-commit hook
  `rev`s (frozen SHAs) are bumped by hand.
- `checkout` uses `persist-credentials: false` everywhere; `${{ }}`
  expressions reach scripts only through `env:`.

## Caching

- Provider plugins: cached per root, keyed on that root's `providers.tf`, with
  **no** `restore-keys` fallback. A prefix fallback restores another root's
  cache, init adds this root's providers, and the save archives the union, so
  the cache only ever grows until it fills the runner disk.
- Pre-commit validates many roots in one job, so it disables the shared plugin
  cache (gitignored lockfiles make cached providers fail checksum checks) and
  frees ~25 GB of preinstalled SDKs first.
- tflint rulesets are cached and fetched with `GITHUB_TOKEN`: unauthenticated,
  the 60 requests/hour limit makes `tflint --init` panic.
