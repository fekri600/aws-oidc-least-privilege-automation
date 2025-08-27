data "aws_ssm_parameter" "artifacts_bucket_arn" {
  name = "/i2508dr/ci/artifacts_bucket_arn"
}

data "aws_ssm_parameter" "rds_snapshot_s3_key" {
  name = "/i2508dr/ci/rds_snapshot_s3_key"
}

data "aws_ssm_parameter" "rds_failover_s3_key" {
  name = "/i2508dr/ci/rds_failover_s3_key"
}

data "aws_ssm_parameter" "rds_snapshot_code_hash" {
  name = "/i2508dr/ci/rds_snapshot_code_hash"
}

data "aws_ssm_parameter" "rds_failover_code_hash" {
  name = "/i2508dr/ci/rds_failover_code_hash"
}

data "aws_ssm_parameter" "artifacts_bucket_name" {
  name = "/i2508dr/ci/artifacts_bucket_name"
}
