variable "name"                   { type = string }
variable "enable_versioning" {
  type    = bool
  default = true
}
variable "force_destroy" {
  type    = bool
  default = false
}
variable "kms_key_arn" {
  type    = string
  default = null  # use AES256 if null
}
variable "enable_bucket_key" {
  type    = bool
  default = true  # S3 Bucket Keys w/ KMS
}
variable "lifecycle_enabled" {
  type    = bool
  default = true
}
variable "noncurrent_expire_days" {
  type    = number
  default = 90
}
variable "tags" {
  type    = map(string)
  default = {}
}

variable "ci_role_arn" {
  type    = string
  default = null
}
variable "artifacts_prefix" {
  type    = string
  default = null
}