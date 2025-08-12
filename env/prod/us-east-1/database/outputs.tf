
output "db_instance_id" {
  value = module.rds.rds_id
}

output "db_dns_record_name" {
  value = module.route53_record.record_name
}


output "db_primary_endpoint" {
  value = module.rds.rds_endpoint
}

output "db_active_endpoint" {
  value = module.rds.rds_endpoint
}