terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # All values supplied via: terraform init -backend-config=backend.hcl
  # Run bootstrap.sh first to create the bucket and DynamoDB table.
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# Look up the ACM certificate by domain name; avoids hardcoding the ARN.
data "aws_acm_certificate" "this" {
  domain      = "greatzlabs.com"
  statuses    = ["ISSUED"]
  most_recent = true # in case of renewals, always use the newest issued cert
}

module "vpc" {
  count  = var.create_vpc ? 1 : 0
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  single_nat_gateway   = var.single_nat_gateway
  tags                 = var.tags
}

module "ecr" {
  count  = var.create_ecr ? 1 : 0
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
}

module "iam" {
  count  = var.create_iam ? 1 : 0
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
}

module "alb" {
  count  = var.create_alb ? 1 : 0
  source = "./modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = try(module.vpc[0].vpc_id, "")
  public_subnet_ids = try(module.vpc[0].public_subnet_ids, [])
  container_port    = var.container_port
  certificate_arn   = data.aws_acm_certificate.this.arn
  active_color      = var.active_color
  health_check_path = var.health_check_path
  tags              = var.tags
}

module "ecs_blue" {
  count  = var.create_ecs ? 1 : 0
  source = "./modules/ecs"

  slot                  = "blue"
  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = try(module.vpc[0].vpc_id, "")
  private_subnet_ids    = try(module.vpc[0].private_subnet_ids, [])
  execution_role_arn    = try(module.iam[0].execution_role_arn, "")
  task_role_arn         = try(module.iam[0].task_role_arn, "")
  ecr_repository_url    = try(module.ecr[0].repository_url, "")
  target_group_arn      = try(module.alb[0].blue_target_group_arn, "")
  alb_security_group_id = try(module.alb[0].alb_security_group_id, "")
  container_port        = var.container_port
  cpu                   = var.cpu
  memory                = var.memory
  desired_count         = var.desired_count
  image_tag             = var.image_tag
  health_check_path     = var.health_check_path
  log_retention_days    = var.log_retention_days
  environment_variables = {
    APP_COLOR              = "blue"
    APP_VERSION            = var.blue_version
    PYTHONDONTWRITEBYTECODE = "1"
  }
  tags = var.tags
}

module "ecs_green" {
  count  = var.create_ecs ? 1 : 0
  source = "./modules/ecs"

  slot                  = "green"
  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = try(module.vpc[0].vpc_id, "")
  private_subnet_ids    = try(module.vpc[0].private_subnet_ids, [])
  execution_role_arn    = try(module.iam[0].execution_role_arn, "")
  task_role_arn         = try(module.iam[0].task_role_arn, "")
  ecr_repository_url    = try(module.ecr[0].repository_url, "")
  target_group_arn      = try(module.alb[0].green_target_group_arn, "")
  alb_security_group_id = try(module.alb[0].alb_security_group_id, "")
  container_port        = var.container_port
  cpu                   = var.cpu
  memory                = var.memory
  desired_count         = var.desired_count
  image_tag             = var.image_tag
  health_check_path     = var.health_check_path
  log_retention_days    = var.log_retention_days
  environment_variables = {
    APP_COLOR              = "green"
    APP_VERSION            = var.green_version
    PYTHONDONTWRITEBYTECODE = "1"
  }
  tags = var.tags
}

module "github_oidc" {
  count  = var.create_github_oidc ? 1 : 0
  source = "./modules/github_oidc"

  project_name    = var.project_name
  environment     = var.environment
  github_org      = var.github_org
  github_repo     = var.github_repo
  tf_state_bucket = var.tf_state_bucket
  tf_lock_table   = var.tf_lock_table
  tags            = var.tags
}

module "autoscaling" {
  count  = var.create_autoscaling ? 1 : 0
  source = "./modules/autoscaling"

  project_name = var.project_name
  environment  = var.environment
  # Scale the active slot; the standby holds its current task count untouched
  cluster_name = var.active_color == "blue" ? try(module.ecs_blue[0].cluster_name, "") : try(module.ecs_green[0].cluster_name, "")
  service_name = var.active_color == "blue" ? try(module.ecs_blue[0].service_name, "") : try(module.ecs_green[0].service_name, "")
  min_capacity = var.min_capacity
  max_capacity = var.max_capacity
  tags         = var.tags
}
