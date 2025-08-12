data "aws_caller_identity" "current" {

}

data "aws_ssm_parameter" "db_username" {
  name = "/i2508dr/db/db_username"
}

data "aws_ssm_parameter" "db_password" {
  name            = "/i2508dr/db/db_password"
  with_decryption = true
}

