# Terraform S3 backend configuration
# Usage: terraform init -backend-config=backend.hcl
#
# Run bootstrap.sh ONCE before the first terraform init to create the bucket and table.

bucket         = "ecs-fargate-dev-tfstate"
key            = "ecs-fargate/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "ecs-fargate-dev-tflock"
encrypt        = true
