output "db_instance_id" {
  description = "Primary RDS instance ID"
  value       = module.rds.db_instance_id
}

output "lambda_backup_arn" {
  description = "Lambda backup function ARN"
  value       = module.lambda_backup.function_arn
}

output "lambda_backup_name" {
  description = "Lambda backup function name"
  value       = module.lambda_backup.function_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for notifications"
  value       = module.sns.topic_arn
}

output "step_functions_arn" {
  description = "Step Functions state machine ARN"
  value       = module.step_functions.state_machine_arn
} 