variable "function_name" {
  type        = string
  description = "Lambda function name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "input_security_group_id" {
  type        = string
  description = "Input security group ID"
}
variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs"
}
variable "handler" {
  type        = string
  description = "Lambda handler"
}
variable "runtime" {
  type        = string
  description = "Lambda runtime"
}
variable "zip_file" {
  type        = string
  description = "Lambda zip file"
}
variable "environment_variables" {
  type        = map(string)
  description = "Lambda environment variables"
}
variable "role_arn" {
  type        = string
  description = "Lambda role ARN"
}

