# modules/backend_setup/outputs.tf
data "aws_region" "current" {}

output "region" {
  value = data.aws_region.current.name
}

output "bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}
