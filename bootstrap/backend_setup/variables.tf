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

variable "block_public_acls" {
  description = "Block public ACLs for the S3 bucket"
  type        = bool
}

variable "block_public_policy" {
  description = "Block public bucket policy for the S3 bucket"
  type        = bool
}

variable "ignore_public_acls" {
  description = "Ignore public ACLs for the S3 bucket"
  type        = bool
}

variable "restrict_public_buckets" {
  description = "Restrict public buckets for the S3 bucket"
  type        = bool
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