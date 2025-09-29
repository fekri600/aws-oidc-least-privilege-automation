

module "artifacts_bucket" {
  source            = "../../../../modules/s3"
  name              = "${var.name_prefix}-shared-bkt"
  enable_versioning = false
  force_destroy     = true
  kms_key_arn       = null # or leave null for AES256
 
  tags = {
    app         = var.name_prefix
    environment = "shared"
    purpose     = "demo"
  }
}





