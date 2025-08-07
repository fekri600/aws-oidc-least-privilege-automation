output "db_username_path" {
  value = aws_ssm_parameter.db_username.name
}

output "db_password_path" {
  value = aws_ssm_parameter.db_password.name
}

output "db_endpoint_path" {
  value = aws_ssm_parameter.db_endpoint.name
}