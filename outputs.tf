output "primary_db_instance_id" {
  description = "Primary RDS instance ID"
  value       = module.primary.db_instance_id
}

output "primary_lambda_backup_arn" {
  description = "Primary Lambda backup function ARN"
  value       = module.primary.lambda_backup_arn
}

output "secondary_lambda_failover_arn" {
  description = "Secondary Lambda failover function ARN"
  value       = module.secondary.lambda_failover_arn
}

output "primary_sns_topic_arn" {
  description = "Primary SNS topic ARN"
  value       = module.primary.sns_topic_arn
}

output "secondary_sns_topic_arn" {
  description = "Secondary SNS topic ARN"
  value       = module.secondary.sns_topic_arn
}

output "step_functions_arn" {
  description = "Step Functions state machine ARN"
  value       = module.primary.step_functions_arn
}
