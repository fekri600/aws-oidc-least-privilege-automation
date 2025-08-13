# ---- S3 Bucket Configuration ----
state_bucket_name               = "backend-s3-bucket-2707"
state_bucket_versioning_enabled = "Enabled"
state_bucket_sse_algorithm      = "AES256"
public_access_block_config = {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
state_bucket_tags = {
  Name        = "Terraform Remote state management Bucket"
  Environment = "backend remote state management"
}

# ---- DynamoDB Table Configuration ----
dynamodb_table_name     = "backend-d-db-table"
dynamodb_billing_mode   = "PAY_PER_REQUEST"
dynamodb_hash_key       = "LockID"
dynamodb_attribute_type = "S"
dynamodb_table_tags = {
  Name        = "Terraform Locks Table"
  Environment = "backend remote state management"
}

# ---- GitHub OIDC Provider and IAM Role Configuration ----
oidc_url             = "https://token.actions.githubusercontent.com"
oidc_client_id_list  = ["sts.amazonaws.com"]
oidc_thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

iam_role_name   = "AWS_OIDC_ROLE_ARN"
iam_policy_name = "github_permission_policy"


