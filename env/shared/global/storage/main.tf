

module "artifacts_bucket" {
  source            = "../../../../modules/s3"
  name              = "i2508dr-prod-glb-lfn-artf-bkt"
  enable_versioning = false
  force_destroy     = true
  kms_key_arn       = null # or leave null for AES256

  artifacts_prefix = "lambda/"
  tags = {
    app         = "i2508dr-prod-glb"
    environment = "prod"
    purpose     = "lambda-artifacts"
  }
}





