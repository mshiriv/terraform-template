output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions. Store it as the AWS_ROLE_<ENV> repository secret."
  value       = aws_iam_role.github_actions.arn
}

output "github_oidc_subjects" {
  description = "OIDC subject claims trusted by the CI role (useful when debugging an AssumeRoleWithWebIdentity denial)."
  value       = local.github_oidc_subjects
}
