output "lambda_snapshot_role_arn" {
  description = "ARN of the Lambda snapshot role"
  value       = aws_iam_role.lambda_snapshot_role.arn
}

output "step_functions_role_arn" {
  description = "ARN of the Step Functions role"
  value       = aws_iam_role.step_functions_role.arn
}

output "lambda_snapshot_role_name" {
  description = "Name of the Lambda snapshot role"
  value       = aws_iam_role.lambda_snapshot_role.name
}

output "step_functions_role_name" {
  description = "Name of the Step Functions role"
  value       = aws_iam_role.step_functions_role.name
}
output "lambda_failover_role_arn" {
  description = "ARN of the Lambda failover role"
  value       = aws_iam_role.lambda_failover_role.arn
}

