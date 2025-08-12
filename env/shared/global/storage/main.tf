

module "artifacts_bucket" {
  source            = "../../../../modules/s3"
  name              = "${var.name_prefix}-lfn-artf-bkt"
  enable_versioning = true
  force_destroy     = false
  kms_key_arn       = null # or leave null for AES256

  artifacts_prefix = "lambda/"
  ci_role_arn      = var.ci_role_arn
  tags = {
    app         = var.name_prefix
    environment = var.environment
    purpose     = "lambda-artifacts"
  }
}





