variable "name_prefix" {
  type        = string
  description = "The name prefix of the project"
}

variable "artifacts_bucket_arn" {
  type        = string
  description = "The ARN of the artifacts bucket"
}



variable "artifacts_prefix" {
  type        = string
  description = "The prefix of the artifacts"
}

variable "artifacts_bucket_name" {
  type        = string
  description = "The name of the artifacts bucket"
}

variable "ci_role_arn" {
  type        = string
  description = "The ARN of the CI role"
}