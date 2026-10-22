output "ruleset_id" {
  description = "ID of the branch-protection ruleset managing the default branch."
  value       = github_repository_ruleset.default_branch_protection.id
}

output "ruleset_name" {
  description = "Name of the managed branch-protection ruleset."
  value       = github_repository_ruleset.default_branch_protection.name
}
