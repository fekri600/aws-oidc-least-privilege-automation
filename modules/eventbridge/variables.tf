variable "name" {
  type        = string
  description = "Prefix name for all resources in this network"
}

variable "lambda_arn" {
  type        = string
  description = "Lambda function ARN"
}

variable "lambda_name" {
  type        = string
  description = "Lambda function name"
}

variable "schedule_expression" {
  type        = string
  description = "EventBridge schedule expression"
}