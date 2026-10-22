output "ecr_repository_url" {
  description = "Push the api image here."
  value       = module.ecr_api.repository_url
}

output "data_bucket_name" {
  description = "Application data bucket."
  value       = module.data_bucket.s3_bucket_id
}

output "app_config_secret_arn" {
  description = "ARN of the app config secret (set its value out-of-band)."
  value       = module.app_config_secret.secret_arn
}

output "log_group_name" {
  description = "Log group for the api containers (awslogs driver target)."
  value       = aws_cloudwatch_log_group.api.name
}

output "task_role_arn" {
  description = "IAM role for the api task definition's taskRoleArn."
  value       = aws_iam_role.api_task.arn
}
