output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.this.id
}

output "cluster_name" {
  description = "ECS cluster name — used by autoscaling and CI/CD"
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "ECS service name — used by autoscaling and CI/CD"
  value       = aws_ecs_service.this.name
}

output "task_security_group_id" {
  description = "Security group ID attached to ECS tasks"
  value       = aws_security_group.task.id
}

output "task_definition_arn" {
  description = "ARN of the active task definition revision"
  value       = aws_ecs_task_definition.this.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for ECS task logs"
  value       = aws_cloudwatch_log_group.this.name
}
