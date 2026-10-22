output "ecs_cluster_name" {
  description = "Shared ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "ecs_cluster_arn" {
  description = "Shared ECS cluster ARN."
  value       = aws_ecs_cluster.this.arn
}

output "ecs_exec_log_group_name" {
  description = "Log group auditing ECS exec sessions."
  value       = aws_cloudwatch_log_group.ecs_exec.name
}
