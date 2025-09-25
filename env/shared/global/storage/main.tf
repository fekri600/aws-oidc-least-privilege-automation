

module "artifacts_bucket" {
  source            = "../../../../modules/s3"
  name              = "i2509dr-demo-bkt"
  enable_versioning = false
  force_destroy     = true
  kms_key_arn       = null # or leave null for AES256
 
  tags = {
    app         = "i2509dr-demo"
    environment = "demo"
    purpose     = "demo"
  }
}





