data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  # GitHub's OIDC provider URL
  github_oidc_url = "https://token.actions.githubusercontent.com"

  # sub claim format: repo:{org}/{repo}:{ref_pattern}
  oidc_sub = "repo:${var.github_org}/${var.github_repo}:${var.allowed_ref}"
}

# ── GitHub OIDC provider ───────────────────────────────────────────────────────
# One provider per AWS account. Set create_oidc_provider = false if it already
# exists and import it: terraform import module.github_oidc[0].aws_iam_openid_connect_provider.this <arn>

resource "aws_iam_openid_connect_provider" "this" {
  count = var.create_oidc_provider ? 1 : 0

  url            = local.github_oidc_url
  client_id_list = ["sts.amazonaws.com"]

  # DigiCert root CA thumbprints for token.actions.githubusercontent.com
  # AWS validates against its own trust store since 2023, but the field is still required.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = merge(local.common_tags, { Name = "github-actions-oidc" })
}

# ── GitHub Actions IAM role ────────────────────────────────────────────────────

data "aws_iam_openid_connect_provider" "github" {
  # Resolves whether we just created it or it pre-existed
  url        = local.github_oidc_url
  depends_on = [aws_iam_openid_connect_provider.this]
}

resource "aws_iam_role" "github_actions" {
  name        = "${local.name_prefix}-github-actions"
  description = "Assumed by GitHub Actions via OIDC for repo ${var.github_org}/${var.github_repo}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Tighten to "ref:refs/heads/main" to restrict to main-branch only
          "token.actions.githubusercontent.com:sub" = local.oidc_sub
        }
      }
    }]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-github-actions" })
}

# ── Terraform permissions ──────────────────────────────────────────────────────
# Covers every AWS service this project's Terraform code touches.
# Scope IAM actions further once role names are stable.

resource "aws_iam_role_policy" "terraform" {
  name = "${local.name_prefix}-terraform-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EC2VPC"
        Effect   = "Allow"
        Action   = ["ec2:*"]
        Resource = "*"
      },
      {
        Sid      = "ECS"
        Effect   = "Allow"
        Action   = ["ecs:*"]
        Resource = "*"
      },
      {
        Sid      = "ECR"
        Effect   = "Allow"
        Action   = ["ecr:*"]
        Resource = "*"
      },
      {
        Sid      = "ALB"
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:*"]
        Resource = "*"
      },
      {
        Sid    = "IAMRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:ListRoles",
          "iam:UpdateRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:ListRoleTags",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:PassRole"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMOIDCProvider"
        Effect = "Allow"
        Action = [
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:ListOpenIDConnectProviders",
          "iam:TagOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint"
        ]
        Resource = "*"
      },
      {
        Sid      = "CloudWatchLogs"
        Effect   = "Allow"
        Action   = ["logs:*"]
        Resource = "*"
      },
      {
        Sid      = "AppAutoScaling"
        Effect   = "Allow"
        Action   = ["application-autoscaling:*"]
        Resource = "*"
      },
      {
        Sid    = "TerraformStateS3"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:GetEncryptionConfiguration"
        ]
        Resource = [
          "arn:aws:s3:::${var.tf_state_bucket}",
          "arn:aws:s3:::${var.tf_state_bucket}/*"
        ]
      },
      {
        Sid    = "TerraformStateLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/${var.tf_lock_table}"
      },
      {
        Sid      = "STSCallerIdentity"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      }
    ]
  })
}
