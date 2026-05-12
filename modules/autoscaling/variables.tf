variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  description = "ECS cluster name to attach scaling to"
  type        = string
  default     = ""
}

variable "service_name" {
  description = "ECS service name to attach scaling to"
  type        = string
  default     = ""
}

variable "min_capacity" {
  description = "Minimum number of running tasks"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of running tasks"
  type        = number
  default     = 4
}

variable "cpu_target_value" {
  description = "Target average CPU % for the tracking policy"
  type        = number
  default     = 60
}

variable "memory_target_value" {
  description = "Target average memory % for the tracking policy. Set to 0 to disable."
  type        = number
  default     = 0
}

variable "scale_in_cooldown" {
  description = "Seconds to wait after a scale-in before another can happen"
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Seconds to wait after a scale-out before another can happen"
  type        = number
  default     = 60
}

variable "tags" {
  type    = map(string)
  default = {}
}
