output "db_instance_id" {
  description = "Primary RDS instance ID"
  value       = module.rds.rds_id
}

output "lambda_snapshot_arn" {
  description = "Lambda backup function ARN"
  value       = module.lambda_snapshot.lambda_arn
}

output "lambda_snapshot_name" {
  description = "Lambda backup function name"
  value       = module.lambda_snapshot.lambda_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for notifications"
  value       = module.sns.sns_topic_arn
}

output "step_functions_arn" {
  description = "Step Functions state machine ARN"
  value       = module.step_functions.step_function_arn
} 