output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Subnet IDs"
  value       = [module.subnet_private_az_1.subnet_id, module.subnet_private_az_2.subnet_id]
}


# output "db_subnet_group_id" {
#   description = "DB subnet group ID"
#   value       = module.db_subnet_group.db_subnet_group_id
# }

# output "db_subnet_group_name" {
#   description = "DB subnet group name"
#   value       = module.db_subnet_group.db_subnet_group_name
# }

