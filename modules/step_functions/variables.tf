variable "name" {
  type        = string
  description = "Prefix name for all resources in this network"
}

variable "sns_topic_arn" {
  type        = string
  description = "SNS topic ARN"
}

variable "lambda_failover_arn" {
  type        = string
  description = "Lambda function ARN"
}
variable "role_arn" {
  type        = string
  description = "Role ARN"
}