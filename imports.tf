# One-time import of GitHub OIDC resources created manually before Terraform
# was applied. Delete this file after running terraform apply successfully.

data "aws_caller_identity" "current" {}

import {
  to = module.github_oidc[0].aws_iam_openid_connect_provider.this[0]
  id = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

import {
  to = module.github_oidc[0].aws_iam_role.github_actions
  id = "github-to-aws-oidc"
}

import {
  to = module.github_oidc[0].aws_iam_role_policy.terraform
  id = "github-to-aws-oidc:ecs-fargate-dev-terraform-policy"
}
