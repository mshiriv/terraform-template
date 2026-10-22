# Platform: runtime shared by every workload in this account/region
#
# Example contents: an ECS cluster on Fargate (no cost while idle). Replace or
# extend with whatever your workloads share: an EKS cluster, Aurora, a cache,
# a shared load balancer, observability agents. Rule of thumb: if deleting one
# product would leave it in use by another, it belongs here; if not, it
# belongs in that product's 03-workloads root.

resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "/aws/ecs/${var.environment}/exec"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.kms_key_arns["logs"]
}

resource "aws_ecs_cluster" "this" {
  name = var.environment

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  # `aws ecs execute-command` sessions are encrypted with the general CMK and
  # audited to the log group above.
  configuration {
    execute_command_configuration {
      kms_key_id = local.kms_key_arns["general"]
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_exec.name
      }
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}
