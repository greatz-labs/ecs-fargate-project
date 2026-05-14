aws_region   = "us-east-1"
project_name = "ecs-fargate"
environment  = "dev"

vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

# Set to true in dev/staging to save ~$33/mo on the second NAT gateway
single_nat_gateway = true

tags = {
  Owner = "platform-team"
  Repo  = "ecs-fargate-project"
}

# ── Container / ECS ──────────────────────────────────────────────────────────
container_port     = 3000
health_check_path  = "/"
cpu                = "512"
memory             = "1024"
desired_count      = 2
image_tag          = "latest" # replace with git SHA in CI
log_retention_days = 365      # CIS benchmark minimum

# ── Autoscaling ───────────────────────────────────────────────────────────────
min_capacity = 1
max_capacity = 4

# ── Blue-Green ────────────────────────────────────────────────────────────────
# Cutover: set active_color + bump the standby desired_count to var.desired_count,
# then apply. Scale down the old active only after validating the new one.
active_color        = "blue"
blue_desired_count  = 0
green_desired_count = 0
blue_version        = "1.0.0"
green_version       = "2.0.0"

# ── GitHub OIDC ───────────────────────────────────────────────────────────────
github_org      = "greatz-labs"
github_repo     = "ecs-fargate-project"
tf_state_bucket = "ecs-fargate-dev-tfstate"
tf_lock_table   = "ecs-fargate-dev-tflock"

# ── Module toggles — set to false to destroy/skip individual modules ──────────
create_vpc         = true
create_ecr         = true
create_iam         = true
create_alb         = true
create_ecs_blue    = true
create_ecs_green   = true
create_autoscaling = false
create_github_oidc = false

# ── Counter App ───────────────────────────────────────────────────────────────
counter_container_port      = 8080
counter_cpu                 = "256"
counter_memory              = "512"
counter_image_tag           = "latest"
counter_health_check_path   = "/counter/health"
counter_blue_version        = "1.0.0"
counter_green_version       = "1.0.0"
counter_blue_desired_count  = 2
counter_green_desired_count = 0

# Enable in order: ecr_counter first → push image → then alb + ecs
create_ecr_counter = true
create_counter_alb = true
create_ecs_counter = true
