output "lambda_failover_arn" {
  description = "Lambda failover function ARN"
  value       = module.lambda_failover.function_arn
}

output "lambda_failover_name" {
  description = "Lambda failover function name"
  value       = module.lambda_failover.function_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for notifications"
  value       = module.sns.topic_arn
} 