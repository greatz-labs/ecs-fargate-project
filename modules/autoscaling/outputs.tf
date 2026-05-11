output "autoscaling_target_resource_id" {
  description = "Scalable target resource ID (service/{cluster}/{service})"
  value       = try(aws_appautoscaling_target.this[0].resource_id, null)
}

output "cpu_policy_arn" {
  description = "ARN of the CPU target tracking policy"
  value       = try(aws_appautoscaling_policy.cpu[0].arn, null)
}

output "memory_policy_arn" {
  description = "ARN of the memory target tracking policy — null if not enabled"
  value       = try(aws_appautoscaling_policy.memory[0].arn, null)
}
