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
- GitHub Actions OIDC -- no static keys
- AWS region: us-east-1  # change if needed
- AWS account ID: 123456789012  # change to yours

## Module Structure
modules/
  vpc/          -- VPC, subnets, IGW, NAT, route tables
  ecr/          -- container registry
  iam/          -- task execution + task roles
  alb/          -- ALB, target group, listeners
  ecs/          -- cluster, task definition, service
  autoscaling/  -- appautoscaling policies

## Session State
- [ ] Bootstrap script (S3, DynamoDB, OIDC, IAM role)
- [ ] S3 backend block in root main.tf
- [ ] GitHub Actions workflow
- [ ] vpc module
- [ ] ecr + iam modules
- [ ] alb module
- [ ] ecs module
- [ ] autoscaling module

## Open Decisions
- Container image name/tag convention TBD
- ALB: internal or internet-facing TBD