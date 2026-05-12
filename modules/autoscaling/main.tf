locals {
  name_prefix = "${var.project_name}-${var.environment}"
  resource_id = "service/${var.cluster_name}/${var.service_name}"
  enabled     = var.cluster_name != "" && var.service_name != ""

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ── Scalable target ───────────────────────────────────────────────────────────

resource "aws_appautoscaling_target" "this" {
  count = local.enabled ? 1 : 0

  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
  resource_id        = local.resource_id
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# ── CPU target tracking ───────────────────────────────────────────────────────
# "Keep average CPU at 60% and ECS handles the scaling math." — article

resource "aws_appautoscaling_policy" "cpu" {
  count = local.enabled ? 1 : 0

  name               = "${local.name_prefix}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.cpu_target_value
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# ── Memory target tracking (optional) ────────────────────────────────────────
# Disabled by default (memory_target_value = 0). Enable by setting a target %.
# Useful when tasks are memory-bound rather than CPU-bound.

resource "aws_appautoscaling_policy" "memory" {
  count = local.enabled && var.memory_target_value > 0 ? 1 : 0

  name               = "${local.name_prefix}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.memory_target_value
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}
