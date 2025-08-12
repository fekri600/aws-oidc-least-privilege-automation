output "rds_id" {
  value       = aws_db_instance.this.id
  description = "RDS instance ID"
}

output "rds_endpoint" {
  value       = aws_db_instance.this.endpoint
  description = "RDS instance endpoint"
}
