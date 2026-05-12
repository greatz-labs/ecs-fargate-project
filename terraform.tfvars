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
# Change active_color to "green" + terraform apply to cut over; revert to roll back
active_color  = "blue"
blue_version  = "1.0.0"
green_version = "2.0.0"

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
create_ecs         = true
create_autoscaling = true
create_github_oidc = false
