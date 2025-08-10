output "db_primary_endpoint" {
  value = module.ssm.db_primary_endpoint
}

output "db_active_endpoint" {
  value = module.ssm.db_active_endpoint
}