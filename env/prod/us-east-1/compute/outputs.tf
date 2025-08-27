output "lambda_failover_arn" {
  value = module.lambda_failover.lambda_arn
}

output "lambda_snapshot_arn" {
  value = module.lambda_snapshot.lambda_arn
}
output "step_functions_arn" {
  value = module.step_functions.step_functions_arn
}