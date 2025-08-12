

output "active_endpoint_name" {
  value = aws_ssm_parameter.db_active_endpoint.name
}

output "primary_endpoint_name" {
  value = aws_ssm_parameter.db_primary_endpoint.name
}

output "active_endpoint" {
  value = aws_ssm_parameter.db_active_endpoint.value
}

output "primary_endpoint" {
  value = aws_ssm_parameter.db_primary_endpoint.value
}