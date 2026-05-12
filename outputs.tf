output "vpc_id" {
  description = "VPC ID"
  value       = try(module.vpc[0].vpc_id, null)
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = try(module.vpc[0].public_subnet_ids, [])
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = try(module.vpc[0].private_subnet_ids, [])
}

output "ecr_repository_url" {
  description = "ECR repository URL — use as image base in task definitions and CI"
  value       = try(module.ecr[0].repository_url, null)
}

output "execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = try(module.iam[0].execution_role_arn, null)
}

output "task_role_arn" {
  description = "ECS task role ARN"
  value       = try(module.iam[0].task_role_arn, null)
}

output "alb_dns_name" {
  description = "ALB DNS name — point your CNAME or Route53 alias here"
  value       = try(module.alb[0].alb_dns_name, null)
}

output "target_group_arn" {
  description = "ALB target group ARN"
  value       = try(module.alb[0].target_group_arn, null)
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = try(module.ecs[0].cluster_name, null)
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = try(module.ecs[0].service_name, null)
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for ECS task logs"
  value       = try(module.ecs[0].cloudwatch_log_group_name, null)
}

output "github_actions_role_arn" {
  description = "Set this as AWS_ROLE_ARN in GitHub repo → Settings → Variables"
  value       = try(module.github_oidc[0].role_arn, null)
}
