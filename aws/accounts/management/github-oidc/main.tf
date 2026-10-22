# GitHub OIDC: CI/CD authentication for this account
#
# Creates the GitHub Actions OIDC provider and the role this repo's workflows
# assume (no long-lived AWS keys anywhere). Apply it once by hand while
# bootstrapping the account (docs/getting-started.md); CI manages it after.
#
# The trust policy lists the exact OIDC `sub` claims the workflows present,
# instead of a `repo:<owner>/<repo>:*` wildcard that would let any branch,
# tag or environment assume the role:
#   pull_request              PR plans (terraform-plan.yml, github-roots-plan.yml)
#   ref:refs/heads/<default>  drift checks + chatops `terraform plan`
#                             (schedule / issue_comment run on the default branch)
#   environment:<name>        chatops `terraform apply` jobs (one per GitHub Environment)

locals {
  github_oidc_subjects = concat(
    [
      "repo:${var.github_repository}:pull_request",
      "repo:${var.github_repository}:ref:refs/heads/${var.default_branch}",
    ],
    [for env in var.github_environments : "repo:${var.github_repository}:environment:${env}"],
  )
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_oidc_subjects
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name                 = var.ci_role_name
  description          = "Assumed by ${var.github_repository} GitHub Actions to plan/apply Terraform"
  assume_role_policy   = data.aws_iam_policy_document.github_actions_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  #checkov:skip=CKV_AWS_274:The CI role applies arbitrary Terraform in this account, so it needs admin. Access is gated by the OIDC subject allow-list above plus the chatops approval gate; see "Known gaps" in CLAUDE.md for the plan/apply role split.
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
