variable "function_name" {
  type        = string
  description = "Lambda function name"
}

variable "handler" {
  type        = string
  description = "Lambda handler"
}
variable "runtime" {
  type        = string
  description = "Lambda runtime"
}

variable "environment_variables" {
  type        = map(string)
  description = "Lambda environment variables"
}
variable "role_arn" {
  type        = string
  description = "Lambda role ARN"
}

variable "s3_bucket" {
  type        = string
  description = "S3 bucket name"
}

variable "s3_key" {
  type        = string
  description = "S3 key"
}

variable "source_code_hash" {
  type        = string
  description = "Source code hash"
}



