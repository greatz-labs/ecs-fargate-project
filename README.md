# ECS Fargate Blue-Green Project

Terraform infrastructure for a containerised application running on AWS ECS Fargate with a blue-green deployment model, HTTPS via ACM, GitHub Actions CI/CD, and OIDC-based authentication (no static keys).

## Architecture

```
Internet → ALB (HTTPS 443 / HTTP→HTTPS redirect)
               ├── Blue target group  (weight 100 when active_color=blue)
               └── Green target group (weight 100 when active_color=green)

Blue ECS cluster  → private subnets → ECR (image pull) / CloudWatch (logs)
Green ECS cluster → private subnets → ECR (image pull) / CloudWatch (logs)

Standby slot idles at desired_count=0 until explicitly deployed to.
```

## Module structure

```
modules/
  vpc/         — VPC, subnets, IGW, NAT gateway, route tables
  ecr/         — ECR repository with image tag immutability
  iam/         — ECS task execution role and task role
  alb/         — ALB, security group, blue/green target groups, listeners
  ecs/         — ECS cluster, task definition, service, CloudWatch log group
  autoscaling/ — App Auto Scaling target and CPU/memory policies (active slot only)
  github_oidc/ — OIDC provider and IAM role for GitHub Actions (optional)
```

## Prerequisites

- AWS CLI configured (`aws configure` or environment variables)
- Terraform >= 1.5
- An issued ACM certificate for your domain in us-east-1
- GitHub repository for the application (for CI/CD)

---

## Setup

### 1. Clone and configure

```bash
git clone <this-repo>
cd ecs-fargate-project
```

Edit `terraform.tfvars` to match your environment:

```hcl
aws_region   = "us-east-1"
project_name = "ecs-fargate"
environment  = "dev"

github_org      = "<your-github-org>"
github_repo     = "<this-repo-name>"
tf_state_bucket = "ecs-fargate-dev-tfstate"
tf_lock_table   = "ecs-fargate-dev-tflock"
```

Edit `backend.hcl` if you changed the bucket or table names:

```hcl
bucket         = "ecs-fargate-dev-tfstate"
key            = "ecs-fargate/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "ecs-fargate-dev-tflock"
encrypt        = true
```

### 2. Bootstrap remote state

Run once before the first `terraform init`. Creates the S3 state bucket and DynamoDB lock table.

```bash
chmod +x bootstrap.sh
./bootstrap.sh
```

### 3. Initialise Terraform

```bash
terraform init -backend-config=backend.hcl
```

### 4. Push an initial image to ECR

ECS tasks will fail to start if the image tag does not exist in ECR at apply time. Push an initial image first by applying only the ECR module, then the rest:

```bash
# Apply ECR module only
terraform apply -target=module.ecr

# Authenticate Docker to ECR
ECR_URL=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_URL

# Build and push
docker build -t $ECR_URL:latest <path-to-app>
docker push $ECR_URL:latest

# Apply remaining modules
terraform apply
```

### 5. Apply infrastructure

```bash
terraform plan
terraform apply
```

Note the outputs — you will need them to configure the application CI/CD workflow:

| Output | Used for |
|---|---|
| `ecr_repository_url` | `ECR_REPOSITORY` GitHub variable |
| `blue_cluster_name` | `ECS_CLUSTER` GitHub variable |
| `blue_service_name` | `ECS_SERVICE` GitHub variable |
| `alb_dns_name` | DNS / Route53 CNAME |
| `github_actions_role_arn` | `AWS_ROLE_ARN` GitHub variable |

### 6. Configure the application repository

In the application GitHub repo → Settings → Variables → Actions, set:

| Variable | Value |
|---|---|
| `AWS_ROLE_ARN` | `github_actions_role_arn` output |
| `AWS_REGION` | `us-east-1` |
| `ECR_REPOSITORY` | repository name (last segment of `ecr_repository_url`) |
| `ECS_CLUSTER` | `ecs-fargate-dev-blue-cluster` |
| `ECS_SERVICE` | `ecs-fargate-dev-blue-service` |
| `TASK_DEFINITION_FAMILY` | `ecs-fargate-dev-blue-task` |
| `CONTAINER_NAME` | `ecs-fargate-blue-app` |

### 7. Deploy the application

Merge the application branch to `main`. The deploy workflow will:

1. Build the Docker image and push to ECR (tagged with git SHA and `latest`)
2. Register a new task definition revision with the new image
3. Perform a rolling deploy to the active ECS service
4. Wait for service stability

---

## Blue-green cutover

Traffic is controlled by the `active_color` variable. The ALB listener uses weighted forwarding — the active slot gets weight 100, the standby gets weight 0. Changing `active_color` and applying is the only action required to shift traffic.

### Step 1 — Deploy new version to the standby slot

Update the GitHub variables to target the standby, then push to `main` to trigger the deploy workflow:

**Cutting over to green (green is standby):**

| Variable | Value |
|---|---|
| `ECS_CLUSTER` | `ecs-fargate-dev-green-cluster` |
| `ECS_SERVICE` | `ecs-fargate-dev-green-service` |
| `TASK_DEFINITION_FAMILY` | `ecs-fargate-dev-green-task` |
| `CONTAINER_NAME` | `ecs-fargate-green-app` |

The deploy workflow scales green up, pushes the new image, and waits for stability.

### Step 2 — Validate the standby

```bash
curl https://<alb-dns>/version
# {"color": "green", "version": "2.0.0", ...}
```

### Step 3 — Cut over

```hcl
# terraform.tfvars
active_color = "green"
```

```bash
terraform apply
```

This atomically:
- Flips the ALB listener weights (green=100, blue=0)
- Sets green `desired_count` to `var.desired_count`
- Sets blue `desired_count` to 0 (standby idles)

The listener update completes in ~30 seconds with zero downtime — existing connections drain before blue tasks stop.

### Roll back

```hcl
# terraform.tfvars
active_color = "blue"
```

```bash
terraform apply
```

---

## Cost notes

| Resource | Always on | Notes |
|---|---|---|
| ALB | yes | ~$16/mo |
| NAT gateway | yes | `single_nat_gateway = true` saves ~$33/mo in dev |
| ECS tasks (active slot) | yes | Fargate — pay per vCPU/memory used |
| ECS tasks (standby slot) | no | `desired_count = 0` when not active |
| ECR storage | yes | Minimal — immutable tags prevent unbounded growth |

## Destroying

```bash
terraform destroy
```

The ALB access log S3 bucket has `force_destroy = true` for lab use — it will be emptied and deleted automatically.
