variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "AZs to use (should have 2 entries to match subnet lists)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway (cost saving, not HA)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "container_port" {
  description = "Port the application container listens on"
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "Fargate task CPU units (256 / 512 / 1024 / 2048 / 4096)"
  type        = string
  default     = "512"
}

variable "memory" {
  description = "Fargate task memory in MiB"
  type        = string
  default     = "1024"
}

variable "desired_count" {
  description = "Initial number of ECS tasks. Autoscaling takes over after first deploy."
  type        = number
  default     = 2
}

variable "image_tag" {
  description = "Container image tag. Override with git SHA in CI."
  type        = string
  default     = "latest"
}

variable "health_check_path" {
  description = "HTTP path for ALB and container health checks"
  type        = string
  default     = "/"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days — CIS benchmark requires >= 365"
  type        = number
  default     = 365
}

variable "min_capacity" {
  description = "Minimum number of ECS tasks (autoscaling floor)"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of ECS tasks (autoscaling ceiling)"
  type        = number
  default     = 4
}

# ── GitHub OIDC ───────────────────────────────────────────────────────────────

variable "github_org" {
  description = "GitHub username or organisation (e.g. 'acme-corp')"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name without owner prefix (e.g. 'ecs-fargate-project')"
  type        = string
  default     = ""
}

variable "tf_state_bucket" {
  description = "S3 bucket for Terraform state — must match backend.hcl"
  type        = string
  default     = "myapp-dev-tfstate"
}

variable "tf_lock_table" {
  description = "DynamoDB table for Terraform state locking — must match backend.hcl"
  type        = string
  default     = "myapp-dev-tflock"
}

# ── Module toggles ────────────────────────────────────────────────────────────

variable "create_vpc" {
  description = "Create the VPC module resources"
  type        = bool
  default     = true
}

variable "create_ecr" {
  description = "Create the ECR module resources"
  type        = bool
  default     = true
}

variable "create_iam" {
  description = "Create the IAM module resources"
  type        = bool
  default     = true
}

variable "create_alb" {
  description = "Create the ALB module resources"
  type        = bool
  default     = true
}

variable "create_ecs" {
  description = "Create the ECS module resources"
  type        = bool
  default     = true
}

variable "create_autoscaling" {
  description = "Create the autoscaling module resources"
  type        = bool
  default     = true
}

variable "create_github_oidc" {
  description = "Create the GitHub OIDC role and provider"
  type        = bool
  default     = true
}
