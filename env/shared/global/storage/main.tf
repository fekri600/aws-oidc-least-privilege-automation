

module "artifacts_bucket" {
  source            = "../../../../modules/s3"
  name              = "i2508dr-prod-glb-lfn-artf-bkt"
  enable_versioning = false
  force_destroy     = true
  kms_key_arn       = null # or leave null for AES256

  artifacts_prefix = "lambda/"
  ci_role_arn      = data.aws_ssm_parameter.github_trust_role_arn.value
  tags = {
    app         = "i2508dr-prod-glb"
    environment = "prod"
    purpose     = "lambda-artifacts"
  }
}





