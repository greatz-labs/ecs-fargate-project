variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "container_port" {
  description = "Port the container listens on — must match task definition containerPort"
  type        = number
  default     = 8080
}

variable "certificate_arn" {
  description = "ACM certificate ARN. When set, an HTTPS listener is created and HTTP redirects to it."
  type        = string
  default     = ""
}

variable "health_check_path" {
  description = "Path the ALB uses to health-check tasks"
  type        = string
  default     = "/"
}

variable "health_check_interval" {
  description = "Seconds between health checks"
  type        = number
  default     = 30
}

variable "health_check_healthy_threshold" {
  description = "Consecutive successes before marking a target healthy"
  type        = number
  default     = 3
}

variable "health_check_unhealthy_threshold" {
  description = "Consecutive failures before marking a target unhealthy"
  type        = number
  default     = 3
}

variable "deregistration_delay" {
  description = "Seconds ALB waits before deregistering a draining target — lower for faster deploys"
  type        = number
  default     = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
