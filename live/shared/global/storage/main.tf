locals { name = "${var.project}-lambda-artifacts" }

data "aws_ssm_parameter" "github_trust_role_arn" {
  name = "/i2508/oidc/github_trust_role_arn"
}

module "artifacts_bucket" {
  source              = "../../../modules/s3"
  name                = local.name
  enable_versioning   = true
  force_destroy       = false
  kms_key_arn         = null       # or leave null for AES256
  
  artifacts_prefix = "lambda/"
  ci_role_arn      = data.aws_ssm_parameter.github_trust_role_arn.value

  tags = {
    app         = var.project
    environment = var.environment
    purpose     = "lambda-artifacts"
  }
}





