data "aws_ssm_parameter" "github_trust_role_arn" {
  name = "/i2508/oidc/github_trust_role_arn"
}

data "aws_ssm_parameter" "db_username" {
  name = "/i2508dr/db/db_username"
}

data "aws_ssm_parameter" "db_password" {
  name            = "/i2508dr/db/db_password"
  with_decryption = true
}

data "aws_ssm_parameter" "artifacts_bucket_name"  { name = "/i2508dr/ci/artifacts_bucket_name" }
data "aws_ssm_parameter" "rds_snapshot_s3_key"    { name = "/i2508dr/ci/rds_snapshot_s3_key" }
data "aws_ssm_parameter" "rds_failover_s3_key"    { name = "/i2508dr/ci/rds_failover_s3_key" }
data "aws_ssm_parameter" "rds_snapshot_code_hash" { name = "/i2508dr/ci/rds_snapshot_code_hash" }
data "aws_ssm_parameter" "rds_failover_code_hash" { name = "/i2508dr/ci/rds_failover_code_hash" }
