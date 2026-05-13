# Working Preferences

## Compaction
- Run /compact manually at ~50% context usage, not automatic
- On compact, always preserve: modified files, current module status,
  unresolved decisions, open security flags

## IaC
- Modular, DRY. Flag security risks immediately, including hardcoded secrets.
- Minimum code that solves the problem. Nothing speculative.
- Touch only what you must. Clean up only your own mess.
- Inline comments on non-obvious logic only.
- YAML over JSON where both are valid.

## General
- Skip DevOps basics. Keep CLI explanations brief.
- Don't assume. Don't hide confusion. Surface tradeoffs explicitly.
- Define success criteria. Loop until verified.
- Clear, direct output. No filler.

---

# Project: ECS Fargate on AWS

## Stack
- Terraform >= 1.5
- Fargate launch type, new VPC
- S3 backend + DynamoDB state lock
- GitHub Actions OIDC — no static keys (existing OIDC role reused)
- AWS region: us-east-1
- AWS account ID: <your-account-id>

## Module Structure
modules/
  vpc/          -- VPC, subnets, IGW, NAT, route tables
  ecr/          -- container registry (immutable tags)
  iam/          -- task execution + task roles
  alb/          -- ALB, blue/green target groups, weighted listeners
  ecs/          -- cluster, task definition, service (slot=blue|green)
  autoscaling/  -- appautoscaling policies (active slot only)
  github_oidc/  -- OIDC provider + IAM role (create_github_oidc=false, existing role used)

## Infrastructure state (2026-05-12)
- [x] All modules written, applied, and live in AWS
- [x] Blue-green deployment working — green cutover tested
- [x] GitHub Actions CI/CD working (pr.yml + deploy.yml in ecs-fargate-app)
- [x] Flask version banner app deployed (APP_COLOR / APP_VERSION driven)
- [ ] Merge feature-add/infra → main (ecs-fargate-project)
- [ ] Merge PR #7 → main (ecs-fargate-app)

## Key architecture decisions
- Weighted ALB forwarding: both TGs always on the listener (active=100, standby=0)
- blue_desired_count / green_desired_count are explicit tfvars — ALB cutover and scale-down are decoupled
- ignore_changes = [task_definition] only; Terraform owns desired_count
- ACM cert via data source lookup (greatzlabs.com), most_recent=true
- PYTHONDONTWRITEBYTECODE=1 required with readonlyRootFilesystem=true

## Current tfvars state
active_color        = "green"   # green is live
blue_desired_count  = 0
green_desired_count = 2