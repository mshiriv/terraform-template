# Default-branch protection ruleset, managed as code so the review and merge
# requirements are auditable. Requiring the stable "plan-summary" and
# "Pre-commit Checks" status checks is what gates the chatops apply path on a
# green plan plus the checkov/trivy/tflint scans.
resource "github_repository_ruleset" "default_branch_protection" {
  name        = "default-branch-protection"
  repository  = var.repository
  target      = "branch"
  enforcement = "active"

  # Break-glass: org admins may bypass these rules WHEN MERGING A PR (e.g. to
  # land a fix while a required check is stuck). bypass_mode "pull_request"
  # does NOT permit direct pushes; those remain blocked for everyone.
  dynamic "bypass_actors" {
    for_each = var.org_admin_break_glass ? [1] : []
    content {
      actor_id    = 1
      actor_type  = "OrganizationAdmin"
      bypass_mode = "pull_request"
    }
  }

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    non_fast_forward = true
    deletion         = true

    pull_request {
      required_approving_review_count   = var.required_approving_review_count
      require_code_owner_review         = var.require_code_owner_review
      dismiss_stale_reviews_on_push     = var.required_approving_review_count > 0
      require_last_push_approval        = var.required_approving_review_count > 0
      required_review_thread_resolution = true
    }

    required_status_checks {
      strict_required_status_checks_policy = true

      dynamic "required_check" {
        for_each = toset(var.required_status_checks)
        content {
          context = required_check.value
        }
      }
    }
  }
}
