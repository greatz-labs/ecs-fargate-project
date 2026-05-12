#!/usr/bin/env bash
# Bootstrap Terraform remote state infrastructure.
# Run ONCE before the first `terraform init -backend-config=backend.hcl`.
# Requires AWS CLI configured with sufficient permissions.

set -euo pipefail

BUCKET="ecs-fargate-dev-tfstate"
TABLE="ecs-fargate-dev-tflock"
REGION="us-east-1"

echo "==> Creating S3 state bucket: $BUCKET"
if aws s3api head-bucket --bucket "$BUCKET" --region "$REGION" 2>/dev/null; then
  echo "    Bucket already exists, skipping."
else
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
  else
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi

  # Versioning lets you recover from accidental state corruption
  aws s3api put-bucket-versioning --bucket "$BUCKET" \
    --versioning-configuration Status=Enabled

  # Encryption at rest
  aws s3api put-bucket-encryption --bucket "$BUCKET" \
    --server-side-encryption-configuration '{
      "Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]
    }'

  # Block all public access
  aws s3api put-public-access-block --bucket "$BUCKET" \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  echo "    Bucket created."
fi

echo "==> Creating DynamoDB lock table: $TABLE"
if aws dynamodb describe-table --table-name "$TABLE" --region "$REGION" 2>/dev/null; then
  echo "    Table already exists, skipping."
else
  aws dynamodb create-table \
    --table-name "$TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION"
  echo "    Table created."
fi

echo ""
echo "Bootstrap complete. Next steps:"
echo "  1. Update backend.hcl if you changed BUCKET/TABLE/REGION above."
echo "  2. terraform init -backend-config=backend.hcl"
echo "  3. terraform apply"
