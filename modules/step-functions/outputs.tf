output "step_functions_arn" {
  value       = aws_sfn_state_machine.this.arn
  description = "Step Functions ARN"
}
