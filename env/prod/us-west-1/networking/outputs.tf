output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.subnet_private_az_1.subnet_id
}

# output "db_subnet_group_id" {
#   value = module.db_subnet_group.db_subnet_group_id
# }

# output "db_subnet_group_name" {
#   value = module.db_subnet_group.db_subnet_group_name
# }