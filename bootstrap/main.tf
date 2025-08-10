# Get current account information

module "backend_setup" {
  source = "./backend_setup"

  state_bucket_name               = var.state_bucket_name
  state_bucket_versioning_enabled = var.state_bucket_versioning_enabled
  state_bucket_sse_algorithm      = var.state_bucket_sse_algorithm
  state_bucket_tags               = var.state_bucket_tags

  block_public_acls       = var.public_access_block_config.block_public_acls
  block_public_policy     = var.public_access_block_config.block_public_policy
  ignore_public_acls      = var.public_access_block_config.ignore_public_acls
  restrict_public_buckets = var.public_access_block_config.restrict_public_buckets

  dynamodb_table_name     = var.dynamodb_table_name
  dynamodb_billing_mode   = var.dynamodb_billing_mode
  dynamodb_hash_key       = var.dynamodb_hash_key
  dynamodb_attribute_type = var.dynamodb_attribute_type
  dynamodb_table_tags     = var.dynamodb_table_tags
}



module "oidc" {
  source = "./oidc"

  # Pass backend_setup output as input
  state_bucket_name = module.backend_setup.bucket_name

  # Pass remaining variables from bootstrap
  iam_role_name        = var.iam_role_name
  iam_policy_name      = var.iam_policy_name
  oidc_url             = var.oidc_url
  oidc_client_id_list  = var.oidc_client_id_list
  oidc_thumbprint_list = var.oidc_thumbprint_list
}


