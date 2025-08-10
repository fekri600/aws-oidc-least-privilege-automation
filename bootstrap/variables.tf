variable "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
}

variable "state_bucket_versioning_enabled" {
  description = "Enable versioning on S3 bucket"
  type        = string
}

variable "state_bucket_sse_algorithm" {
  description = "SSE algorithm for S3 bucket encryption"
  type        = string
}

variable "state_bucket_tags" {
  description = "Tags for S3 bucket"
  type        = map(string)
}

variable "public_access_block_config" {
  description = "Public access block settings for the S3 bucket"
  type = object({
    block_public_acls       = bool
    block_public_policy     = bool
    ignore_public_acls      = bool
    restrict_public_buckets = bool
  })
}



variable "dynamodb_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
}

variable "dynamodb_billing_mode" {
  description = "Billing mode for DynamoDB table"
  type        = string
}

variable "dynamodb_hash_key" {
  description = "Hash key attribute name for DynamoDB table"
  type        = string
}

variable "dynamodb_attribute_type" {
  description = "Type for hash key attribute"
  type        = string
}

variable "dynamodb_table_tags" {
  description = "Tags for DynamoDB table"
  type        = map(string)
}

variable "oidc_url" {
  description = "OIDC provider URL"
  type        = string
}

variable "oidc_client_id_list" {
  description = "OIDC client IDs"
  type        = list(string)
}

variable "oidc_thumbprint_list" {
  description = "OIDC thumbprint list"
  type        = list(string)
}

variable "iam_role_name" {
  description = "Name for the IAM role used by GitHub Actions"
  type        = string
}

variable "iam_policy_name" {
  description = "Name for the IAM policy attached to the GitHub Actions role"
  type        = string
}
