output "db_primary_endpoint" {
  value = module.ssm.primary_endpoint_name
}

output "db_active_endpoint" {
  value = module.ssm.active_endpoint_name
}


output "db_username" {
  value = data.aws_ssm_parameter.db_username.value
}

output "db_password" {
  value = data.aws_ssm_parameter.db_password.value
}

output "artifacts_bucket_name" {
  value = data.aws_ssm_parameter.artifacts_bucket_name.value
}

output "rds_snapshot_s3_key" {
  value = data.aws_ssm_parameter.rds_snapshot_s3_key.value
}

output "rds_failover_s3_key" {
  value = data.aws_ssm_parameter.rds_failover_s3_key.value
}

output "rds_snapshot_code_hash" {
  value = data.aws_ssm_parameter.rds_snapshot_code_hash.value
}

output "rds_failover_code_hash" {
  value = data.aws_ssm_parameter.rds_failover_code_hash.value
}

output "artifacts_bucket_arn" {
  value = data.aws_ssm_parameter.artifacts_bucket_arn.value
}