# github / repo-management

The default-branch protection ruleset of this repository, as code: pull
request required, `plan-summary` and `Pre-commit Checks` required (strict:
the branch must be up to date), review threads resolved, no force pushes or
deletion. Requiring those two checks is what makes the chatops apply gate
meaningful.

**Applied out-of-band**, never by the CI matrix: managing a ruleset needs an
admin-scoped GitHub token, and CI deliberately never holds one.
[github-roots-plan.yml](../../.github/workflows/github-roots-plan.yml) posts a
read-only plan on PRs once enabled (SETUP.md step 13).

## Apply

Run as a repository admin, after the management state bucket exists
(SETUP.md step 5):

```bash
export AWS_PROFILE=<management-admin>          # state bucket access
export GITHUB_TOKEN=$(gh auth token)           # or a fine-grained PAT with Administration: write
terraform -chdir=github/repo-management init
terraform -chdir=github/repo-management plan
terraform -chdir=github/repo-management apply
```

## Review model

| Setting | Team (default) | Solo maintainer |
|---------|----------------|-----------------|
| `required_approving_review_count` | `1` | `0` |
| `require_code_owner_review` | `true` | `false` (the only owner can't approve their own PR) |

Even at 0 approvals, the chatops apply gate still requires an approval from
someone else or an audited admin override.

`org_admin_break_glass = true` lets organization admins merge a PR past stuck
checks (never direct pushes). A read-only plan token can't see bypass actors,
so enabling it shows a permanent phantom diff in CI plans. Without it,
break-glass is: an owner disables the ruleset in the UI, merges, re-enables.

## Terraform reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.0 |
| <a name="requirement_github"></a> [github](#requirement\_github) | ~> 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [github_repository_ruleset.default_branch_protection](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_ruleset) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | GitHub organization or user that owns the managed repository. | `string` | `"YOUR_GITHUB_ORG"` | no |
| <a name="input_org_admin_break_glass"></a> [org\_admin\_break\_glass](#input\_org\_admin\_break\_glass) | Add an OrganizationAdmin bypass so org admins can merge a PR while a required check is stuck or CI is down (bypass applies to PR merges only, never direct pushes). Only meaningful for organization-owned repositories. | `bool` | `false` | no |
| <a name="input_repository"></a> [repository](#input\_repository) | Repository (within github\_owner) whose default-branch protection ruleset is managed here. | `string` | `"YOUR_GITHUB_REPO"` | no |
| <a name="input_require_code_owner_review"></a> [require\_code\_owner\_review](#input\_require\_code\_owner\_review) | Require a CODEOWNERS approval. Turn off while the only code owner is also the PR author (they cannot approve their own PR). | `bool` | `true` | no |
| <a name="input_required_approving_review_count"></a> [required\_approving\_review\_count](#input\_required\_approving\_review\_count) | Approving reviews required before a PR can merge. Set 0 for a solo maintainer (a required approval could never be satisfied); the chatops apply gate still requires an approval or an audited admin override. | `number` | `1` | no |
| <a name="input_required_status_checks"></a> [required\_status\_checks](#input\_required\_status\_checks) | Status-check contexts that must pass before merging to the default branch. Use STABLE job names: dynamic matrix leg names (e.g. "Plan: <dir>") vary per PR and cannot be required. | `list(string)` | <pre>[<br/>  "plan-summary",<br/>  "Pre-commit Checks"<br/>]</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ruleset_id"></a> [ruleset\_id](#output\_ruleset\_id) | ID of the branch-protection ruleset managing the default branch. |
| <a name="output_ruleset_name"></a> [ruleset\_name](#output\_ruleset\_name) | Name of the managed branch-protection ruleset. |
<!-- END_TF_DOCS -->
