variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "github_org" {
  description = "GitHub username or organisation that owns the repo"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without the owner prefix)"
  type        = string
}

variable "allowed_ref" {
  description = <<-EOT
    Scope the OIDC trust to a specific ref pattern.
    Examples:
      "*"                        — any ref in the repo (default, most flexible)
      "ref:refs/heads/main"      — main branch only
      "ref:refs/heads/main:pull_request" — main + PRs
  EOT
  type        = string
  default     = "*"
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Only ONE is allowed per AWS account — set false if it already exists."
  type        = bool
  default     = true
}

variable "tf_state_bucket" {
  description = "S3 bucket name that holds Terraform state — scopes the S3 policy"
  type        = string
}

variable "tf_lock_table" {
  description = "DynamoDB table name used for state locking — scopes the DynamoDB policy"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
