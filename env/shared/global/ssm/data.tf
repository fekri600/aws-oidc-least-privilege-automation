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